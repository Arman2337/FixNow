import { describe, expect, it } from "vitest";
import { validateLoginInput } from "./validation";

describe("admin login validation", () => {
  it("rejects invalid credentials without sending them", () => {
    expect(validateLoginInput("not-an-email", "short")).toEqual({ errors: {
      email: "Enter a valid work email.",
      password: "Password must be 12 to 128 characters.",
    } });
  });

  it("accepts a valid work credential shape", () => {
    expect(validateLoginInput("admin@example.com", "correct horse battery")).toEqual({});
  });
});
