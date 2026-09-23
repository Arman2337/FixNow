# FixNow Runtime-Only Audit

**Audit date:** 2026-09-16 (Asia/Calcutta)  
**Scope requested:** Customer, provider, and admin browser flows; broken controls/navigation; API, backend, and database errors; static business data.  
**Method:** Runtime startup and HTTP smoke checks, followed by attempted browser automation. No application code was modified.

## Executive Summary

The runtime is not currently auditable end-to-end because none of the two browser applications can be opened from the documented local URLs.

- Backend and reverse proxy start and listen on ports `3300` and `8080`.
- Flutter web does not start on the documented port `51354`.
- Admin Next.js does not start on the documented port `3100`.
- Browser automation was attempted, but the environment's automatic approval service returned `503 Service Unavailable` and denied localhost browser access. No browser-policy workaround was attempted.

**Runtime health:** **Blocked / 20 of 100**  
**Verified findings:** 3 P0/P1 blockers, 1 P2 API-contract concern.  
**Flow coverage:** Customer 0%, provider 0%, admin 0% because both frontends are unavailable.

## Priority Findings

### P0 — Customer and provider web application fails to start

**Area:** Flutter web / customer and provider flows  
**Impact:** Total outage for browser-based customer and provider journeys. No screen, button, navigation path, booking flow, provider job flow, or error state can be reached.

**Reproduction**

1. From the repository root, run `npm run dev`.
2. The orchestrator announces `Open http://localhost:51354`.
3. The launcher emits two errors: `Cannot read file "C:\Users\patel\OneDrive\": EPERM`.
4. Check `http://localhost:51354`; the connection is refused.

**Evidence**

- No listener exists on port `51354` after startup.
- An HTTP request to `http://localhost:51354` returns: `No connection could be made because the target machine actively refused it.`
- Backend port `3300` and proxy port `8080` remain available, isolating the failure to the web client startup stage.

**Affected requested checks:** All customer flows, all provider flows, all mobile-web buttons and navigation, static business-data verification.

### P0 — Admin portal fails to start

**Area:** Admin  
**Impact:** Total outage for administration. Login, operations dashboard, bookings, providers, services, support, trust, users, and analytics cannot be used or audited.

**Reproduction**

1. In `admin`, run `npm run dev`.
2. Next.js exits immediately.
3. Observe `Error: spawn EPERM` from `next-dev.js`.
4. Confirm no listener exists on port `3100`.

**Evidence**

- The admin process exits with code 1.
- Port `3100` is not listening.

**Affected requested checks:** All admin flows, buttons, navigation, API integration, and database-backed admin data.

### P1 — Documented full-stack startup reports success before the frontend is actually available

**Area:** Runtime orchestration / operability  
**Impact:** Operators receive a usable-looking URL even though the main application failed to launch. This masks the outage and can produce false-positive startup checks.

**Reproduction**

1. Run `npm run dev`.
2. Observe the success-style message `Open http://localhost:51354`.
3. Immediately verify the port; no process is listening and the URL refuses the connection.

**Expected:** The orchestrator should report the application ready only after the frontend accepts connections, or exit visibly when the child process fails.

**Actual:** The command remains active with backend/proxy processes despite the advertised main UI being unavailable.

### P2 — Backend service catalog route returns 404 on both direct and proxied URLs

**Area:** API / service discovery  
**Impact:** If the frontend currently requests this conventional catalog URL, customer service discovery cannot load. The precise client contract could not be confirmed through browser network inspection because the frontend did not start.

**Runtime evidence**

- `GET http://localhost:3300/api/v1/services` → `404 Not Found`
- `GET http://localhost:8080/api/v1/services` → `404 Not Found`
- `GET http://localhost:3300/api/v1` → `200 OK`, body `Hello World!`

**Limit:** This is an API-contract concern, not a confirmed broken UI request. It should be compared with the actual runtime request once the frontend starts.

## Runtime Checks Performed

| Surface | Check | Result |
|---|---|---|
| Full stack | `npm run dev` | Partial start; backend/proxy live, Flutter web failed |
| Flutter web | Port `51354` | Connection refused; no listener |
| Admin | `npm run dev` on port `3100` | Process exits with `spawn EPERM`; no listener |
| Backend | Port `3300` | Listening |
| Reverse proxy | Port `8080` | Listening |
| Backend root API | `GET /api/v1` | 200, `Hello World!` |
| Backend health candidates | `GET /health`, proxy `/health` | 404 |
| Service catalog candidate | Direct and proxy `GET /api/v1/services` | 404 |
| Browser automation | Open local application URL | Denied because automatic approval review returned 503 |

## Requested Flow Coverage

| Flow | Status | Reason |
|---|---|---|
| Customer registration/login | Not testable | Flutter web unavailable |
| Customer service discovery/search | Not testable | Flutter web unavailable |
| Customer booking/payment/tracking/chat/call/support | Not testable | Flutter web unavailable |
| Provider login/onboarding/availability/jobs/earnings | Not testable | Flutter web unavailable |
| Admin login/dashboard/navigation/data actions | Not testable | Admin unavailable |
| Static business data in rendered UI | Not testable | No frontend rendered |
| Backend/database errors triggered by UI actions | Not testable | No frontend rendered |

## Top 3 Problems to Address Before Deeper Runtime QA

1. Restore Flutter web startup and verify port `51354` becomes reachable before printing the ready URL.
2. Restore admin startup on port `3100`.
3. Re-run the full browser audit after both surfaces are reachable, prioritizing login, booking acceptance, booking lifecycle, provider availability, admin operations, and rendered values that should come from the database.

## Audit Limitations

- The instruction was runtime-only; source code was not used to manufacture UI findings and no application code was changed.
- Interactive screenshots could not be captured because the applications were unavailable and browser access was denied when the approval-review service returned a 503.
- Credentials and seeded test identities were not used because no login UI was reachable.
- This report intentionally does not claim that unvisited screens or buttons work.

## Suggested Next Audit Pass

Once ports `51354` and `3100` respond, repeat this audit with browser console/network capture and cover:

1. Customer: registration/login → discovery → subservice/cart → address/schedule → booking → payment → tracking/chat/call → completion/review/support.
2. Provider: login/onboarding → online/offline → request accept/reject → navigation/chat/call → OTP/work completion → earnings/history.
3. Admin: login → dashboard → bookings → providers → services → support → trust → users → analytics, testing every visible action and browser back/forward behavior.
4. Compare displayed prices, ratings, names, counts, ETAs, invoice values, and availability against their API responses to detect static business data.
