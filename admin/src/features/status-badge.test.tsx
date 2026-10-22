import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { StatusBadge } from "./status-badge";

describe("StatusBadge", () => {
  it("uses identical status semantics for backend uppercase and lowercase statuses", () => {
    for (const status of ["approved", "rejected", "active", "suspended"]) {
      expect(renderToStaticMarkup(<StatusBadge status={status.toUpperCase()} />))
        .toBe(renderToStaticMarkup(<StatusBadge status={status} />));
    }
  });
  it("shows a readable label for an unfamiliar status", () => {
    expect(renderToStaticMarkup(<StatusBadge status="AWAITING_REVIEW" />)).toContain("AWAITING REVIEW");
  });
});
