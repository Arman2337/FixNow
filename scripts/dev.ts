import { spawn, spawnSync, type Subprocess } from "bun";

const args = process.argv.slice(2);
const isBackendOnly = args.includes("--backend-only") || args.includes("--no-flutter");
const isProxyOnly = args.includes("--proxy-only");

console.log(`\x1b[36m
  ╔══════════════════════════════════════════════════════════════════╗
  ║                 FixNow Local Dev Orchestrator                    ║
  ║                   Powered by Bun & Zero-Docker                   ║
  ╚══════════════════════════════════════════════════════════════════╝
\x1b[0m`);

const childProcesses: Subprocess[] = [];

function cleanup() {
  console.log("\n\x1b[33m🛑 Shutting down all FixNow services...\x1b[0m");
  for (const proc of childProcesses) {
    try {
      proc.kill();
    } catch {}
  }
  process.exit(0);
}

process.on("SIGINT", cleanup);
process.on("SIGTERM", cleanup);

// 1. Verify/Start Native PostgreSQL Service (Windows)
function checkPostgres() {
  console.log("📦 \x1b[1mChecking Local PostgreSQL Service...\x1b[0m");
  try {
    const checkResult = spawnSync({
      cmd: [
        "powershell",
        "-NoProfile",
        "-Command",
        "$svc = Get-Service postgresql* -ErrorAction SilentlyContinue; if ($svc) { if ($svc.Status -ne 'Running') { Start-Service $svc.Name; Write-Output 'STARTED' } else { Write-Output 'RUNNING' } } else { Write-Output 'NOT_FOUND' }"
      ],
      stdout: "pipe",
    });

    const output = checkResult.stdout.toString().trim();
    if (output.includes("RUNNING")) {
      console.log("   \x1b[32m✔ PostgreSQL Windows service is running.\x1b[0m");
    } else if (output.includes("STARTED")) {
      console.log("   \x1b[32m✔ PostgreSQL Windows service was started successfully.\x1b[0m");
    } else {
      console.log("   \x1b[33mℹ PostgreSQL service not registered as a standard Windows service.\x1b[0m");
      console.log("   \x1b[90m(If running via custom pg_ctl or port 55432, ensure it is active)\x1b[0m");
    }
  } catch (err: any) {
    console.log("   \x1b[33mℹ Skipped Windows service check.\x1b[0m");
  }
}

// 2. Setup ADB Port Forwarding for Connected Devices
function setupAdb() {
  try {
    const adbCheck = spawnSync({
      cmd: ["adb", "devices"],
      stdout: "pipe",
      stderr: "pipe",
    });

    const output = adbCheck.stdout.toString();
    const hasDevices = output.split("\n").some((line) => line.includes("\tdevice"));

    if (hasDevices) {
      console.log("📱 \x1b[1mConnected Android Device detected via ADB. Setting up port forwarding...\x1b[0m");
      spawnSync({ cmd: ["adb", "reverse", "tcp:3300", "tcp:3300"] });
      spawnSync({ cmd: ["adb", "reverse", "tcp:8080", "tcp:8080"] });
      console.log("   \x1b[32m✔ Forwarded tcp:3300 and tcp:8080 to connected Android device.\x1b[0m");
    }
  } catch {
    // adb not installed or not in PATH, skip silently
  }
}

async function start() {
  checkPostgres();
  setupAdb();

  // 3. Start Bun Reverse Proxy
  console.log("\n⚡ \x1b[1mStarting Bun Reverse Proxy (Port 8080 -> 3300)...\x1b[0m");
  const proxyProc = spawn({
    cmd: ["bun", "run", "scripts/proxy.ts"],
    stdout: "inherit",
    stderr: "inherit",
  });
  childProcesses.push(proxyProc);

  if (isProxyOnly) {
    console.log("\n\x1b[32m✔ Running proxy only.\x1b[0m");
    return;
  }

  // Helper for cross-platform command execution
  const npmCmd = process.platform === "win32" ? "npm.cmd" : "npm";
  const flutterCmd = process.platform === "win32" ? "flutter.bat" : "flutter";

  // 4. Start NestJS Backend
  console.log("⚡ \x1b[1mStarting NestJS Backend API (Port 3300)...\x1b[0m");
  const backendProc = spawn({
    cmd: [npmCmd, "run", "start:dev"],
    cwd: "backend",
    stdout: "inherit",
    stderr: "inherit",
    env: { ...process.env, PORT: "3300" },
  });
  childProcesses.push(backendProc);

  // 5. Start Flutter Mobile (if not --backend-only)
  if (!isBackendOnly) {
    console.log("📱 \x1b[1mLaunching Flutter Mobile App...\x1b[0m");
    console.log("   \x1b[90mTip: Run with 'bun dev --backend-only' to only run backend + proxy.\x1b[0m\n");
    const flutterProc = spawn({
      cmd: [flutterCmd, "run"],
      cwd: "mobile",
      stdin: "inherit",
      stdout: "inherit",
      stderr: "inherit",
    });
    childProcesses.push(flutterProc);
  } else {
    console.log("\n\x1b[32m✔ FixNow Backend & Proxy running in watch mode. Press Ctrl+C to stop.\x1b[0m\n");
  }
}

start().catch((err) => {
  console.error("Fatal startup error:", err);
  cleanup();
});
