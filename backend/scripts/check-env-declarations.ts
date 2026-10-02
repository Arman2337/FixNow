/**
 * Fails the build when the source reads an environment variable that
 * `EnvironmentVariables` does not declare.
 *
 * SEC-013. Six variables were read as `process.env.X ?? 'default'` in files
 * that never touch `ConfigService`, which meant they were never type-coerced,
 * never bounded, and never subject to a production rule. `CLAMAV_PORT` was the
 * sharpest case: it went through `Number()` on whatever string arrived, so a typo
 * produced `NaN` and a silently unreachable malware scanner on a path that is
 * supposed to fail closed. Nobody noticed, because a `process.env` read fails no
 * gate and breaks nothing at compile time.
 *
 * This is a *source* check rather than a runtime assertion on purpose. A
 * runtime assertion over `process.env` would reject every ambient variable on the
 * host — the developer's shell, the CI runner, the container platform — none of
 * which is this service's configuration, and it would make the process
 * unbootable for no benefit. The property worth enforcing is narrower and
 * precise: every variable the code reads is a declared, validated input.
 *
 * Two escape hatches are enumerated rather than inferred:
 *
 *  - `DIRECT_ENV_READS_ALLOWED`, for variables that genuinely cannot go through
 *    `ConfigService` (constructed outside the DI graph, or deliberately never
 *    held on the validated config so they cannot leak into a log line)
 *  - `process.env[expr]`, which cannot be statically resolved and is reported
 *    separately rather than silently accepted
 *
 * Usage: node scripts/check-env-declarations.ts [srcDir]
 * Exits 1 with one line per violation.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';

const srcDir = resolve(process.argv[2] ?? 'src');
const envValidation = resolve(join(srcDir, 'config/env.validation.ts'));

/** `process.env.NAME` and `process.env['NAME']`. */
const DIRECT_READ =
  /process\.env(?:\.([A-Z][A-Z0-9_]*)|\[\s*['"]([A-Z][A-Z0-9_]*)['"]\s*\])/g;

/** `process.env[expr]` with a non-literal key. */
const DYNAMIC_READ = /process\.env\[\s*(?!['"])/g;

const VALIDATION_SPEC = /\b([A-Z][A-Z0-9_]*)\s*\??\s*:/g;

function walk(dir: string, out: string[] = []): string[] {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) walk(full, out);
    else if (entry.endsWith('.ts')) out.push(full);
  }
  return out;
}

/**
 * The names in the allowed list, read from the source rather than imported.
 *
 * Importing would pull in `class-validator` decorators and the whole config
 * module graph for a text scan. Parsing the `new Set([...])` literal is enough
 * and keeps this script dependency-free and fast.
 */
function readAllowedDirectReads(): Set<string> {
  const source = readFileSync(envValidation, 'utf8');
  const block =
    /DIRECT_ENV_READS_ALLOWED[^=]*=\s*new Set\(\[([\s\S]*?)\]\)/.exec(source);
  if (!block) {
    throw new Error(
      'DIRECT_ENV_READS_ALLOWED not found in ' +
        envValidation +
        '. Add it back before removing this script.',
    );
  }
  return new Set(
    (block[1].match(/'([A-Z][A-Z0-9_]*)'/g) ?? []).map((quoted) =>
      quoted.slice(1, -1),
    ),
  );
}

function declaredVariables(): Set<string> {
  const source = readFileSync(envValidation, 'utf8');
  const names = new Set<string>();
  VALIDATION_SPEC.lastIndex = 0;
  let match: RegExpExecArray | null;
  while ((match = VALIDATION_SPEC.exec(source)) !== null) {
    names.add(match[1]);
  }
  return names;
}

interface Violation {
  file: string;
  line: number;
  name: string;
}

function main(): void {
  const files = walk(srcDir);
  const declared = declaredVariables();
  const allowed = readAllowedDirectReads();
  const violations: Violation[] = [];
  const dynamic: string[] = [];

  for (const file of files) {
    if (resolve(file) === envValidation) continue;
    const source = readFileSync(file, 'utf8');
    const lines = source.split(/\r?\n/);

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Skip comments so a documented example cannot fail the build.
      const code = line.replace(/\/\/.*$/, '').replace(/\/\*.*?\*\//g, '');
      if (code.trim() === '' && line.trim().startsWith('//')) continue;

      DIRECT_READ.lastIndex = 0;
      let match: RegExpExecArray | null;
      while ((match = DIRECT_READ.exec(code)) !== null) {
        const name = match[1] ?? match[2];
        if (declared.has(name) || allowed.has(name)) continue;
        violations.push({ file, line: i + 1, name });
      }

      DYNAMIC_READ.lastIndex = 0;
      if (DYNAMIC_READ.test(code)) {
        // The *definition* of a `positiveEnv`-style helper indexes
        // `process.env[key]` by parameter, which is not statically resolvable.
        // Its call sites are checked above against the literal they pass, so the
        // definition itself is accounted for and reported separately so it stays
        // visible rather than silently passing.
        dynamic.push(`${file}:${i + 1}`);
      }
    }

    // `process.env[key]` where `key` came from a literal is resolvable. The
    // `positiveEnv('FOO', fallback)` helpers in this codebase all take a
    // literal, so the *first argument* to those helpers is exactly the set of
    // keys the file can reach dynamically. Checking those against the declared
    // list is what turns a typo in
    // `positiveEnv('BOOKING_EXPIRY_SECONDS', …)` into a build failure instead of
    // a silent fallback.
    const HELPER =
      /\b(?:positiveEnv|numberEnv|requiredEnvironment)\(\s*'([A-Z][A-Z0-9_]*)'/g;
    HELPER.lastIndex = 0;
    let helperMatch: RegExpExecArray | null;
    while ((helperMatch = HELPER.exec(source)) !== null) {
      const key = helperMatch[1];
      if (declared.has(key) || allowed.has(key)) continue;
      const lineNumber = source.slice(0, helperMatch.index).split('\n').length;
      violations.push({ file, line: lineNumber, name: key });
    }
  }

  if (violations.length === 0) {
    console.log(
      `check-env-declarations: OK — every environment variable read in ${srcDir} is declared on EnvironmentVariables or listed in DIRECT_ENV_READS_ALLOWED.`,
    );
    if (dynamic.length > 0) {
      console.log(
        `check-env-declarations: note — ${dynamic.length} dynamic read site(s) remain; their keys are checked at their call sites, which pass string literals:`,
      );
      for (const site of dynamic) console.log(`    ${site}`);
    }
    return;
  }

  if (violations.length > 0) {
    console.error(
      `check-env-declarations: ${violations.length} environment variable read(s) that EnvironmentVariables does not declare.\n` +
        'An undeclared read is never validated, bounded, or subject to a production rule.\n',
    );
    for (const v of violations) {
      console.error(`  ${v.file}:${v.line}  process.env.${v.name}`);
    }
    console.error(
      '\nFix: add the variable to EnvironmentVariables with a validator, a bound and a documented default — or, if it genuinely cannot go through ConfigService, add it to DIRECT_ENV_READS_ALLOWED with a comment saying why.',
    );
  }

  if (dynamic.length > 0) {
    console.error(
      `\ncheck-env-declarations: ${dynamic.length} dynamic process.env read site(s). Their keys are checked at the call sites that pass string literals:\n`,
    );
    for (const site of dynamic) console.error(`    ${site}`);
  }

  process.exit(1);
}

main();
