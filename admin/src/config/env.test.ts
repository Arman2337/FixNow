import { describe, expect, it } from "vitest";
import { parseEnvironment } from "./env";

describe("parseEnvironment", () => {
  it("uses safe local development defaults", () => {
    expect(parseEnvironment({})).toEqual({
      appEnvironment: "development",
      apiBaseUrl: "http://localhost:3000/api/v1",
    });
  });

  it("rejects unknown environments and non-HTTP API URLs", () => {
    expect(() => parseEnvironment({ NEXT_PUBLIC_APP_ENV: "staging" })).toThrow("NEXT_PUBLIC_APP_ENV");
    expect(() => parseEnvironment({ NEXT_PUBLIC_API_BASE_URL: "file:///tmp/api" })).toThrow("HTTP or HTTPS");
  });

  it("requires HTTPS for production", () => {
    expect(() => parseEnvironment({
      NEXT_PUBLIC_APP_ENV: "production",
      NEXT_PUBLIC_API_BASE_URL: "http://api.example.test",
    })).toThrow("HTTPS in production");
  });
});
