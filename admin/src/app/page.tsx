import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { getSession } from "@/auth/session";
import { redirect } from "next/navigation";

export default async function Home() {
  const result = await getSession();
  if (result.state !== "authenticated") {
    if (result.state === "anonymous") redirect("/login");
    if (result.state === "expired") redirect("/login?reason=expired");
    redirect("/unauthorized");
  }
  return <AdminShell environment={env.appEnvironment} roles={result.session.roles} />;
}
