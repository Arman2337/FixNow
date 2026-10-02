/**
 * Fails when the deploy definition and the code disagree about configuration.
 *
 * `render.yaml` was setting `AI_PROVIDER_API_KEY`, a variable that exists
 * nowhere in the backend: `ai.module.ts` reads `HF_TOKEN`. The secret was
 * collected for nothing and the credential that was actually needed was never
 * delivered, and nothing reported either fact.
 *
 * Two directions matter:
 *
 * 1. Every key `render.yaml` declares must be one the code knows. A key the
 *    code never reads is a secret being collected with no effect.
 * 2. Every key the code requires with no default must be declared in
 *    `render.yaml`. A required key that is missing from the deploy definition
 *    is a crash-loop waiting for the next deploy.
 *
 * Usage: npm run deploy:verify-env
 */
import { readdirSync, readFileSync } from 'fs';
import { join } from 'path';
import { EnvironmentVariables } from '../src/config/env.validation';

const REPO_ROOT = join(__dirname, '..', '..');
const RENDER_YAML = join(REPO_ROOT, 'render.yaml');
const VALIDATION_TS = join(
  REPO_ROOT,
  'backend',
  'src',
  'config',
  'env.validation.ts',
);

/** Keys declared on the EnvironmentVariables class, and which have a default. */
function declaredVariables(): { keys: Set<string>; required: Set<string> } {
  const source = readFileSync(VALIDATION_TS, 'utf8');
  const start = source.indexOf('export class EnvironmentVariables');
  if (start < 0) {
    throw new Error('could not find the EnvironmentVariables class');
  }
  // The class runs to the first line that is exactly "}".
  const end = source.indexOf('\n}', start);
  const body = source.slice(start, end < 0 ? source.length : end);

  const keys = new Set<string>();
  const required = new Set<string>();
  // A declaration with a type but no "?" and no "=" has no default.
  const declaration =
    /^\s{2}([A-Z][A-Z0-9_]*)([!?])?\s*:\s*([^=;]+)(=\s*[^;]+)?;/gm;
  let match: RegExpExecArray | null;
  while ((match = declaration.exec(body)) !== null) {
    const [, name, optional, , hasDefault] = match;
    keys.add(name);
    if (!optional && !hasDefault) {
      required.add(name);
    }
  }
  return { keys, required };
}

/**
 * Reads the `envVars:` keys out of render.yaml.
 *
 * Deliberately not a full YAML parse: `js-yaml` is present but untyped, and
 * adding `@types/js-yaml` for one flat list is not worth a new dependency. The
 * block is required to be found, so reformatting the file fails loudly rather
 * than silently reporting zero keys.
 */
function renderEnvKeys(): string[] {
  const lines = readFileSync(RENDER_YAML, 'utf8').split(/\r?\n/);
  const start = lines.findIndex((line) => /^\s*envVars:\s*$/.test(line));
  if (start < 0) {
    throw new Error('render.yaml has no envVars block');
  }
  const keys: string[] = [];
  for (const line of lines.slice(start + 1)) {
    const entry = /^\s{6}-\s*key:\s*(\S+)\s*$/.exec(line);
    if (entry) {
      keys.push(entry[1]);
      continue;
    }
    // Dedenting past four spaces means the envVars block has ended.
    if (/^\s{0,4}\S/.test(line)) {
      break;
    }
  }
  if (keys.length === 0) {
    throw new Error('render.yaml envVars block contained no keys');
  }
  return keys;
}

/**
 * Keys read straight from `process.env` rather than through the validated
 * config class - the private S3 adapter does this. Ignoring them would report
 * working configuration as dead, which is worse than not checking at all.
 */
function directlyReadVariables(): Set<string> {
  const root = join(REPO_ROOT, 'backend', 'src');
  const keys = new Set<string>();
  const patterns = [
    /process\.env\.([A-Z][A-Z0-9_]*)/g,
    /process\.env\[['"]([A-Z][A-Z0-9_]*)['"]\]/g,
    /requiredEnvironment\(['"]([A-Z][A-Z0-9_]*)['"]\)/g,
  ];
  const walk = (dir: string): void => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
        continue;
      }
      if (!entry.name.endsWith('.ts') || entry.name.endsWith('.spec.ts')) {
        continue;
      }
      const source = readFileSync(full, 'utf8');
      for (const pattern of patterns) {
        let match: RegExpExecArray | null;
        while ((match = pattern.exec(source)) !== null) {
          keys.add(match[1]);
        }
      }
    }
  };
  walk(root);
  return keys;
}

function main(): void {
  const { keys: declaredByClass, required } = declaredVariables();
  const direct = directlyReadVariables();
  const known = new Set([...declaredByClass, ...direct]);
  const declared = renderEnvKeys();

  // Proves the class import is real and the type is what we think it is.
  if (typeof EnvironmentVariables !== 'function') {
    throw new Error('EnvironmentVariables is not a class');
  }

  const problems: string[] = [];

  const unknown = declared.filter((key) => !known.has(key));
  for (const key of unknown) {
    problems.push(
      `render.yaml sets ${key}, which the backend never reads. Either the ` +
        `code reads a different name, or this secret is collected with no effect.`,
    );
  }

  const missing = [...required].filter((key) => !declared.includes(key));
  for (const key of missing) {
    problems.push(
      `${key} is required by the code with no default, but render.yaml does ` +
        `not declare it, so a production deploy cannot supply it.`,
    );
  }

  console.log(
    `EnvironmentVariables declares ${declaredByClass.size} keys ` +
      `(${required.size} required); ${direct.size} more are read from process.env`,
  );
  console.log(`render.yaml declares ${declared.length} keys`);
  console.log('');

  if (problems.length > 0) {
    console.error(`${problems.length} deployment/config disagreement(s):`);
    for (const problem of problems) {
      console.error(`  - ${problem}`);
    }
    process.exit(1);
  }

  console.log('render.yaml and the backend configuration agree.');
}

main();
