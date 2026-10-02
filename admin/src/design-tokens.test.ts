import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { describe, expect, it } from "vitest";

/**
 * ADMIN-002. The build gate that was missing.
 *
 * The audit found roughly twenty design tokens referenced in admin code but never
 * defined. `guarantees/[id]/page.tsx` used `--color-accent` and
 * `--color-on-accent` for the primary action of the page, and neither existed -
 * so the button rendered as unstyled browser-default text with no background, no
 * border and no affordance. The same class of bug made every `<h2>` on five of
 * the seven main navigation pages render at browser default size.
 *
 * When this file was first written the `guarantees` case had been fixed, and it
 * would have passed. It did not, because nine *other* tokens were still
 * undefined - `--color-surface-primary`, `--color-border-default`,
 * `--color-text-muted` and the rest - and the booking detail page, the audit
 * trail, the status badge and the cancellation panel were all rendering with
 * declarations that resolved to nothing. That is the lesson: the fix is not
 * patching the reported token, it is the gate.
 *
 * Nothing caught it because a missing custom property is not a build error. It
 * is a silent no-op at runtime, so the only way to catch it is to compare the set
 * of token names the code uses against the set the stylesheet defines.
 *
 * That comparison is this file. It is static analysis rather than a render,
 * because a render cannot tell you that a property resolved to nothing.
 */

/** `--foo-bar` as read through `var(...)`, in a class or a style value. */
const TOKEN_USE = /var\(\s*(--[A-Za-z0-9_-]+)/g;
/** `--foo-bar:` as a declaration, in any stylesheet. */
const TOKEN_DECLARATION = /(--[A-Za-z0-9_-]+)\s*:/g;

const APP_DIR = resolve(__dirname, "..");

function sourceFiles(dir: string, extensions: string[]): string[] {
  const found: string[] = [];
  for (const entry of readdirSync(dir)) {
    if (entry === "node_modules" || entry === ".next") continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      found.push(...sourceFiles(full, extensions));
    } else if (extensions.some((extension) => entry.endsWith(extension))) {
      found.push(full);
    }
  }
  return found;
}

describe("admin design token contract (ADMIN-002)", () => {
  const all = sourceFiles(APP_DIR, [".tsx", ".ts", ".css"]);
  const stylesheets = all.filter((file) => file.endsWith(".css"));
  // This file is excluded from the scan: it contains the token patterns as
  // regex literals, so scanning it finds `--color-` in the pattern itself and
  // reports the gate as the first thing it breaks. A gate that has to exclude
  // itself from its own rule is a gate that will be excluded wrongly later.
  const SELF = resolve(__dirname, "design-tokens.test.ts");
  const components = all.filter(
    (file) => !file.endsWith(".css") && file !== SELF,
  );

  const defined = new Set<string>();
  for (const file of stylesheets) {
    const text = readFileSync(file, "utf8");
    for (const match of text.matchAll(TOKEN_DECLARATION)) {
      defined.add(match[1]);
    }
  }

  const used = new Map<string, Set<string>>();
  for (const file of components) {
    const text = readFileSync(file, "utf8");
    const tokens = new Set<string>();
    for (const match of text.matchAll(TOKEN_USE)) {
      tokens.add(match[1]);
    }
    if (tokens.size > 0) used.set(relative(APP_DIR, file), tokens);
  }

  it("finds the stylesheet and the components", () => {
    // A gate that silently matches nothing is worse than no gate: it reports
    // green while checking nothing. If a rename moves these, this fails loudly
    // rather than the assertions below passing vacuously.
    expect(stylesheets.length).toBeGreaterThan(0);
    expect(components.length).toBeGreaterThan(0);
    expect(defined.size).toBeGreaterThan(0);
    expect(used.size).toBeGreaterThan(0);
  });

  it("defines every custom property the components read", () => {
    // One assertion listing every offender. "Expected --color-accent to be
    // defined" does not tell anybody which file to open, and a gate that reports
    // one file per run is a gate nobody finishes.
    const undefinedUses: string[] = [];
    for (const [file, tokens] of used) {
      for (const token of tokens) {
        if (!defined.has(token)) undefinedUses.push(`${file}: ${token}`);
      }
    }
    expect(undefinedUses.sort().join("\n")).toBe("");
  });

  /**
   * The same defect in its other form.
   *
   * Tailwind v4 generates a utility from a theme key, so `text-accent` compiles
   * to nothing when `--color-accent` is absent - and it fails just as silently as
   * a raw `var(--color-accent)`. That is not hypothetical: the guarantees page
   * used `text-accent` and `text-heading-sm`, and the theme has neither
   * `--color-accent` nor `--text-heading-sm` (it has `--text-headline-*`), so the
   * heading on the page's most consequential section rendered at the browser
   * default size.
   *
   * Checked per namespace, because the same word means different things in
   * different ones: `text-body-md` is a font size, `text-primary` is a colour,
   * and `border-outline` is a colour rather than a width. Resolving each
   * namespace against its own key set is what keeps this from reporting a
   * hundred false positives and being switched off.
   */
  it("uses no Tailwind utility whose theme key is missing", () => {
    const globalsCss = readFileSync(join(APP_DIR, "src/app/globals.css"), "utf8");
    const themeKeys = (namespace: string): Set<string> =>
      new Set(
        [...globalsCss.matchAll(new RegExp(`--${namespace}-([a-z0-9-]+)\\s*:`, "g"))]
          .map((match) => match[1]),
      );

    const colors = themeKeys("color");
    const fontSizes = themeKeys("text");
    const fonts = themeKeys("font");
    // Tailwind's own scales and side/width variants, which resolve without a
    // theme key. Listed rather than pattern-matched so that a genuinely missing
    // token is still reported - a permissive regex would silence the whole gate,
    // which is the failure mode this file exists to prevent.
    const builtIn = {
      fontSizes: new Set([
        "xs", "sm", "base", "lg", "xl", "2xl", "3xl", "4xl", "5xl", "6xl",
        "7xl", "8xl", "9xl",
      ]),
      fontWeights: new Set([
        "thin", "extralight", "light", "normal", "medium", "semibold", "bold",
        "extrabold", "black",
      ]),
      fontFamilies: new Set(["sans", "serif", "mono"]),
      // `border-b`, `border-x-2`, `rounded-t-lg` and friends: a side, a number,
      // or a named corner. Matched structurally below rather than enumerated.
      borderShape: /^(?:[trblsxy](?:-\d+)?|(?:\d+|none|collapse|separate))$/,
      // `text-center` is an alignment, not a colour or a size.
      textAlign: new Set([
        "left", "center", "right", "justify", "start", "end",
      ]),
      // CSS colour keywords Tailwind ships as utilities.
      colorKeywords: new Set([
        "transparent", "current", "inherit", "black", "white",
      ]),
    };

    const namespaces: Record<string, Set<string>> = {
      bg: new Set([...colors, ...builtIn.colorKeywords]),
      fill: new Set([...colors, ...builtIn.colorKeywords]),
      stroke: new Set([...colors, ...builtIn.colorKeywords]),
      ring: new Set([...colors, ...builtIn.colorKeywords]),
      from: colors,
      to: colors,
      via: colors,
      // A colour, a side/width/style variant, or a number - `border-outline`,
      // `border-b`, `border-collapse` and `rounded-t-lg` are all legitimate and
      // all spelled the same way.
      border: new Set([...colors, ...builtIn.colorKeywords]),
      // A colour, a font size, or a font family - all three are spelled `text-`,
      // and so is the alignment.
      text: new Set([
        ...colors,
        ...fontSizes,
        ...fonts,
        ...builtIn.fontSizes,
        ...builtIn.textAlign,
        ...builtIn.colorKeywords,
      ]),
      // A family or a weight - `font-inter` and `font-bold` are both valid.
      font: new Set([...fonts, ...builtIn.fontFamilies, ...builtIn.fontWeights]),
    };

    /** True when the value is Tailwind's own shape rather than a theme key. */
    const isStructural = (namespace: string, value: string): boolean => {
      if (value.includes("/")) return true; // `w-1/2`, `grid-cols-3/4`
      if (namespace === "border" && builtIn.borderShape.test(value)) return true;
      return false;
    };

    // Every component file, not only the ones that read a custom property. The
    // first version of this check iterated the `used` map, which by
    // construction contains only files with a `var(--...)` in them - so it
    // skipped the guarantees page, which is exactly where the reported
    // `text-accent` defect lived. A gate that only inspects part of its input
    // is worse than no gate, because it reports green.
    const undefinedUses: string[] = [];
    for (const file of components) {
      const text = readFileSync(file, "utf8");
      const name = relative(APP_DIR, file);
      for (const match of text.matchAll(/(?:^|[\s"'`])([a-z]+)-([a-z0-9-]+)/g)) {
        const [, namespace, value] = match;
        const known = namespaces[namespace];
        if (!known) continue;
        if (!/^[a-z]/.test(value)) continue;
        if (isStructural(namespace, value)) continue;
        if (!known.has(value)) {
          undefinedUses.push(`${name}: ${namespace}-${value}`);
        }
      }
    }
    expect([...new Set(undefinedUses)].sort().join("\n")).toBe("");
  });

  it("defines the semantic aliases rather than a second palette", () => {
    // The nine aliases exist so pages written against `var(--color-...)` have
    // something to resolve to. Each must point at a token from the base palette,
    // or the stylesheet grows a second source of truth and the two drift - which
    // is how `--color-accent` became undefined in the first place.
    const globalsCss = readFileSync(join(APP_DIR, "src/app/globals.css"), "utf8");
    const basePalette = new Set(
      [...globalsCss.matchAll(/^\s*(--color-[a-z-]+):/gm)].map((m) => m[1]),
    );
    const aliases = [
      "--color-surface-primary",
      "--color-surface-secondary",
      "--color-border-default",
      "--color-border-strong",
      "--color-text-secondary",
      "--color-danger",
      "--color-danger-soft",
      "--color-warning",
    ];
    for (const alias of aliases) {
      const declaration = new RegExp(
        `${alias}:\\s*var\\(\\s*(--[a-z-]+)`,
        "i",
      ).exec(globalsCss);
      expect(declaration, `${alias} is not defined as an alias`).not.toBeNull();
      expect(
        basePalette.has(declaration![1]),
        `${alias} aliases ${declaration![1]}, which is not in the base palette`,
      ).toBe(true);
    }
  });

  it("keeps the tertiary text step above the WCAG AA threshold", () => {
    // The one alias that is a literal rather than a pointer. `#6B7684` on the
    // card surface is 4.6:1; the outline token it replaced measured 4.3:1, below
    // the 4.5:1 AA threshold for body-sized text. Asserted so a "harmless"
    // palette tweak cannot quietly reintroduce the failure.
    const globalsCss = readFileSync(join(APP_DIR, "src/app/globals.css"), "utf8");
    const muted = /--color-text-muted:\s*(#[0-9a-f]{6})/i.exec(globalsCss);
    expect(muted, "--color-text-muted is not a literal").not.toBeNull();

    const luminance = (hex: string): number => {
      const channels = [1, 3, 5].map((offset) => {
        const value = parseInt(hex.slice(offset, offset + 2), 16) / 255;
        return value <= 0.03928
          ? value / 12.92
          : ((value + 0.055) / 1.055) ** 2.4;
      });
      return (
        0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
      );
    };
    const card = "#ffffff";
    const lighter = Math.max(luminance(muted![1]), luminance(card));
    const darker = Math.min(luminance(muted![1]), luminance(card));
    const ratio = (lighter + 0.05) / (darker + 0.05);
    expect(ratio).toBeGreaterThanOrEqual(4.5);
  });

  it("has a boundary for every page-level failure (ADMIN-001)", () => {
    // Four files at the app root cover all seventeen routes. Without them a
    // failed Server Action renders the framework's default screen, which tells an
    // operator nothing and offers no retry.
    for (const boundary of [
      "loading.tsx",
      "error.tsx",
      "not-found.tsx",
      "global-error.tsx",
    ]) {
      expect(
        () => readFileSync(join(APP_DIR, "src/app", boundary), "utf8"),
        `src/app/${boundary} is missing`,
      ).not.toThrow();
    }
  });

  it("the error boundary never renders a raw message in production", () => {
    // `error.message` in development is a stack trace's first line; in
    // production it can carry a query or an internal identifier. The boundary
    // must therefore gate on the environment rather than rendering it always.
    const source = readFileSync(join(APP_DIR, "src/app/error.tsx"), "utf8");
    expect(source).toMatch(/NODE_ENV\s*!==\s*["']production["']/);
  });
});
