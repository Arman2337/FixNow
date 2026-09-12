# FixNow Professional Redesign — Design Specification

## Status and decision

**Approved:** 2026-09-12  
**Scope:** customer Flutter app, provider Flutter app, and Next.js admin  
**Visual reference:** user-supplied FixNow screens, used for quality and direction only

FixNow will receive a phased, flow-based professional redesign. This is not a feature reduction, data migration, or backend change. The redesign preserves every currently implemented route, behavior, permission check, API integration, and source of truth.

## Current-state map

| Area | Existing implementation | Redesign boundary |
| --- | --- | --- |
| Mobile composition | `mobile/lib/app/app.dart` constructs repositories/controllers and chooses customer/provider shells | Retain composition, route callbacks, session restore, dependency injection |
| Navigation | `app_shell.dart`, `app_navigation.dart`, `fix_bottom_navigation.dart` | Preserve customer Home/Bookings/Help/Profile and provider Home/Active Job/History/Profile |
| Design system | `mobile/lib/design_system/` | Update tokens and reusable components before screens |
| State/data | Feature `ChangeNotifier` controllers and repository adapters over `ApiClient` | No data/API shape or controller contract change |
| Realtime | `features/realtime/realtime_client.dart`, booking/provider/tracking controllers | Retain authenticated socket lifecycle, projections, location consent, freshness semantics |
| Auth | `auth/*`, `AuthController`, secure/web stores | Retain email/password, OTP, roles, restore/refresh |
| AI | `features/ai/*`, backend analysis adapters | Retain live text/photo/voice analysis and advisory result semantics |
| Payments | `features/payments/*` | Retain payment, refund/business rules, invoice/receipt behavior |
| Admin | `admin/src/features/*`, `management-api.ts`, `app/**` | Retain server-side session/role behavior and management endpoints |

### Mobile screens and flows

Entry/auth includes welcome, role selection, registration/sign-in, email verification/OTP, session restore, provider onboarding and professional setup.

Customer includes home/service discovery, location consent/address selection, universal search, AI recommendation and diagnosis, service/subservice catalogue, service request, recurrence/scheduling, bookings/detail/lifecycle, live tracking, chat, calls, payment/invoice/share, review/photos, profile, notifications, help, complaints, and emergency confirmation.

Provider includes onboarding/verification, skills/service area/documents, availability/schedule, incoming requests/acceptance, active job/OTP/lifecycle/proof, customer-location publication/tracking, history, earnings, profile, notifications, chat and calls.

Admin routes are `/`, `/login`, `/users`, `/users/[userId]`, `/providers`, `/providers/[applicationId]`, provider document route, `/services`, `/bookings`, `/bookings/[bookingId]`, `/support`, `/support/[complaintId]`, `/analytics`, `/trust`, and `/unauthorized`.

### Non-negotiable constraints

- Never replace real API results with reference-image/example content.
- Preserve permissions, booking lifecycle/conflict recovery, location consent/freshness, payment ambiguity handling, and AI safety/uncertainty semantics.
- Do not create endpoints or modify backend contracts merely to fit a new layout.

## Design decision

`DESIGN.md` is the authoritative system. The family uses ivory surfaces, deep evergreen brand emphasis, restrained gold trust/rating emphasis, contrast-safe dark typography, and semantic operational statuses. The signature is **the calm operational panel**: a crisp light information surface paired with a compact evergreen action region for the screen’s decisive real task.

## Layout and information architecture

### Customer

```text
location / notification
greeting + universal search
AI Assistant: text | photo | voice
current booking (only when active)
contextual categories
real recommended providers/services
bottom navigation
```

AI diagnosis retains existing controller/repository state, including individual/combined media support. Results present real detected issue/category, confidence, urgency, needed skills, estimate, disclaimer, and category-forward “find experts” action. Permission, upload, failure, disabled, and unavailable states remain explicit.

Discovery uses filterable, comparison-oriented service/provider cards. Booking details, tracking, payment, invoice, reviews, support, emergency, and profile keep existing actions/data but receive hierarchy around the booking’s true state and one primary next action.

### Provider

```text
availability / service area
urgent incoming requests
active job or honest empty state
today’s work and earnings signal
notification / profile access
bottom navigation
```

The active-job cockpit remains state-first: allowed customer/service context, navigation/location consent, OTP, safety note, lifecycle action, proof/completion, and chat/call. It derives state only from existing booking/controller/realtime sources.

### Admin

```text
role-aware collapsible sidebar | page header + account controls
                             | operational summary / queue context
                             | real filters, table/list, detail action rail
```

Existing management modules are redesigned as operational queues and drill-downs. Only real accessible totals are displayed. A named module only appears once backed by an authorized route and data contract—no fake zero metrics or inactive product claims.

## Component architecture

### Flutter foundation

Evolve `app_colors.dart`, `app_typography.dart`, `app_spacing.dart`, `app_radius.dart`, `app_shadows.dart`, `app_motion.dart`, `app_theme.dart`, and existing `Fix*` components. Preserve public roles where possible; add variants rather than duplicate components; replace overly decorative effects only when consumers retain behavior.

### Admin foundation

Centralize CSS semantic variables in `admin/src/app/globals.css`. Add focused reusable page-header, metric/queue-card, status, filter-row, empty/error/loading, and table/action-row components under existing admin conventions. Before modifying Next 16 code, read relevant local Next documentation.

## Delivery phases and acceptance gates

### Phase 1 — foundation

Update centralized tokens/typography/icon policy; modernize shared Flutter components and add admin equivalents; adjust component/contrast tests; verify both apps build without navigation/data contract changes.

### Phase 2 — customer

Migrate: Home + location/search; AI diagnosis/recommendation; service/provider discovery; request/booking lifecycle; tracking/chat/call; payments/invoice/reviews; profile/help/notifications/emergency. Each slice validates real-data, loading, empty, error, and permission-sensitive states.

### Phase 3 — provider

Migrate: dashboard/availability/incoming requests; active job/tracking/OTP/proof; history/earnings; profile/onboarding/verification. Verify acceptance conflict recovery, pre/post-acceptance privacy, location permission, and realtime freshness.

### Phase 4 — admin

Migrate: shell/overview; users/providers/documents; services/bookings; support/trust; analytics/access. Verify roles/route guards, form/action states, filter/pagination behavior, keyboard focus, and desktop layout.

## Verification

- Flutter: targeted widget/controller/repository tests; `flutter analyze`; Android/iOS-sized walkthroughs; text-scale and permission-denial coverage.
- Admin: targeted Vitest; `npm run lint`, `npm run type-check`, `npm run build`; keyboard/focus and responsive checks.
- Cross-cutting: contrast validation, reduced motion, scan for demo data, regression confirmation for auth, booking, realtime/location, AI, payment, push, support, and permissions.

## Out of scope

No missing-backend feature work, business-policy rewrite, unapproved dependency/assets, or fabricated UI state. A product gap exposed by migration receives an honest UI state and a separate proposal.

