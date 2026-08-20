# Bun-Powered Local Development Workflow

FixNow supports a fast, zero-Docker, single-command development workflow using **Bun**.

## Prerequisites

1. **Bun**: v1.1+ installed (`bun --version`).
2. **PostgreSQL**: Local PostgreSQL running on Windows (either as a service or custom instance).
3. **Flutter**: For mobile development (`flutter --version`).
4. **Docker Desktop (optional)**: Needed only when you want the local Redis container. `bun dev` starts that container automatically when Docker Desktop is already running.

---

## Available Commands

From the workspace root directory:

### 1. Start Full Stack (DB Check + Proxy + Backend + Flutter)
```bash
bun dev
```
- Verifies local PostgreSQL service is running.
- Checks for attached physical Android devices and configures `adb reverse`.
- Starts Bun reverse proxy on port `8080`.
- Starts NestJS backend on port `3300` in hot-reload watch mode.
- Starts local Redis from `infrastructure/local/docker-compose.yml` when Docker Desktop is running; otherwise the backend uses its memory-cache fallback.
- Launches Flutter Web at `http://localhost:51354` with full terminal interactivity (`r` hot reload, `R` hot restart). Set `FLUTTER_WEB_PORT` to use another fixed port.

### 2. Start Backend & Proxy Only (No Flutter)
```bash
bun run dev:backend
# or
bun dev --backend-only
```
- Starts PostgreSQL check + Bun Proxy (`:8080`) + NestJS Backend (`:3300`).

### 3. Start Proxy Only
```bash
bun run dev:proxy
```
- Starts the Bun reverse proxy listening on `0.0.0.0:8080` forwarding to `127.0.0.1:3300`.

---

## Port Mappings & Architecture

| Component | Port | Description |
| :--- | :--- | :--- |
| **NestJS Backend** | `3300` | REST API (`/api/v1`) and WebSockets (`/api/v1/*`) |
| **Bun Reverse Proxy** | `8080` | High-speed proxy with live request logging and CORS |
| **Flutter Web** | `51354` | Stable browser development URL (override with `FLUTTER_WEB_PORT`) |
| **PostgreSQL** | `55432` / `5432` | Local database instance |
| **Redis** | `6379` | Optional local cache container, started by `bun dev` when Docker Desktop is running |

The browser app, proxy, and backend intentionally use separate ports during development. Only the browser address needs to be opened manually; Flutter Web remains fixed at `http://localhost:51354`.

### Connecting Devices to the Backend

- **Windows Desktop / Web**: Connect to `http://127.0.0.1:8080/api/v1` or `http://127.0.0.1:3300/api/v1`
- **Android Emulator**: Connect to `http://10.0.2.2:8080/api/v1`
- **Physical Phone (USB)**: Automatically forwarded via `adb reverse` to `http://127.0.0.1:8080/api/v1`
- **Physical Phone (Wi-Fi)**: Connect directly to `http://<YOUR_PC_LOCAL_IP>:8080/api/v1`
