/**
 * A minimal stand-in for the admin API, for end-to-end journeys only.
 *
 * TEST-001. The three specs this replaces did `page.goto('about:blank')`,
 * `page.setContent('<h1>FixNow Customer App</h1>')`, screenshotted it, and
 * asserted the heading they had just written. They passed against a browser with
 * no FixNow code loaded, and CI never ran them, so they had never passed or
 * failed in anyone's pipeline either.
 *
 * This is a stub for the *dependency*, not for the subject. The admin app under
 * test is the real one: real routing, real server components, real session
 * classification, real role gates. What is faked is the network it talks to.
 *
 * It has to be a real server rather than `page.route()` because the session is
 * read on the server: `getSession()` calls `readAdminSession()` from a React
 * Server Component, so the request never passes through the browser and a
 * route-level interceptor cannot see it. Stubbing in the browser would have
 * tested the login page with the authenticated branch unreachable - which is the
 * branch worth testing.
 *
 * Only the endpoints the journeys assert on are implemented. Anything else
 * answers 404 rather than guessing, so a journey that starts depending on an
 * unstubbed endpoint fails loudly instead of rendering an empty page and
 * passing a loose assertion.
 */
import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';

const PORT = Number(process.env.E2E_STUB_API_PORT ?? 3199);

/**
 * The real StaffRole union, copied from admin/src/auth/types.ts.
 *
 * Spelled out here rather than imported because the e2e package does not depend
 * on the admin app's source tree, and a stub that quietly accepted a role the app
 * does not recognise would make every role-gate journey pass against a branch
 * that can never be reached in production. `operations_administrator`,
 * `support_agent`, `trust_safety_reviewer`, `auditor` are the ones the journeys
 * use; the rest are here so a mismatch is a type error rather than a silent 403.
 */
type StaffRole =
  | 'provider_reviewer'
  | 'support_agent'
  | 'trust_safety_reviewer'
  | 'finance_operator'
  | 'service_catalog_manager'
  | 'operations_administrator'
  | 'security_administrator'
  | 'auditor';

interface StubSession {
  userId: string;
  roles: readonly StaffRole[];
}

/**
 * The session is chosen by the bearer token, so a journey can select a role by
 * choosing a token. This is what makes the role gate testable: the same code
 * path renders two different pages depending only on what the API says.
 */
const tokens: Record<string, StubSession> = {
  'e2e-analytics': { userId: 'staff-analytics', roles: ['operations_administrator'] },
  'e2e-auditor': { userId: 'staff-auditor', roles: ['auditor'] },
  'e2e-support': { userId: 'staff-support', roles: ['support_agent'] },
  'e2e-trust': { userId: 'staff-trust', roles: ['trust_safety_reviewer'] },
};

/**
 * A session that authenticates but is refused by every management endpoint.
 *
 * `readAdminSession` accepts it, so the app gets past the login check, and then
 * the module request is denied. That is the 403 branch of
 * `requireManagementResult`, which is a different destination from the 401 branch
 * - and therefore a different page - so it needs its own token rather than a
 * route interception.
 */
const deniedToken = 'e2e-forbidden';

function isDenied(req: IncomingMessage): boolean {
  const header = req.headers.authorization;
  return typeof header === 'string' && header.includes(deniedToken);
}

const analytics = {
  generatedAt: '2026-08-14T10:00:00.000Z',
  bookings: { total: 1284, completed: 1102, cancelled: 96, pending: 86 },
  providers: { total: 412, active: 287, verified: 350, pendingVerification: 62 },
  services: {
    topCategories: [
      { id: 'cat-plumbing', name: 'Plumbing', count: 312 },
      { id: 'cat-electrical', name: 'Electrical', count: 208 },
    ],
  },
  emergencies: { activeRequests: 7, totalRequests: 94 },
  trust: { averageAcceptMinutes: 4.2, sampleSize: 180, windowDays: 30 },
};

/**
 * Complaints, matching the `Complaint` type in admin/src/features/support/types.ts.
 *
 * The field names are the app's, not invented ones: an earlier version of this
 * stub used `reference` and `subject`, which do not exist on that type, so the
 * support page rendered rows with an empty reference and the journey asserted
 * against text that could never appear. Shape a stub from the type the consumer
 * expects, or the journey is testing the stub.
 *
 * The ids are long and distinctive because the page renders a shortened form of
 * them, and the distinct values are what prove the shortening happened.
 */
const complaints = [
  {
    // The distinguishing digits come AFTER the eight characters shortId() keeps
    // (`cmp-e2e-` plus one more), because the first draft used
    // cmp-e2e-0000000000000001 and cmp-e2e-0000000000000002 - both of which
    // shorten to CMPE2E00. Two rows the page cannot tell apart, which would have
    // made "both complaints are listed" pass on one row alone.
    id: 'cmp-e2e-1111111111111111',
    submitterId: 'usr-e2e-customer-1111',
    targetRole: 'PROVIDER',
    targetId: 'prv-e2e-1',
    bookingId: 'bk-e2e-1',
    category: 'NO_SHOW',
    description: 'Provider did not arrive within the ETA window.',
    status: 'ESCALATED',
    createdAt: '2026-08-13T09:15:00.000Z',
    updatedAt: '2026-08-13T10:00:00.000Z',
    evidence: [],
  },
  {
    id: 'cmp-e2e-2222222222222222',
    submitterId: 'usr-e2e-customer-2222',
    targetRole: 'CUSTOMER',
    bookingId: 'bk-e2e-2',
    category: 'REFUND',
    description: 'Refund not received after cancellation.',
    status: 'OPEN',
    createdAt: '2026-08-12T17:40:00.000Z',
    updatedAt: '2026-08-12T17:40:00.000Z',
    evidence: [],
  },
];

function send(res: ServerResponse, status: number, body: unknown): void {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json',
    'content-length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

function sessionFor(req: IncomingMessage): StubSession | null {
  const header = req.headers.authorization;
  if (typeof header !== 'string') return null;
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  if (!match) return null;
  return tokens[match[1]] ?? null;
}

const server = createServer((req, res) => {
  const url = new URL(req.url ?? '/', `http://127.0.0.1:${PORT}`);
  const path = url.pathname.replace(/^\/api\/v1/, '');

  if (path === '/auth/admin/session') {
    if (isDenied(req)) {
      // Authenticates, so the app proceeds past the login check.
      send(res, 200, { userId: 'staff-forbidden', roles: ['support_agent'] });
      return;
    }
    const session = sessionFor(req);
    if (!session) {
      // 401, not 403: the admin app classifies a 403 as `unauthorized`, which
      // redirects to /unauthorized rather than to /login. Getting this wrong
      // would make every journey pass against the wrong branch.
      send(res, 401, { code: 'unauthenticated', message: 'Access token required' });
      return;
    }
    send(res, 200, session);
    return;
  }

  if (path === '/admin/analytics') {
    if (isDenied(req)) {
      send(res, 403, { code: 'not-permitted', message: 'Requires management role' });
      return;
    }
    send(res, 200, analytics);
    return;
  }

  if (path === '/admin/complaints') {
    if (isDenied(req)) {
      send(res, 403, { code: 'not-permitted', message: 'Requires management role' });
      return;
    }
    // A bare array, because that is what `listComplaints()` is typed to return.
    // The support page maps over the result directly, so an envelope here would
    // render zero rows and every assertion about complaint content would fail -
    // correctly, but for a reason that has nothing to do with the app.
    send(res, 200, complaints);
    return;
  }

  send(res, 404, {
    code: 'not-stubbed',
    message: `No stub for ${path}. Add one deliberately rather than letting a journey render an empty page.`,
  });
});

server.listen(PORT, '127.0.0.1', () => {
  process.stdout.write(`e2e stub api listening on http://127.0.0.1:${PORT}/api/v1\n`);
});

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
