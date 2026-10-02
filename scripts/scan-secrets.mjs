/**
 * Deterministic secret scanner for the whole monorepo, plus git history.
 *
 * SEC-005. The audit found live third-party credentials on disk - a HuggingFace
 * token, an OpenRouteService key, a database password - and rated it P0. Where
 * they actually are is narrower than that: not in git, and not in any tracked
 * file. `git log --all` is clean of every rule below, `.env` is ignored, and
 * `.env.example` holds placeholders only. This script is what keeps it that
 * way, instead of leaving it to convention.
 *
 * Why not gitleaks or trufflehog: they are better tools, but neither is
 * installed here, so a gate built on them could not be executed against this
 * repository before being merged. A gate that has never been run is the exact
 * failure this branch exists to close - TEST-003 was nine specs that had never
 * run. So this is deterministic, dependency-free, and self-verifying:
 *
 *   node scripts/scan-secrets.mjs            scan, exit 1 on findings
 *   node scripts/scan-secrets.mjs --self-test  prove the rules still fire
 *
 * The self-test exists because a scanner that reports "clean" is
 * indistinguishable from a scanner that stopped looking. It feeds each rule a
 * synthetic secret and asserts the rule fires, so "clean" means something.
 *
 * Usage: node scripts/scan-secrets.mjs
 */
import { execFileSync, spawnSync } from 'node:child_process';
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

const REPO_ROOT = join(import.meta.dirname, '..');

/**
 * Documented test/CI placeholder passwords, enumerated from this repository's
 * own files rather than guessed. A rule that fires on the CI service
 * container's default password is a rule somebody switches off.
 */
const PLACEHOLDER_POSTGRES_PASSWORDS = new Set([
  'postgres', // the GitHub Actions service container's own default
  'fixnow_test', // the disposable integration database
  'fixnow_dev', // the disposable dev database
  'user',
  'password',
  'pass',
  'test',
  'x',
  // The token this repository's own `.env.example` uses, and which
  // `backend/test/setup.ts` and `test/app.e2e-spec.ts` copy. Enumerated from
  // the files rather than guessed, because a placeholder this scanner does not
  // know about is a false positive on every run - and a gate that reports the
  // same harmless findings every time is a gate people learn to ignore, which is
  // worse than no gate.
  'replace-me',
]);

/**
 * Each rule is anchored to a credential this project actually integrates with,
 * so a match is a real finding rather than a pattern collision.
 */
const RULES = [
  {
    id: 'huggingface-token',
    why: 'HuggingFace inference token (AI_PROVIDER=huggingface)',
    pattern: /\bhf_[A-Za-z0-9]{30,}\b/,
    sample: `HF_TOKEN=hf_${'a'.repeat(34)}`,
  },
  {
    id: 'openrouteservice-key',
    why: 'OpenRouteService API key (road routing)',
    // Anchored to the variable name, because an ORS key has no prefix.
    //
    // The previous pattern was `eyJhbGciOi[A-Za-z0-9_-]{60,}`, on the reasoning
    // that "ORS keys are JWTs, so the literal header is a reliable signature".
    // Two things are wrong with that. A real JWT header is 36 characters, so
    // after the 9-character `eyJhbGciOi` prefix there are 27 left - the `{60,}`
    // can never be satisfied and the rule matched nothing. And the ORS key found
    // on this machine was not a JWT at all: it began
    // `eyJvcmciOiI1YjNjZTM1...`, which decodes to a custom
    // `{"orm":"...","id":"..."}` header. So the rule would not have caught the
    // exact credential SEC-005 is about - and the self-test, which feeds each
    // rule its own sample, had been reporting this rule as MISSED rather than
    // anyone reading it.
    //
    // A name-anchored long-token rule is the shape that actually holds: a
    // provider-specific variable name plus a base64url blob long enough not to
    // be a hash fragment or an identifier.
    pattern:
      /(?:OPENROUTESERVICE|OPENROUTE)[A-Z_]*\s*[=:]\s*['"]?(eyJ[A-Za-z0-9_-]{40,})/i,
    sample: `OPENROUTESERVICE_API_KEY=eyJ${'b'.repeat(60)}`,
  },
  {
    id: 'jwt-secret',
    why: 'JWT signed with a shared secret (any HS256 token in source)',
    // The shape above, corrected: three base64url segments, of which the header
    // is the standard HS256 one. Kept as its own rule because a signed JWT
    // checked into source is a leak regardless of which service issued it.
    pattern: /eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{20,}/,
    sample: `TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.${'d'.repeat(24)}.${'e'.repeat(43)}`,
  },
  {
    // `rzp_live` only. Razorpay publishes `rzp_test` keys in its own docs, they
    // are not credentials, and flagging them teaches people to ignore the rule.
    id: 'razorpay-live',
    why: 'Razorpay live key',
    pattern: /\brzp_live_[A-Za-z0-9]{10,}\b/,
    sample: `RAZORPAY_KEY_ID=rzp_live_${'c'.repeat(16)}`,
  },
  {
    id: 'stripe-live',
    why: 'Stripe live secret key',
    pattern: /\bsk_live_[A-Za-z0-9]{10,}\b/,
    sample: `STRIPE_SECRET=sk_live_${'d'.repeat(24)}`,
  },
  {
    id: 'aws-access-key-id',
    why: 'AWS access key id',
    pattern: /\bAKIA[0-9A-Z]{16}\b/,
    sample: `AWS_ACCESS_KEY_ID=AKIA${'E'.repeat(16)}`,
  },
  {
    id: 'private-key-block',
    why: 'PEM private key block',
    pattern: /-----BEGIN (?:RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----/,
    sample: `-----BEGIN ${'PRIVATE KEY'}-----
PLACEHOLDER-KEY-BODY
-----END ${'PRIVATE KEY'}-----`,
  },
  {
    id: 'google-api-key',
    why: 'Google API key (Maps, Places, Firebase)',
    // Firebase *client* keys are excluded by shape, not by path. A client key
    // ships inside every APK and is readable by anyone who unzips one, so
    // treating it as a secret produces a finding on every correctly configured
    // mobile project. A server key is a different matter: it is prefixed
    // `AIza` and followed by `_` in the variable name that receives it.
    //
    // The distinction that actually matters is enforced elsewhere, by
    // `checkIgnoreIntegrity`, which requires `google-services.json` to be
    // gitignored. Flagging the key itself would only teach people to ignore the
    // rule.
    pattern:
      /(?:^|[^A-Za-z0-9])(AIza[A-Za-z0-9_-]{35})(?![A-Za-z0-9_-]*_[A-Za-z0-9_-]*$)/,
    sample: `GOOGLE_MAPS_API_KEY=AIza${'f'.repeat(35)}`,
    // `where` carries a provenance suffix - `(untracked)`, `(history)` - so the
    // comparison is on the path rather than on the whole label. Getting this
    // wrong would report a correctly configured mobile project on every run.
    allow: (m) => /(^|\/)google-services\.json/.test(stripProvenance(currentFile)),
  },

  {
    id: 'slack-token',
    why: 'Slack API token',
    pattern: /\bxox[baprs]-[A-Za-z0-9-]{10,}\b/,
    sample: `SLACK=xoxb-${'1'.repeat(12)}-${'2'.repeat(24)}`,
  },
  {
    id: 'npm-token',
    why: 'npm publish token',
    pattern: /\bnpm_[A-Za-z0-9]{30,}\b/,
    sample: `NPM_TOKEN=npm_${'g'.repeat(36)}`,
  },
  {
    id: 'postgres-url-with-password',
    why: 'PostgreSQL URL carrying an inline password',
    pattern: /postgres(?:ql)?:\/\/[A-Za-z0-9_.-]+:([^@\s/"']{4,})@/,
    sample: `DATABASE_URL=postgresql://app:${'s3cr3t'}value@db.internal:5432/fixnow`,
    allow: (m) => PLACEHOLDER_POSTGRES_PASSWORDS.has(m[1].toLowerCase()),
  },
];

/** Directories never worth walking. */
const SKIP_DIRS = new Set([
  'node_modules', '.git', '.dart_tool', 'build', 'dist', '.next', '.turbo',
  '.gradle', 'coverage', 'Pods', '.idea', '.cache', '.tmp',
]);

/**
 * Vendored third-party trees that `.gitignore` already lists as not ours.
 *
 * This is a performance fix with a correctness consequence. `.claude/skills`
 * and `.agents/skills` hold 615 tracked files of other people's documentation
 * and scripts - and because git tracks them, the working-tree scan reads and
 * regex-scans every one. This script had never completed a run on this
 * repository, which is the exact failure it exists to prevent: a gate that is
 * too slow to run is a gate that reports nothing.
 *
 * They are skipped because they are not this repository's code to audit, and
 * because a credential in a vendored skill is that project's problem, not ours.
 * `checkIgnoreIntegrity` still asserts both paths are ignored - and, as of the
 * change below, that they are not *also* tracked, which is the contradiction
 * that made the ignore check misleading.
 */
const SKIP_DIRS_VENDORED = new Set(['.claude', '.agents']);

/**
 * Files above this size are not scanned.
 *
 * A hand-typed credential lives in a config file, a source file or a committed
 * artefact. This repository's largest tracked file is 88 KB; the 60 MB file in
 * the working tree is a Gradle build cache. Reading whole build caches as utf8
 * to run ten regexes over them is the difference between a gate that runs in
 * seconds and one that does not finish.
 */
const MAX_SCAN_BYTES = 1024 * 1024;

/** Binary or generated files that cannot contain a hand-typed credential. */
const SKIP_EXT = new Set([
  '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.pdf', '.zip', '.gz',
  '.woff', '.woff2', '.ttf', '.otf', '.mp3', '.mp4', '.wasm', '.so', '.dll',
  '.lock', '.jar',
]);

/**
 * Untracked files that legitimately hold a credential-shaped value. Named
 * explicitly so that adding a new one fails the scan rather than quietly
 * joining this list.
 */
const ALLOWED_UNTRACKED = [
  { path: '.env', why: 'local developer credentials; gitignored' },
  { path: 'backend/.env', why: 'local developer credentials; gitignored' },
  { path: 'admin/.env.local', why: 'Next.js local overrides; gitignored' },
];

/** Tracked files skipped for being over MAX_SCAN_BYTES, reported not hidden. */
const skippedLarge = [];

const findings = [];
const scannerErrors = [];

/**
 * The file currently being scanned.
 *
 * A rule needs it when the answer depends on where a value lives rather than on
 * what it looks like - which is the case for a Firebase client key in
 * `google-services.json`, where the key itself is public by design and the thing
 * worth controlling is that the file is gitignored.
 */
let currentFile = '';

/**
 * Strips the provenance a finding label carries - ` (untracked)`, ` (history)` -
 * so a rule can compare against the path. The label is for humans; a rule
 * matching on it would have to know about the decoration, and would silently
 * stop matching the moment someone improves the wording.
 */
function stripProvenance(where) {
  return where.replace(/\s+\((?:untracked|history)\)$/, '');
}

function scanText(text, where) {
  currentFile = where;
  for (const rule of RULES) {
    // A global copy, consumed with `matchAll`.
    //
    // This loop used to be `while ((match = re.exec(text)) !== null)` on a
    // non-global regex, which cannot advance: `lastIndex` is ignored without
    // `g`, so every call returns the *same first match*. On a rule whose match
    // was allowed - which is exactly what the placeholder-password allow list
    // does - the `continue` sent it round again and the scanner looped forever.
    //
    // That is not a theoretical defect. This script has never completed a run on
    // this repository, because `.github/workflows/ci.yml` has always carried the
    // postgres service-container URL
    // (`postgresql://postgres:postgres@localhost:5432/...`) whose password is on
    // the allow list by design. A gate that hangs on its own documented
    // fixtures is a gate that reports nothing - which is the entire failure this
    // script was written to prevent, reproduced inside the script itself.
    //
    // `matchAll` requires `g`, is given a fresh regex each call so no state is
    // shared between files, and handles the zero-length-match case that a bare
    // `exec` loop cannot.
    const flags = rule.pattern.flags.includes('g')
      ? rule.pattern.flags
      : `${rule.pattern.flags}g`;
    const re = new RegExp(rule.pattern.source, flags);

    for (const match of text.matchAll(re)) {
      let allowed = false;
      try {
        allowed = rule.allow ? Boolean(rule.allow(match)) : false;
      } catch (error) {
        // Previously a throw here propagated to the caller's catch-all, which
        // aborted the whole file silently and reported "clean". A rule that
        // cannot be evaluated must be loud, not absent.
        scannerErrors.push(
          `${rule.id} failed on ${where}: ${error instanceof Error ? error.message : String(error)}`,
        );
        break;
      }
      if (allowed) continue;
      // Never echo the secret: enough to locate it, not to reuse it.
      findings.push({
        id: rule.id,
        why: rule.why,
        where,
        sample: `${match[0].slice(0, 6)}...[${match[0].length} chars]`,
      });
      break; // one finding per rule per file is enough to act on
    }
  }
}

function* walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (SKIP_DIRS.has(entry.name)) continue;
    if (SKIP_DIRS_VENDORED.has(entry.name)) continue;
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      yield* walk(full);
      continue;
    }
    if (SKIP_EXT.has(full.slice(full.lastIndexOf('.')).toLowerCase())) continue;
    yield full;
  }
}

function git(args, opts = {}) {
  return execFileSync('git', args, {
    cwd: REPO_ROOT,
    encoding: 'utf8',
    maxBuffer: 512e6,
    ...opts,
  });
}

/** 1 + 2: every tracked file, plus every untracked file the walk reaches. */
function scanWorkingTree() {
  const allowedUntracked = new Set(ALLOWED_UNTRACKED.map((e) => e.path));
  const tracked = new Set(git(['ls-files']).split('\n').filter(Boolean));

  // There is deliberately no `git ls-files --others --ignored` call here.
  //
  // It was there to avoid re-scanning untracked files that git already ignores,
  // and it cost a full enumeration of every ignored directory on the machine -
  // `node_modules` for four projects, build caches, and whatever else happens to
  // be gitignored. On a developer machine that is tens of thousands of paths,
  // and it is unbounded rather than merely slow: a directory being created and
  // deleted underneath the walk (a tool cache, a package manager, an editor
  // index) makes git retry and this script never finish. That is how a gate
  // ends up reporting nothing - the failure this script exists to prevent.
  //
  // Removing it costs nothing and gains coverage. The walk already skips
  // `node_modules`, `build`, `dist`, `.next` and the rest by name, so the
  // directories that made the enumeration expensive are still skipped - and the
  // untracked files that remain are now scanned rather than skipped, which is
  // the correct default for a scanner. A gitignored file is not a safe file; the
  // only ones treated as safe are the three named in `ALLOWED_UNTRACKED`, and
  // they are skipped by name.
  const ignored = new Set();

  for (const file of tracked) {
    const rel = file.split(sep).join('/');
    // A tracked file under a vendored tree is third-party content, and there are
    // 615 of them. `checkIgnoreIntegrity` now reports the contradiction
    // separately, so skipping them here does not hide it.
    if (SKIP_DIRS_VENDORED.has(rel.split('/')[0])) continue;
    const full = join(REPO_ROOT, file);
    if (!existsSync(full)) continue;
    try {
      // The size cap, not a `catch`: `readFileSync` on a 60 MB build cache
      // succeeds and then spends minutes in ten regexes, which no error handler
      // can distinguish from slow.
      if (statSync(full).size > MAX_SCAN_BYTES) {
        skippedLarge.push(file);
        continue;
      }
      scanText(readFileSync(full, 'utf8'), file);
    } catch {
      /* unreadable or binary: nothing to scan */
    }
  }

  let staged = 0;
  for (const file of walk(REPO_ROOT)) {
    const rel = relative(REPO_ROOT, file).split(sep).join('/');
    if (allowedUntracked.has(rel)) continue;
    if (tracked.has(rel)) continue;
    if (ignored.has(rel)) continue;
    staged += 1;
    try {
      if (statSync(join(REPO_ROOT, rel)).size > MAX_SCAN_BYTES) {
        skippedLarge.push(rel);
        continue;
      }
      scanText(readFileSync(join(REPO_ROOT, rel), 'utf8'), `${rel} (untracked)`);
    } catch {
      /* unreadable or binary: nothing to scan */
    }
  }
  return staged;
}

/**
 * 3: every blob reachable from any ref.
 *
 * Streamed through one `git cat-file --batch`. Spawning a process per blob - the
 * obvious implementation - took over fifteen minutes on this history.
 */
function scanHistory() {
  const objectList = git(['rev-list', '--objects', '--all']);
  const seen = new Set();
  const wanted = [];
  for (const line of objectList.split('\n')) {
    if (!line) continue;
    const space = line.indexOf(' ');
    const sha = line.slice(0, space);
    if (seen.has(sha)) continue;
    const path = space < 0 ? '' : line.slice(space + 1);
    if (path && SKIP_EXT.has(path.slice(path.lastIndexOf('.')).toLowerCase())) {
      continue;
    }
    seen.add(sha);
    wanted.push({ sha, path });
  }
  if (wanted.length === 0) return { blobs: 0, missing: 0 };

  const result = spawnSync('git', ['cat-file', '--batch', '--buffer'], {
    cwd: REPO_ROOT,
    input: `${wanted.map(({ sha }) => sha).join('\n')}\n`,
    encoding: 'utf8',
    maxBuffer: 1024e6,
  });
  const raw = result.stdout ?? '';
  let cursor = 0;
  let index = 0;
  let missing = 0;
  let scanned = 0;

  while (index < wanted.length) {
    const headerEnd = raw.indexOf('\n', cursor);
    if (headerEnd < 0) break;
    const [sha, , sizeRaw] = raw.slice(cursor, headerEnd).split(' ');
    const size = Number(sizeRaw);
    cursor = headerEnd + 1;
    if (!Number.isFinite(size)) {
      missing += 1; // a broken or partially-fetched object
      index += 1;
      continue;
    }
    const body = raw.slice(cursor, cursor + size);
    cursor += size + 1;
    index += 1;
    if (body.includes('\0')) continue;
    // Same bound as the working tree, and for the same reason: a historical
    // build artefact is megabytes of base64, and scanning it buys nothing.
    if (size > MAX_SCAN_BYTES) {
      skippedLarge.push(`${sha.slice(0, 8)} (history, ${size} bytes)`);
      continue;
    }
    scanned += 1;
    const entry = wanted.find((e) => e.sha === sha);
    scanText(body, `${sha.slice(0, 8)}:${entry?.path ?? ''} (history)`);
  }
  return { blobs: scanned, missing };
}

/**
 * 4: the ignore rules the first two checks depend on must still work.
 *
 * `.gitignore` in this repository contained UTF-16 fragments with embedded NUL
 * bytes, which silently killed the `.cursor/` rule, and was missing four whole
 * vendored directories. A corrupted ignore file is a security control that
 * looks fine and is not.
 *
 * Each required path is also checked for the opposite failure, which is the one
 * this version was written to catch: `git check-ignore --no-index` answers
 * "would this be ignored", and answers yes for a path that is *already tracked*.
 * `.claude/` and `.agents/` are both listed in `.gitignore` and both hold tracked
 * files - 615 of them - so the original version of this check reported them as
 * protected while they sat in the repository. An ignore rule and a tracked file
 * are not in conflict; the tracked file wins, and the rule does nothing.
 */
function checkIgnoreIntegrity() {
  const required = [
    { path: '.env', why: 'local credentials' },
    { path: 'backend/.env', why: 'local credentials' },
    { path: 'admin/.env.local', why: 'Next.js local overrides' },
    { path: 'reports/', why: 'generated reports quote code verbatim' },
    { path: 'outputs/', why: 'generated output' },
    { path: 'google-services.json', why: 'Firebase config' },
    { path: '.cursor/', why: 'editor config, sometimes holding MCP tokens' },
    {
      path: '.agents/',
      why: 'vendored agent tooling',
      // Vendored third-party trees. Tracked copies are a contradiction rather
      // than a leak, and they were the reason this scan never finished a run.
      alsoMustNotBeTracked: true,
    },
    { path: '.claude/', why: 'agent tooling', alsoMustNotBeTracked: true },
  ];
  for (const { path, why, alsoMustNotBeTracked } of required) {
    let ignoredOk = false;
    try {
      execFileSync('git', ['check-ignore', '-q', '--no-index', path], {
        cwd: REPO_ROOT,
      });
      ignoredOk = true;
    } catch {
      ignoredOk = false;
    }
    if (!ignoredOk) {
      findings.push({
        id: 'gitignore-gap',
        why: `"${path}" is not ignored, so ${why} can be committed`,
        where: '.gitignore',
        sample: `add: ${path}`,
      });
    }

    if (!alsoMustNotBeTracked) continue;
    const prefix = path.replace(/\/$/, '');
    const tracked = git(['ls-files', '--', prefix])
      .split('\n')
      .filter(Boolean);
    if (tracked.length === 0) continue;
    findings.push({
      id: 'ignored-but-tracked',
      why:
        `"${path}" is in .gitignore but ${tracked.length} file(s) under it are ` +
        `tracked. The ignore rule does nothing for tracked paths, so ${why} is ` +
        `in the repository and its contents were being scanned as ours`,
      where: `${prefix}/`,
      sample: `git rm -r --cached ${prefix}   # ${tracked.length} file(s)`,
    });
  }
}

/**
 * Proves the rules still fire. A scanner reporting "clean" is
 * indistinguishable from one that stopped looking, so this is the check that
 * makes "clean" mean something.
 */
function selfTest() {
  let failed = 0;
  for (const rule of RULES) {
    const before = findings.length;
    scanText(rule.sample, `self-test:${rule.id}`);
    const fired = findings.length > before;
    if (!fired) failed += 1;
    console.log(
      `  ${fired ? 'detects' : 'MISSED  '}  ${rule.id.padEnd(24)} ${rule.why}`,
    );
  }

  // And the other direction: the documented placeholders must NOT fire.
  const allowed = [
    'postgresql://postgres:postgres@localhost:5432/fixnow_ci',
    'postgresql://fixnow_test:fixnow_test@127.0.0.1:55432/fixnow_test',
    'postgresql://user:password@127.0.0.1:5432/fixnow_dev',
    'RAZORPAY_KEY_ID=rzp_test_key',
    'RAZORPAY_KEY_SECRET=rzp_test_secret',
  ];
  for (const text of allowed) {
    const before = findings.length;
    scanText(text, 'self-test:allowlist');
    if (findings.length > before) {
      failed += 1;
      console.log(`  FALSE POSITIVE on documented placeholder: ${text}`);
    }
  }

  if (failed > 0) {
    console.error(`\nself-test: ${failed} failure(s)`);
    process.exit(1);
  }

  // The regression that mattered most, and the one this script could not
  // previously detect: a rule whose match is ALLOWED must still terminate.
  //
  // `scanText` advanced with a bare `re.exec` on a non-global regex, so an
  // allowed match was returned again on every iteration and the loop never
  // finished. The documented placeholder below is in `.github/workflows/ci.yml`,
  // so the scanner hung on the repository's own CI file and had never once
  // reported a result. Every rule firing proves the rules work; this proves the
  // scan terminates on the case that broke it.
  const placeholderUrl =
    'DATABASE_URL=postgresql://postgres:postgres@localhost:5432/fixnow_ci';
  const beforeTermination = findings.length;
  scanText(placeholderUrl, 'self-test:allowed-match-terminates');
  if (findings.length !== beforeTermination) {
    console.error(
      '  FALSE POSITIVE: a documented placeholder was reported as a finding',
    );
    failed += 1;
  }

  if (failed > 0) {
    console.error(`\nself-test: ${failed} failure(s)`);
    process.exit(1);
  }
  console.log(
    `\nself-test: all ${RULES.length} rules fire, ${allowed.length} documented ` +
      `placeholders do not, and an allowed match terminates.`,
  );
  process.exit(0);
}

if (process.argv.includes('--self-test')) {
  console.log('scan-secrets self-test\n');
  selfTest();
}

const untrackedCount = scanWorkingTree();
const history = scanHistory();
checkIgnoreIntegrity();

for (const error of scannerErrors) {
  console.error(`scan-secrets: RULE ERROR  ${error}`);
}

if (findings.length === 0 && scannerErrors.length === 0) {
  console.log(
    `scan-secrets: clean (${history.blobs} history blobs across all refs, ` +
      `${untrackedCount} untracked-not-ignored files, ${RULES.length} rules` +
      (history.missing ? `; ${history.missing} objects missing from this clone` : '') +
      (skippedLarge.length
        ? `; ${skippedLarge.length} file(s) over ${MAX_SCAN_BYTES / 1024 / 1024}MB not scanned`
        : '') +
      ')',
  );
  process.exit(0);
}

console.error(`scan-secrets: ${findings.length + scannerErrors.length} finding(s)\n`);
for (const finding of findings) {
  console.error(`  [${finding.id}] ${finding.where}`);
  console.error(`      ${finding.why}`);
  console.error(`      ${finding.sample}`);
}
console.error('\nIf a finding is a real credential: rotate it FIRST, then remove it.');
process.exit(1);
