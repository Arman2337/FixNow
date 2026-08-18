/**
 * FixNow Lightweight Development Reverse Proxy (Powered by Bun)
 *
 * Forwards incoming HTTP and WebSocket traffic to the NestJS backend
 * and provides formatted request logging, CORS, and multi-device support.
 */

const BACKEND_HOST = process.env.BACKEND_HOST || "127.0.0.1";
const BACKEND_PORT = parseInt(process.env.BACKEND_PORT || "3300", 10);
const PROXY_PORT = parseInt(process.env.PROXY_PORT || "8080", 10);
const PROXY_HOST = process.env.PROXY_HOST || "0.0.0.0";

const targetBase = `http://${BACKEND_HOST}:${BACKEND_PORT}`;

console.log(`\x1b[36m┌────────────────────────────────────────────────────────────┐\x1b[0m`);
console.log(`\x1b[36m│\x1b[0m  🚀 \x1b[1mFixNow Bun Reverse Proxy\x1b[0m                                \x1b[36m│\x1b[0m`);
console.log(`\x1b[36m│\x1b[0m  Proxy:   \x1b[32mhttp://${PROXY_HOST}:${PROXY_PORT}\x1b[0m                               \x1b[36m│\x1b[0m`);
console.log(`\x1b[36m│\x1b[0m  Target:  \x1b[33m${targetBase}\x1b[0m                              \x1b[36m│\x1b[0m`);
console.log(`\x1b[36m└────────────────────────────────────────────────────────────┘\x1b[0m\n`);

function colorStatus(status: number): string {
  if (status >= 500) return `\x1b[31m${status}\x1b[0m`;
  if (status >= 400) return `\x1b[33m${status}\x1b[0m`;
  if (status >= 300) return `\x1b[36m${status}\x1b[0m`;
  if (status >= 200) return `\x1b[32m${status}\x1b[0m`;
  return `${status}`;
}

const server = Bun.serve({
  port: PROXY_PORT,
  hostname: PROXY_HOST,

  async fetch(req, server) {
    const url = new URL(req.url);
    const start = performance.now();

    // Check for WebSocket upgrade
    const isWebSocket = req.headers.get("upgrade")?.toLowerCase() === "websocket";
    if (isWebSocket) {
      const targetWsUrl = `ws://${BACKEND_HOST}:${BACKEND_PORT}${url.pathname}${url.search}`;
      console.log(`\x1b[35m[WS UPGRADE]\x1b[0m ${url.pathname}${url.search} -> ${targetWsUrl}`);

      const success = server.upgrade(req, {
        data: { targetWsUrl },
      });
      if (success) return undefined;
    }

    // Health check endpoint for proxy
    if (url.pathname === "/_proxy/health") {
      return new Response(JSON.stringify({ status: "ok", proxy: true, target: targetBase }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Intercept CORS Preflight requests (OPTIONS)
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, PATCH, OPTIONS",
          "Access-Control-Allow-Headers": req.headers.get("Access-Control-Request-Headers") || "*",
          "Access-Control-Max-Age": "86400",
        },
      });
    }

    // Forward HTTP request to backend
    const targetUrl = `${targetBase}${url.pathname}${url.search}`;

    try {
      const headers = new Headers(req.headers);
      headers.set("x-forwarded-host", req.headers.get("host") || `localhost:${PROXY_PORT}`);
      headers.set("x-forwarded-proto", url.protocol.replace(":", ""));
      headers.set("x-forwarded-for", server.requestIP(req)?.address || "127.0.0.1");

      const response = await fetch(targetUrl, {
        method: req.method,
        headers,
        body: ["GET", "HEAD"].includes(req.method) ? undefined : await req.arrayBuffer(),
        redirect: "manual",
      });

      const duration = (performance.now() - start).toFixed(1);
      console.log(
        `\x1b[90m${new Date().toLocaleTimeString()}\x1b[0m [${req.method}] ${url.pathname}${url.search} -> ${colorStatus(response.status)} \x1b[90m(${duration}ms)\x1b[0m`
      );

      // Clone response headers and pass through
      const respHeaders = new Headers(response.headers);
      // Ensure CORS for easy web dev
      if (!respHeaders.has("access-control-allow-origin")) {
        respHeaders.set("access-control-allow-origin", "*");
      }

      // Log error responses in the proxy (excluding 304 Not Modified)
      if (!response.ok && response.status !== 304 && req.method !== "OPTIONS") {
        const clonedRes = response.clone();
        const text = await clonedRes.text().catch(() => "could not read body");
        console.error(`\x1b[31m[PROXY ERROR]\x1b[0m ${req.method} ${url.pathname} -> ${response.status} ${text.substring(0, 100)}`);
      }

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: respHeaders,
      });
    } catch (err: any) {
      const duration = (performance.now() - start).toFixed(1);
      console.error(
        `\x1b[90m${new Date().toLocaleTimeString()}\x1b[0m [${req.method}] ${url.pathname} -> \x1b[31mFAIL\x1b[0m \x1b[90m(${duration}ms)\x1b[0m: ${err.message}`
      );

      return new Response(
        JSON.stringify({
          statusCode: 502,
          message: `Proxy Error: Unable to reach backend at ${targetBase}. Is the NestJS backend running?`,
          error: "Bad Gateway",
        }),
        {
          status: 502,
          headers: { "Content-Type": "application/json", "access-control-allow-origin": "*" },
        }
      );
    }
  },

  websocket: {
    open(ws) {
      const { targetWsUrl } = ws.data as { targetWsUrl: string };
      const backendWs = new WebSocket(targetWsUrl);
      (ws as any).backendWs = backendWs;

      backendWs.onopen = () => {
        console.log(`\x1b[32m[WS CONNECTED]\x1b[0m Connected to backend WS`);
      };

      backendWs.onmessage = (event) => {
        ws.send(event.data);
      };

      backendWs.onclose = () => {
        ws.close();
      };

      backendWs.onerror = (err) => {
        console.error(`\x1b[31m[WS ERROR]\x1b[0m Backend WS error:`, err);
        ws.close();
      };
    },
    message(ws, message) {
      const backendWs = (ws as any).backendWs as WebSocket | undefined;
      if (backendWs && backendWs.readyState === WebSocket.OPEN) {
        backendWs.send(message);
      }
    },
    close(ws) {
      const backendWs = (ws as any).backendWs as WebSocket | undefined;
      if (backendWs && backendWs.readyState === WebSocket.OPEN) {
        backendWs.close();
      }
    },
  },
});
