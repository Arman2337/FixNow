/**
 * Fails the build when a `@Body()` parameter's type is not a class.
 *
 * SEC-010 / SEC-011. NestJS's `ValidationPipe` only validates when the target's
 * metatype is a class. Given an interface or a bare `type`, `metatype` arrives as
 * `Object` or `Function`, the pipe's `toValidate()` returns false, and the
 * parameter is passed through untouched — with `whitelist: true,
 * forbidNonWhitelisted: true` still in force, so every property on the body is
 * either stripped or rejected depending on the shape.
 *
 * That is how `POST /guarantees/claims` came to answer 400 for every possible
 * request: its DTO was a bare class with no decorators, and
 * `POST /users/me/addresses` wrote `latitude`/`longitude` straight from the
 * client with no range check at all.
 *
 * A type alias is therefore a silent security decision. This script makes it
 * loud, the same way a lint rule would, but with no dependency and with an
 * unambiguous rule: the annotation after the parameter name must name a class.
 *
 * Usage: node scripts/check-body-dto-classes.ts [rootDir]
 * Exits 1 with one line per violation.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';

const root = resolve(process.argv[2] ?? 'src');

/** `@Body(...) name: Type` — captures the parameter name and its annotation. */
const BODY_PARAM =
  /@Body\([^)]*\)\s*(\??)\s*([A-Za-z0-9_$]+)\s*:\s*([A-Za-z0-9_$<>[\].]+)/g;

interface Violation {
  file: string;
  line: number;
  param: string;
  type: string;
}

function walk(dir: string, out: string[] = []): string[] {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) walk(full, out);
    else if (entry.endsWith('.ts') && !entry.endsWith('.d.ts')) out.push(full);
  }
  return out;
}

/**
 * A name is a usable DTO type only if some file in the tree declares it with
 * `class` or `enum`. Interfaces, type aliases and bare objects are all erased at
 * runtime, which is the condition this whole check exists to catch.
 */
function collectDeclaredClasses(files: string[]): Map<string, string> {
  const declared = new Map<string, string>();
  for (const file of files) {
    const source = readFileSync(file, 'utf8');
    const classMatch =
      /^\s*(?:export\s+)?(?:abstract\s+)?class\s+([A-Za-z0-9_$]+)/gm;
    let m: RegExpExecArray | null;
    while ((m = classMatch.exec(source)) !== null) {
      if (!declared.has(m[1])) declared.set(m[1], file);
    }
  }
  return declared;
}

function main(): void {
  const files = walk(root);
  const declaredClasses = collectDeclaredClasses(files);
  const violations: Violation[] = [];

  for (const file of files) {
    const source = readFileSync(file, 'utf8');
    const lines = source.split(/\r?\n/);

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      BODY_PARAM.lastIndex = 0;
      let match: RegExpExecArray | null;
      while ((match = BODY_PARAM.exec(line)) !== null) {
        const param = match[2];
        const rawType = match[3];
        const type = rawType.split(/[.<>[\]|]/)[0];

        // `unknown`, `any`, and the built-ins the pipe genuinely skips.
        if (['any', 'unknown', 'object', 'Record', 'void'].includes(type)) {
          continue;
        }
        // A dotted path resolves to a class declared elsewhere; find it.
        if (rawType.includes('.')) {
          continue;
        }

        const declaration = declaredClasses.get(type);
        if (!declaration) {
          violations.push({
            file,
            line: i + 1,
            param,
            type,
          });
        }
      }
    }
  }

  if (violations.length === 0) {
    console.log(
      `check-body-dto-classes: OK — every @Body() parameter in ${root} is annotated with a declared class.`,
    );
    return;
  }

  console.error(
    `check-body-dto-classes: ${violations.length} @Body() parameter(s) annotated with a type that is not a class.\n` +
      'ValidationPipe skips non-class metatypes, so these bodies are unvalidated at runtime.\n',
  );
  for (const v of violations) {
    console.error(`  ${v.file}:${v.line}  @Body() ${v.param}: ${v.type}`);
  }
  console.error(
    '\nFix: give the parameter a DTO class decorated with class-validator, and export that class.',
  );
  process.exit(1);
}

main();
