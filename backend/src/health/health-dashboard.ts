import type { HealthFact, SystemHealthReport } from './system-health.service';

/**
 * Escapes text for interpolation into HTML.
 *
 * Every value on this page is interpolated as text, never as markup. Most of
 * them are process numbers and enum-ish strings, but the dependency `detail`
 * carries an error name and `reason` carries operator-supplied configuration —
 * and an escaping function that is correct only for the values that happen to
 * arrive today is how a reflected XSS gets introduced later by an innocent
 * change to what is displayed.
 */
function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Renders the dashboard.
 *
 * Styles and script are inlined rather than served from a static asset
 * directory because this is one self-contained page with no build step, and a
 * second origin or a separate asset pipeline would be a dependency for a
 * diagnostic screen. The script only re-fetches this same URL and swaps the
 * body, so it needs no external anything.
 */
function factRows(facts: readonly HealthFact[]): string {
  return facts
    .map(
      (fact) => `
            <tr class="${fact.ok ? 'ok' : 'bad'}">
              <th scope="row">${escapeHtml(fact.label)}</th>
              <td>${escapeHtml(fact.value)}</td>
            </tr>`,
    )
    .join('');
}

export function renderHealthDashboard(report: SystemHealthReport): string {
  const healthy = report.status === 'healthy';
  const databaseRow: HealthFact = {
    label: 'Database',
    value: report.database.ok
      ? `connected · ${report.database.latencyMs ?? 0} ms`
      : report.database.detail,
    ok: report.database.ok,
  };
  const cacheRow: HealthFact = {
    label: 'Redis / cache',
    value: report.cache.detail,
    ok: report.cache.ok,
  };
  const memoryRow: HealthFact = {
    label: 'Heap used / total',
    value: `${report.memory.heapUsedMb} MB / ${report.memory.heapTotalMb} MB`,
    ok: true,
  };
  const rssRow: HealthFact = {
    label: 'RSS',
    value: `${report.memory.rssMb} MB`,
    ok: true,
  };
  const heapLimitRow: HealthFact = {
    label: 'V8 heap limit',
    value: `${report.memory.heapLimitMb} MB`,
    ok: true,
  };

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>FixNow health dashboard</title>
<style>
  :root {
    color-scheme: light dark;
    --bg: #0f1115;
    --card: #171a21;
    --border: #262b36;
    --text: #e6e8ee;
    --muted: #9aa3b2;
    --ok: #3fb950;
    --bad: #f85149;
    --accent: #58a6ff;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 2rem 1rem;
    background: var(--bg);
    color: var(--text);
    font: 15px/1.5 ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
  }
  .wrap { max-width: 62rem; margin: 0 auto; }
  header {
    display: flex;
    flex-wrap: wrap;
    gap: 1rem;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 1.5rem;
  }
  h1 { font-size: 1.4rem; margin: 0; letter-spacing: -0.01em; }
  .sub { color: var(--muted); font-size: 0.85rem; margin-top: 0.2rem; }
  .badge {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.45rem 0.9rem;
    border-radius: 999px;
    font-weight: 600;
    font-size: 0.9rem;
    border: 1px solid;
  }
  .badge.healthy { color: var(--ok); border-color: var(--ok); }
  .badge.degraded { color: var(--bad); border-color: var(--bad); }
  .dot { width: 0.6rem; height: 0.6rem; border-radius: 50%; background: currentColor; }
  .badge.degraded .dot { animation: pulse 1.1s ease-in-out infinite; }
  @keyframes pulse { 50% { opacity: 0.25; } }
  @media (prefers-reduced-motion: reduce) { .badge.degraded .dot { animation: none; } }
  .grid {
    display: grid;
    gap: 1rem;
    grid-template-columns: repeat(auto-fit, minmax(17rem, 1fr));
  }
  section {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 0.6rem;
    padding: 1rem 1.1rem 0.6rem;
  }
  h2 {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--muted);
    margin: 0 0 0.75rem;
    font-weight: 600;
  }
  table { width: 100%; border-collapse: collapse; }
  th, td { text-align: left; padding: 0.4rem 0; vertical-align: top; }
  th { font-weight: 400; color: var(--muted); }
  td {
    text-align: right;
    font-variant-numeric: tabular-nums;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 0.88rem;
    word-break: break-word;
  }
  tr.bad td { color: var(--bad); font-weight: 600; }
  footer {
    margin-top: 1.5rem;
    display: flex;
    flex-wrap: wrap;
    gap: 1rem;
    align-items: center;
    justify-content: space-between;
    color: var(--muted);
    font-size: 0.85rem;
  }
  label { display: inline-flex; gap: 0.45rem; align-items: center; cursor: pointer; }
  button {
    font: inherit;
    color: var(--accent);
    background: none;
    border: 1px solid var(--border);
    border-radius: 0.4rem;
    padding: 0.35rem 0.7rem;
    cursor: pointer;
  }
  button:hover { border-color: var(--accent); }
  code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
</style>
</head>
<body>
<div class="wrap" id="root">
  <header>
    <div>
      <h1>FixNow health dashboard</h1>
      <div class="sub">Checked ${escapeHtml(report.checkedAt)} · up ${escapeHtml(report.uptimeHuman)}</div>
    </div>
    <span class="badge ${healthy ? 'healthy' : 'degraded'}">
      <span class="dot"></span>${healthy ? 'Healthy' : 'Degraded'}
    </span>
  </header>

  <div class="grid">
    <section>
      <h2>Uptime</h2>
      <table><tbody>
        <tr class="ok"><th scope="row">Uptime</th><td>${escapeHtml(report.uptimeHuman)}</td></tr>
        <tr class="ok"><th scope="row">Seconds</th><td>${report.uptimeSeconds}</td></tr>
      </tbody></table>
    </section>

    <section>
      <h2>Memory</h2>
      <table><tbody>
        ${factRows([memoryRow, rssRow, heapLimitRow])}
      </tbody></table>
    </section>

    <section>
      <h2>Dependencies</h2>
      <table><tbody>
        ${factRows([databaseRow, cacheRow])}
      </tbody></table>
    </section>

    <section>
      <h2>Environment</h2>
      <table><tbody>
        ${factRows(report.environment)}
      </tbody></table>
    </section>

    <section>
      <h2>Recent metrics</h2>
      <table><tbody>
        ${factRows(report.metrics)}
      </tbody></table>
    </section>
  </div>

  <footer>
    <label>
      <input type="checkbox" id="auto" checked>
      Auto-refresh
    </label>
    <select id="interval" style="font:inherit;color:var(--muted);background:none;border:1px solid var(--border);border-radius:0.4rem;padding:0.35rem">
      <option value="10000">every 10s</option>
      <option value="30000">every 30s</option>
    </select>
    <button id="now" type="button">Refresh now</button>
    <span>Since a stale reading looks identical to a live one, this never caches.</span>
  </footer>
</div>
<script>
(function () {
  var auto = document.getElementById('auto');
  var interval = document.getElementById('interval');
  var timer = null;

  function schedule() {
    if (timer) clearInterval(timer);
    if (auto.checked) timer = setInterval(refresh, Number(interval.value));
  }

  function refresh() {
    // cache: 'no-store' because the browser caching a health page is the same
    // failure as a proxy caching it: the operator reads a number that stopped
    // moving and concludes the system is idle.
    fetch(location.href, {
      headers: { Accept: 'text/html' },
      cache: 'no-store',
      credentials: 'same-origin',
    })
      .then(function (response) {
        if (!response.ok) throw new Error('HTTP ' + response.status);
        return response.text();
      })
      .then(function (html) {
        var parsed = new DOMParser().parseFromString(html, 'text/html');
        var incoming = parsed.getElementById('root');
        var current = document.getElementById('root');
        if (incoming && current) current.replaceWith(incoming);
        bind();
      })
      .catch(function (error) {
        // A failed refresh is reported rather than swallowed: silently stopping
        // is what makes a dashboard worse than no dashboard.
        var status = document.querySelector('.badge');
        if (!status) return;
        status.className = 'badge degraded';
        status.lastChild.textContent = 'Refresh failed (' + error.message + ')';
      });
  }

  function bind() {
    auto = document.getElementById('auto');
    interval = document.getElementById('interval');
    auto.addEventListener('change', schedule);
    interval.addEventListener('change', schedule);
    document.getElementById('now').addEventListener('click', refresh);
    schedule();
  }

  bind();
})();
</script>
</body>
</html>`;
}
