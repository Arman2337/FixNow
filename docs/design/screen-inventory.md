# FixNow Mobile Screen Inventory

Status: authoritative coverage audit

Last audited: 2026-08-14

Branch: `feat/customer-core-journey`

This inventory maps the required customer and provider mobile experience to implemented Flutter surfaces, backend contracts, product requirements, and tracked work. A screen is not considered implemented because a backend endpoint or visual placeholder exists.

## Classification

- **EXISTS + GOOD:** implemented, reachable, validated, and aligned with the design direction.
- **EXISTS + NEEDS REDESIGN:** implemented and functional, but still uses the superseded light/blue system.
- **PARTIAL:** some UI or contract exists, but the complete experience is not reachable or supported.
- **MISSING:** required and supported enough to implement, but no production mobile screen exists.
- **BLOCKED:** the experience depends on unfinished product/backend work.
- **FUTURE:** explicitly outside the approved current product scope.

Routes are conceptual because the current app uses a root state switch, an indexed shell, and direct `MaterialPageRoute` pushes rather than named routes.

## Foundation and shared states

| Screen | Role | Feature | Current status | Route | Implementation status | Design status | Dependencies | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Session restore | Shared | Authentication | EXISTS + NEEDS REDESIGN | Root state | Functional | Generic fullscreen spinner | FN-036, FN-076 | Replace with branded, non-jumping launch state. |
| Welcome / entry | Shared | Onboarding | EXISTS + GOOD | Root | Get Started and Sign In are implemented | Premium dark | FN-081 | Does not claim unsupported auth methods. |
| Role selection | Shared | Onboarding | EXISTS + GOOD | Onboarding | Customer/provider selection implemented | Premium dark | FN-025, FN-081 | Registration and sign-in intents remain explicit. |
| Global offline state | Shared | Reliability | PARTIAL | Overlay/contained | Feature-level handling exists | Inconsistent | FN-080 | Needs shared banner and stale-state language. |
| Global error state | Shared | Reliability | PARTIAL | Reusable component | Screen-specific implementations | Inconsistent | FN-080 | Preserve input and provide recovery. |
| Empty state system | Shared | Reliability | PARTIAL | Reusable component | Ad hoc cards | Inconsistent | FN-080 | Bookings, jobs, notifications, reviews, and earnings require dedicated variants. |
| Skeleton/loading system | Shared | Reliability | MISSING | Reusable component | Mostly spinners/text | Required | FN-080 | Use shape-matched skeletons without fake data. |

## Authentication and onboarding

| Screen | Role | Feature | Current status | Route | Implementation status | Design status | Dependencies | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Shared sign in | Shared | Authentication | EXISTS + GOOD | Root/auth | Customer/provider email/password works with persisted server-resolved role | Premium dark | FN-024, FN-026, FN-081 | Separate entry endpoints share server-side role resolution. |
| Customer registration | Customer | Authentication | EXISTS + GOOD | Root/auth register mode | Email/password registration works | Premium dark | FN-024, FN-026, FN-081 | Collects only supported credentials. |
| Email OTP verification | Shared | Authentication | EXISTS + NEEDS REDESIGN | Root/verification | Functional | Superseded light/blue | FN-026, FN-081 | Six-digit email code; do not label as phone verification. |
| Forgot password | Shared | Authentication | BLOCKED | Auth | No recovery contract | Not designed | New backend recovery task | Must not expose an inert action. |
| Provider registration entry | Provider | Authentication | EXISTS + GOOD | Onboarding/provider | Backend registration, email verification, persisted role, and honest handoff work | Premium dark | FN-025, FN-081 | Routes to incomplete onboarding state, never customer shell. |
| Provider personal/profile setup | Provider | Onboarding | MISSING | Provider onboarding | Backend profile contract exists | Required | FN-030, FN-083 | Collect only supported fields. |
| Provider categories and skills | Provider | Onboarding | MISSING | Provider onboarding | Backend skills contract exists | Required | FN-029, FN-083 | Verification state is distinct from skill claims. |
| Provider service area | Provider | Onboarding | MISSING | Provider onboarding | Coverage contract exists | Required | FN-030, FN-083 | Must follow location/privacy policy. |
| Provider document upload | Provider | KYC | MISSING | Provider onboarding | Private upload contract exists | Required | FN-031, FN-083 | Never cache or expose documents as ordinary media. |
| Provider onboarding review | Provider | Onboarding | MISSING | Provider onboarding | Backend fields exist | Required | FN-030, FN-031, FN-083 | Review before submission; no fake approval. |
| Provider verification status | Provider | Verification | MISSING | Provider/status | Backend supports unverified, under review, approved, rejected, resubmission requested | Required | FN-032, FN-083 | Suspended is an account state, not an onboarding status. |

## Customer experience

| Screen | Role | Feature | Current status | Route | Implementation status | Design status | Dependencies | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Customer home | Customer | Discovery | EXISTS + GOOD | Shell/Home | Categories and foreground location work | Premium dark | FN-037, FN-082 | Nearby-provider data is not currently returned, so the UI makes no proximity claims. |
| Emergency entry | Customer | Safety | BLOCKED | Home/contextual | Not implemented | Future design only | FN-063, FN-064 | Must not imply emergency response before policy and dispatch exist. |
| All services | Customer | Discovery | PARTIAL | Home | Active category grid exists | Needs redesign | FN-037, FN-082 | No separate search/detail taxonomy experience. |
| Service search | Customer | Discovery | MISSING | Home/services/search | No mobile search | Required | FN-029, FN-082 | Search only backend-supported active categories. |
| Service detail | Customer | Discovery | MISSING | Home/services/:id | Category endpoint exists | Required | FN-029, FN-082 | Scope/pricing content is limited by current contract. |
| Problem entry | Customer | Booking | EXISTS + GOOD | Push/service-request | Text request works | Premium dark | FN-039, FN-082 | Voice/photo/AI are blocked; no fake controls are shown. |
| AI-assisted problem entry | Customer | AI | BLOCKED | Request | No approved AI service | Future | FN-016, FN-056–FN-059 | Manual text remains the deterministic fallback. |
| Location permission explanation | Customer | Location | PARTIAL | Home/request | Foreground consent card exists | Needs redesign | FN-037, FN-082 | Denial is handled; precise location remains purpose-bound. |
| Choose/search/confirm address | Customer | Location | MISSING | Request/location | No address/map-pin contract | Required later | FN-082 plus address contract task | Do not infer saved addresses from profile. |
| Saved addresses | Customer | Location | BLOCKED | Profile/addresses | No backend model | Not designed | New address-domain task | Must define retention and deletion first. |
| Provider matching | Customer | Matching | PARTIAL | Bookings/requested/detail | Booking card and detail communicate matching | Premium honest state | FN-040, FN-082 | No dedicated timeout/search projection is exposed to mobile. |
| Provider results | Customer | Marketplace | BLOCKED | Matching/results | Matching is backend-driven; no list contract | Not designed | New provider-discovery contract task | Do not fabricate ratings, ETA, distance, or prices. |
| Provider profile | Customer | Marketplace | BLOCKED | Providers/:id | No customer-safe aggregate endpoint | Not designed | FN-054 plus new read-model task | Private provider data must remain hidden. |
| Booking confirmation | Customer | Booking | PARTIAL | Service request | Explicit submit exists | Needs stronger review hierarchy | FN-039, FN-082 | No provider, price, payment, or cancellation-fee data exists. |
| Booking list | Customer | Booking | EXISTS + GOOD | Shell/Bookings | API-backed history and detail navigation work | Premium dark | FN-042, FN-082 | Cards expose authoritative status and request metadata only. |
| Booking details | Customer | Booking | EXISTS + GOOD | Bookings/:id | Reachable from booking cards | Premium dark | FN-042, FN-082 | Tracking/provider/price content remains explicitly unavailable until supplied by contracts. |
| Active booking tracking | Customer | Tracking | PARTIAL | Booking detail | Reachable honest tracking handoff exists | Premium map-ready composition | FN-045, FN-082 | No map is rendered until an authorized current provider location and configured SDK are available. |
| Tracking bottom sheet | Customer | Tracking | MISSING | Tracking overlay | Not implemented | Required | FN-045, FN-082 | Show only authorized and freshness-labelled data. |
| Service in progress | Customer | Booking | PARTIAL | Booking detail/tracking | Status can be displayed | Not composed | FN-041, FN-082 | Backend lifecycle uses `IN_PROGRESS`. |
| Service completion | Customer | Booking | MISSING | Booking completion | Completion state exists | Required | FN-041, FN-082 | Payment/invoice/warranty content remains blocked. |
| Rating and review | Customer | Trust | BLOCKED | Booking/rating | Not implemented | Not designed | FN-054 | Rich rating categories require an approved contract. |
| Customer profile hub | Customer | Account | EXISTS + GOOD | Shell/Profile | Basic name/phone edit and sign-out work | Premium dark | FN-028, FN-082 | Unsupported settings remain absent or explicitly unavailable. |
| Customer support | Customer | Support | PARTIAL | Shell/Help | Honest preview only | Needs full IA | FN-075 | No operational channel may be claimed yet. |
| Notifications | Customer | Notifications | BLOCKED | Contextual/profile | No push/mobile notification UI | Not designed | FN-061, FN-062 | Do not create fake unread items. |
| Payment methods | Customer | Payments | BLOCKED | Profile/payments | No payment architecture | Not designed | FN-051–FN-053 | Never collect card data before the provider model is approved. |
| Invoice/transaction detail | Customer | Payments | BLOCKED | Booking/payment | No financial records | Not designed | FN-052, FN-053 | Amounts and payment states must be authoritative. |

## Provider experience

| Screen | Role | Feature | Current status | Route | Implementation status | Design status | Dependencies | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Provider shell/navigation | Provider | Navigation | PARTIAL | Provider shell | Destination metadata exists; shell is never selected | Placeholder only | FN-083 | Role-aware bootstrap and provider controllers are missing. |
| Provider home/dashboard | Provider | Jobs | MISSING | Provider/Home | Backend profile/availability exists | Required | FN-083 | Earnings metrics remain blocked by FN-053. |
| Availability/schedule | Provider | Availability | MISSING | Provider/Home/availability | Backend get/update endpoints exist | Required | FN-033, FN-083 | Explicit Online/Busy/Offline sync and errors required. |
| Incoming requests | Provider | Matching | MISSING | Provider/Jobs | Matching service exists; no provider inbox/read contract | Required later | New provider job-feed task | Show minimum customer area before acceptance. |
| Request detail | Provider | Matching | MISSING | Provider/Jobs/:id | Acceptance command exists | Required later | FN-041 plus job-feed task | Acceptance must remain atomic. |
| Provider active job | Provider | Booking | MISSING | Provider/Active Job | Status commands exist | Required | FN-041, FN-083 | Controls: accepted → en route → in progress → completed only. |
| Provider navigation/tracking | Provider | Location | MISSING | Provider/Active Job/map | Location ingestion exists | Required later | FN-044, FN-083 | Consent, freshness, and background-location rules apply. |
| Provider job completion | Provider | Booking | MISSING | Provider/Active Job/complete | Completion transition exists | Required | FN-041, FN-083 | Charges/payment are not yet supported. |
| Provider history | Provider | Booking | MISSING | Provider/Jobs/history | Booking history endpoint is role-aware | Required | FN-042, FN-083 | Verify returned fields before exposing customer data. |
| Provider earnings | Provider | Finance | BLOCKED | Provider/Earnings | No financial ledger | Not designed | FN-053 | Never display generated balances. |
| Provider profile | Provider | Account | MISSING | Provider/Profile | Backend profile/skills endpoints exist | Required | FN-030, FN-083 | Reviews remain blocked by FN-054. |
| Provider documents | Provider | KYC | MISSING | Provider/Profile/documents | Private document contract exists | Required | FN-031, FN-083 | Download/delete require explicit safe UX. |
| Provider notifications | Provider | Notifications | BLOCKED | Provider/notifications | No push UI | Not designed | FN-061, FN-062 | Booking state remains authoritative. |

## Delivery order

1. FN-080 — migrate tokens, theme, motion, shared components, and role-aware navigation foundation.
2. FN-081 — implement premium welcome, role selection, shared auth, verification, and supported provider entry.
3. FN-082 — reconstruct the currently supported customer core and wire honest tracking states.
4. FN-083 — implement the backend-supported provider onboarding and operational mobile core.
5. Existing roadmap tasks then unlock support, payments, ratings, notifications, emergency, and AI screens.

## Evidence

- Flutter composition: `mobile/lib/app/`, `mobile/lib/auth/`, `mobile/lib/features/`, and `mobile/lib/design_system/`.
- Backend capability: `backend/src/auth/`, `backend/src/providers/`, `backend/src/bookings/`, `backend/src/location/`, `backend/src/realtime/`, and `backend/src/services/`.
- Shared lifecycle contracts: `shared/booking-lifecycle.types.ts` and `shared/booking-tracking.types.ts`.
- Product and privacy authority: `docs/product/requirements.md`, `docs/security/security-and-privacy-architecture.md`, and `docs/security/permission-matrix.md`.
- Implementation authority: `PROJECT_TASKS.md`.
