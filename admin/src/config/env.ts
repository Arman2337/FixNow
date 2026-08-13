export type AppEnvironment = "development" | "test" | "production";
export type AdminEnvironment = Readonly<{ appEnvironment: AppEnvironment; apiBaseUrl: string }>;

const environments = new Set<AppEnvironment>(["development", "test", "production"]);

export function parseEnvironment(source: Readonly<Record<string, string | undefined>>): AdminEnvironment {
  const appEnvironment = source.NEXT_PUBLIC_APP_ENV?.trim() || "development";
  if (!environments.has(appEnvironment as AppEnvironment)) {
    throw new Error("NEXT_PUBLIC_APP_ENV must be development, test, or production.");
  }

  const apiBaseUrl = source.NEXT_PUBLIC_API_BASE_URL?.trim() || "http://localhost:3000/api/v1";
  let parsedUrl: URL;
  try {
    parsedUrl = new URL(apiBaseUrl);
  } catch {
    throw new Error("NEXT_PUBLIC_API_BASE_URL must be an absolute URL.");
  }
  if (parsedUrl.protocol !== "http:" && parsedUrl.protocol !== "https:") {
    throw new Error("NEXT_PUBLIC_API_BASE_URL must use HTTP or HTTPS.");
  }
  if (appEnvironment === "production" && parsedUrl.protocol !== "https:") {
    throw new Error("NEXT_PUBLIC_API_BASE_URL must use HTTPS in production.");
  }

  return Object.freeze({
    appEnvironment: appEnvironment as AppEnvironment,
    apiBaseUrl: parsedUrl.toString().replace(/\/$/, ""),
  });
}

export const env = parseEnvironment(process.env);
