import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

/**
 * TEST-001: a spec must exercise the product.
 *
 * The three specs this replaced were 17 lines each and proved only that
 * Playwright could set content on a blank page:
 *
 *   await page.goto('about:blank');
 *   await page.setContent('<h1>FixNow Customer App</h1>');
 *   expect(await page.locator('h1').textContent()).toBe('FixNow Customer App');
 *
 * They would pass with the entire application deleted. CI had no e2e job, so
 * they had never been executed by anything either.
 *
 * These are the patterns that make a spec assert nothing about FixNow. They are
 * banned by name rather than by judgement, because "does this test test
 * something" is not a question a linter can answer - but "does this test open a
 * blank page and assert its own markup" is exactly answerable, and it is how the
 * failure happened.
 */
const banned: ReadonlyArray<{ pattern: RegExp; why: string }> = [
  {
    pattern: /\bsetContent\s*\(/,
    why: 'writes the markup it then asserts, so it tests the test file',
  },
  {
    pattern: /\babout:blank\b/,
    why: 'there is no application at about:blank',
  },
  {
    pattern: /\bdata:text\/html\b/,
    why: 'a data: URL is the same trick as setContent',
  },
  {
    pattern: /locator\(\s*['"`]body['"`]\s*\)\s*\.?(textContent|innerText)\s*\(/,
    why: 'asserting on the whole body asserts nothing',
  },
];

/**
 * Strips comments, so a file that explains why a pattern is banned does not ban
 * itself by naming it.
 *
 * This is a scanner, not a parser, and being wrong about tokenisation is the one
 * failure mode that matters - a mis-stripped line would either hide a real
 * offence or invent a false one. The version written first dropped a line only
 * when it saw `//`, which is why the doc comment here, whose continuation lines
 * start with `*` and carry no `//`, matched `about:blank` and failed the run.
 *
 * So comment entry is tracked as state across the whole file rather than
 * detected per line: a block-comment opener closes on the matching terminator, a
 * line comment runs to the end of its line, and a string opened inside code is
 * left alone.
 */
function codeLines(source: string): string[] {
  const out: string[] = [];
  let inBlockComment = false;

  for (const line of source.split(/\r?\n/)) {
    let outLine = '';
    let quote: string | null = null;

    for (let i = 0; i < line.length; i += 1) {
      if (inBlockComment) {
        if (line[i] === '*' && line[i + 1] === '/') {
          inBlockComment = false;
          i += 1;
        }
        continue;
      }

      const char = line[i];

      if (quote) {
        if (char === '\\') {
          outLine += char;
          i += 1;
          if (i < line.length) outLine += line[i];
          continue;
        }
        if (char === quote) quote = null;
        // String contents are kept: a real offence lives inside quotes.
        outLine += char;
        continue;
      }

      if (char === "'" || char === '"' || char === '`') {
        quote = char;
        outLine += char;
        continue;
      }

      if (char === '/' && line[i + 1] === '/') break;
      if (char === '/' && line[i + 1] === '*') {
        inBlockComment = true;
        i += 1;
        continue;
      }
      outLine += char;
    }

    out.push(outLine);
  }

  return out;
}

function specFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true })
    .flatMap((entry) => {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) return specFiles(path);
      return entry.name.endsWith('.spec.ts') ? [path] : [];
    });
}

const specs = specFiles(join(process.cwd(), 'tests'));
const violations: string[] = [];

if (specs.length === 0) {
  violations.push('tests/ contains no *.spec.ts files');
}

for (const spec of specs) {
  const lines = codeLines(readFileSync(spec, 'utf8'));
  for (const { pattern, why } of banned) {
    lines.forEach((line, index) => {
      if (pattern.test(line)) {
        violations.push(
          `${spec}:${index + 1}: ${why}\n      ${line.trim()}`,
        );
      }
    });
  }
}

// A journey that never navigates cannot have exercised a real page.
for (const spec of specs) {
  const source = readFileSync(spec, 'utf8');
  if (!/page\.goto\(/.test(source)) {
    violations.push(`${spec}: never calls page.goto(), so it drives no application`);
  }
}

if (violations.length > 0) {
  throw new Error(
    [
      'An end-to-end spec that does not exercise the product:',
      ...violations.map((line) => `  - ${line}`),
      '',
      'See e2e/tests/admin-access.spec.ts for what a real journey looks like.',
    ].join('\n'),
  );
}

process.stdout.write(
  `e2e spec guard: ${specs.length} spec(s) checked, none assert against markup they wrote themselves.\n`,
);
