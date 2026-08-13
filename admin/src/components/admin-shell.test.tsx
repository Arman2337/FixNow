import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AdminShell } from "./admin-shell";

describe("AdminShell", () => {
  it("renders an accessible, honest foundation state", () => {
    const markup = renderToStaticMarkup(<AdminShell environment="test" roles={["provider_reviewer"]} />);
    expect(markup).toContain("<main");
    expect(markup).toContain('aria-label="Admin navigation"');
    expect(markup).toContain('aria-current="page"');
    expect(markup).toContain('href="/providers"');
    expect(markup).toContain("Authentication and administrative workflows are not enabled yet.");
    expect(markup).toContain("Sign out");
    expect(markup).toContain("Providers");
    expect(markup).not.toContain("Access</a>");
  });
});
