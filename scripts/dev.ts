import { spawn, spawnSync, type Subprocess } from "bun";

const args = process.argv.slice(2);
const isBackendOnly = args.includes("--backend-only") || args.includes("--no-flutter");
const isProxyOnly = args.includes("--proxy-only");
const flutterWebPort = process.env.FLUTTER_WEB_PORT || "51354";

console.log(`\x1b[36m
  ╔══════════════════════════════════════════════════════════════════╗
  ║                 FixNow Local Dev Orchestrator                    ║
  ║                   Powered by Bun & Zero-Docker                   ║
  ╚══════════════════════════════════════════════════════════════════╝
\x1b[0m`);

const childProcesses: Subprocess[] = [];

import net from "node:net";

/**
 * Polls until `port` accepts a TCP connection, or the timeout elapses.
 * The orchestrator must never announce a URL before the app behind it is
 * actually reachable — announcing early masks a failed launch as success.
 */
function waitForPort(port: number, timeoutMs: number): Promise<boolean> {
  const deadline = Date.now() + timeoutMs;
  return new Promise((resolve) => {
    function tryConnect() {
      if (Date.now() >= deadline) {
        return resolve(false);
      }
      const socket = new net.Socket();
      socket.setTimeout(800);
      socket.once("connect", () => {
        socket.destroy();
        resolve(true);
      });
      socket.once("error", () => {
        socket.destroy();
        const socket6 = new net.Socket();
        socket6.setTimeout(800);
        socket6.once("connect", () => {
          socket6.destroy();
          resolve(true);
        });
        socket6.once("error", () => {
          socket6.destroy();
          setTimeout(tryConnect, 500);
        });
        socket6.once("timeout", () => {
          socket6.destroy();
          setTimeout(tryConnect, 500);
        });
        socket6.connect(port, "::1");
      });
      socket.once("timeout", () => {
        socket.destroy();
        setTimeout(tryConnect, 500);
      });
      socket.connect(port, "127.0.0.1");
    }
    tryConnect();
  });
}

/**
 * Tracks a child so an unexpected exit is reported and shuts the stack down
 * instead of leaving the orchestrator running against a dead service.
 */
function trackChild(proc: Subprocess, label: string) {
  childProcesses.push(proc);
  proc.exited.then((code, signal, error) => {
    if (code === 0 || code === null) return;
    console.error(
      `\x1b[31m✖ ${label} exited unexpectedly (code ${code ?? "null"}${
        signal ? `, signal ${signal}` : ""
      }${error ? `: ${error.message}` : ""}).\x1b[0m`,
    );
    cleanup();
  });
}

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

// Redis is disposable local infrastructure.  When Docker Desktop is already
// running, Compose can start the existing Redis-only service idempotently.
// Do not try to launch Docker Desktop itself: it is a user-managed GUI service
// and may be unavailable on a developer's machine.
function checkRedis() {
  console.log("🧠 \x1b[1mChecking local Redis...\x1b[0m");
  try {
    const dockerCheck = spawnSync({
      cmd: ["docker", "version", "--format", "{{.Server.Version}}"],
      stdout: "pipe",
      stderr: "pipe",
    });

    if (dockerCheck.exitCode !== 0 || !dockerCheck.stdout.toString().trim()) {
      console.log("   \x1b[33mℹ Docker Desktop is not running; backend will use its local cache fallback.\x1b[0m");
      return;
    }

    const redisStart = spawnSync({
      cmd: [
        "docker",
        "compose",
        "-f",
        "infrastructure/local/docker-compose.yml",
        "up",
        "-d",
        "redis",
      ],
      stdout: "pipe",
      stderr: "pipe",
    });

    if (redisStart.exitCode === 0) {
      console.log("   \x1b[32m✔ Redis is ready on localhost:6379.\x1b[0m");
    } else {
      console.log("   \x1b[33mℹ Redis could not be started; backend will use its local cache fallback.\x1b[0m");
    }
  } catch {
    console.log("   \x1b[33mℹ Docker is unavailable; backend will use its local cache fallback.\x1b[0m");
  }
}

// 2. Setup ADB Port Forwarding for Connected Devices
function setupAdb(): boolean {
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
      return true;
    }
  } catch {
    // adb not installed or not in PATH, skip silently
  }
  return false;
}

async function start() {
  checkPostgres();
  checkRedis();
  const hasDevice = setupAdb();

  // 3. Start Bun Reverse Proxy
  console.log("\n⚡ \x1b[1mStarting Bun Reverse Proxy (Port 8080 -> 3300)...\x1b[0m");
  const proxyProc = spawn({
    cmd: ["bun", "run", "scripts/proxy.ts"],
    stdout: "inherit",
    stderr: "inherit",
  });
  trackChild(proxyProc, "Reverse proxy");

  if (isProxyOnly) {
    console.log("\n\x1b[32m✔ Running proxy only.\x1b[0m");
    return;
  }

  // Helper for cross-platform command execution
  const npmCmd = process.platform === "win32" ? "npm.cmd" : "npm";
  // `flutter` is a .bat on Windows, which Bun.spawn cannot execute directly —
  // route it through cmd.exe so the batch file is actually invoked. This is the
  // same requirement documented in mobile/tool/bisect_font_bump.dart.
  const flutterCmd =
    process.platform === "win32"
      ? ["cmd.exe", "/d", "/s", "/c", "flutter.bat"]
      : ["flutter"];

  // 4. Run database migrations
  console.log("📦 \x1b[1mChecking & running database migrations...\x1b[0m");
  try {
    const npxCmd = process.platform === "win32" ? "npx.cmd" : "npx";
    const migrationResult = spawnSync({
      cmd: [
        npxCmd,
        "ts-node",
        "-r",
        "tsconfig-paths/register",
        "./node_modules/typeorm/cli.js",
        "migration:run",
        "-d",
        "typeorm.config.ts",
      ],
      cwd: "backend",
      stdout: "pipe",
      stderr: "pipe",
    });
    if (migrationResult.exitCode === 0) {
      console.log("   \x1b[32m✔ Database migrations are up to date.\x1b[0m");
    } else {
      console.log("   \x1b[33mℹ Database migrations check output:\x1b[0m\n", migrationResult.stderr.toString() || migrationResult.stdout.toString());
    }
  } catch (err: any) {
    console.log("   \x1b[33mℹ Skipped database migrations run:\x1b[0m", err?.message);
  }

  // 5. Start NestJS Backend
  console.log("⚡ \x1b[1mStarting NestJS Backend API (Port 3300)...\x1b[0m");
  const backendProc = spawn({
    cmd: [npmCmd, "run", "start:dev"],
    cwd: "backend",
    stdout: "inherit",
    stderr: "inherit",
    env: { ...process.env, PORT: "3300" },
  });
  trackChild(backendProc, "Backend API");

  // 6. Start Flutter Mobile (if not --backend-only)
  if (!isBackendOnly) {
    const flutterArgs = ["run"];
    if (hasDevice) {
      console.log("📱 \x1b[1mLaunching Flutter Mobile App on attached device...\x1b[0m");
      // Explicit even though push now defaults on: it keeps the flag visible
      // and discoverable, and documents how to turn push off.
      flutterArgs.push(
        "--dart-define=PUSH_NOTIFICATIONS_ENABLED=true",
        "--dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1/"
      );
    } else {
      console.log("🌐 \x1b[1mLaunching Flutter Web App...\x1b[0m");
      flutterArgs.push(
        "-d", "chrome",
        "--web-hostname", "127.0.0.1",
        "--web-port", flutterWebPort,
        "--dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1/"
      );
    }
    console.log("   \x1b[90mTip: Run with 'bun dev --backend-only' to only run backend + proxy.\x1b[0m\n");

    const flutterProc = spawn({
      cmd: [...flutterCmd, ...flutterArgs],
      cwd: "mobile",
      stdin: "inherit",
      stdout: "inherit",
      stderr: "inherit",
    });
    trackChild(flutterProc, "Flutter app");

    // Announce the URL only once the web server actually answers, so a failed
    // launch is never reported as a ready application. A device build has no
    // local port to probe, so there is nothing to wait for.
    if (!hasDevice) {
      const port = Number(flutterWebPort);
      if (await waitForPort(port, 120_000)) {
        console.log(
          `   \x1b[32m✔ Flutter is serving — open http://localhost:${port}\x1b[0m\n`,
        );
      } else {
        console.error(
          `\x1b[31m✖ Flutter did not start listening on port ${port}.\x1b[0m`,
        );
        cleanup();
        return;
      }
    }
  } else {
    console.log("\n\x1b[32m✔ FixNow Backend & Proxy running in watch mode. Press Ctrl+C to stop.\x1b[0m\n");
  }
}

start().catch((err) => {
  console.error("Fatal startup error:", err);
  cleanup();
});
