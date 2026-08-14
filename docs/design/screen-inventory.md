# FixNow Screen Inventory

Status: current-state acceptance inventory

Last audited: 2026-08-14 (FN-087)

Branch: `fix/local-booking-schema`

This inventory is based on inspected routes/source, automated checks, and a physical Android walkthrough. Backend capability alone does not make a screen complete.

## Classification

- **EXISTS + WORKING:** reachable and connected to the implemented backend behavior.
- **EXISTS + PARTIAL:** reachable, but an advertised or required part is absent.
- **EXISTS + BROKEN:** reachable but failed during acceptance testing.
- **MISSING:** no usable screen exists for an in-scope capability.
- **BLOCKED BY BACKEND:** UI completion needs a missing backend contract.
- **FUTURE:** roadmap work outside the current MVP audit.

## Mobile inventory

| Screen | Route | Role | Feature | Source file | Backend dependency | Reachable from UI? | Tested? | Result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Welcome | Root/welcome | Shared | Entry | `mobile/lib/auth/welcome_screen.dart` | None | Yes | Physical + widget | EXISTS + WORKING |
| Role selection | Root/role | Shared | Entry | `mobile/lib/auth/role_selection_screen.dart` | None | Yes | Physical + widget | EXISTS + WORKING |
| Registration/sign in | Root/auth | Shared | Authentication | `mobile/lib/auth/auth_screen.dart` | Customer/provider auth APIs | Yes | Physical customer + automated roles | EXISTS + WORKING |
| Email verification | Root/verification | Shared | Authentication | `mobile/lib/auth/verification_screen.dart` | OTP APIs | Yes | Physical local-dev OTP + widget | EXISTS + WORKING |
| Session restore | Root state | Shared | Authentication | `mobile/lib/app/app.dart` | Refresh/session store | Yes | Physical restart + unit | EXISTS + WORKING |
| Customer home/categories | Shell/Home | Customer | Discovery | `mobile/lib/features/services/service_discovery_screen.dart` | Active categories | Yes | Physical + widget | EXISTS + WORKING |
| Location consent | Home card/system dialog | Customer | Location | `mobile/lib/features/location/location_consent_card.dart` | Device location | Yes | Physical grant + denial widget | EXISTS + WORKING |
| Service request | Push/request | Customer | Booking | `mobile/lib/features/bookings/service_request_screen.dart` | `POST /bookings` | Yes | Physical | EXISTS + WORKING |
| Booking list | Shell/Bookings | Customer | Booking | `mobile/lib/features/bookings/customer_bookings_screen.dart` | `GET /bookings` | Yes | Physical + widget | EXISTS + WORKING |
| Booking details | Push/bookings/:id | Customer | Booking | `mobile/lib/features/bookings/booking_detail_screen.dart` | Booking history projection | Yes | Physical/source | EXISTS + PARTIAL — no cancel action, provider read model, or live data |
| Live tracking screen | Booking details → tracking | Customer | Realtime/location | `mobile/lib/features/tracking/booking_tracking_screen.dart`, `mobile/lib/features/realtime/realtime_client.dart` | HTTP reconciliation plus authenticated WebSocket projection updates | Yes for active assigned jobs | Widget + realtime client tests | EXISTS + PARTIAL — location is honestly unavailable until an authorized fresh point arrives |
| Customer profile | Shell/Profile | Customer | Profile | `mobile/lib/features/profile/customer_profile_screen.dart` | Profile API | Yes | Physical + widget | EXISTS + WORKING |
| Help | Shell/Help | Customer | Support | `mobile/lib/app/app_shell.dart` | Support contract absent/in progress | Yes | Physical | EXISTS + PARTIAL — honest preview (FN-075) |
| Provider registration | Root/auth provider | Provider applicant | Authentication | `mobile/lib/auth/auth_screen.dart` | Provider auth API | Yes | Widget/source | EXISTS + WORKING |
| Provider verification status | Root/provider onboarding | Provider applicant | Onboarding | `mobile/lib/features/provider/provider_onboarding_screen.dart` | Own application API | Yes by role | Widget/source | EXISTS + WORKING |
| Professional setup | Push/provider setup | Provider applicant | Profile/skills/area/documents | `mobile/lib/features/provider/provider_setup_screen.dart` | Profile, skills, categories, private documents | Yes | Widget/source; prior physical evidence | EXISTS + PARTIAL — no applicant submit transition |
| Provider home | Provider shell/Home | Verified provider | Workspace | `mobile/lib/features/provider/provider_home_screen.dart` | Profile, availability, assigned history | Yes by role | Widget/source | EXISTS + WORKING for assigned work |
| Availability/schedule | Provider Home | Verified provider | Availability | `mobile/lib/features/provider/provider_home_screen.dart` | Availability API | Yes | Unit/source | EXISTS + WORKING |
| Incoming requests | Provider Home | Verified provider | Matching | `mobile/lib/features/provider/provider_home_screen.dart` | Privacy-safe eligible-request feed with manual refresh | Yes by role | Widget + controller/repository tests | EXISTS + WORKING for eligible previews |
| Incoming request detail/accept | Provider Home request card | Verified provider | Booking acceptance | `mobile/lib/features/provider/provider_home_screen.dart` | Request details and atomic accept action; conflict returns honest recovery state | Yes by role | Widget + controller/backend tests | EXISTS + WORKING |
| Active assigned job | Provider shell/Active Job | Verified provider | Lifecycle | `mobile/lib/features/provider/provider_jobs_screen.dart` | Assigned `GET /bookings`, status command | Yes by role | Widget/integration backend | EXISTS + PARTIAL — unreachable through normal marketplace flow |
| Provider history | Provider shell/History | Verified provider | Booking history | `mobile/lib/features/provider/provider_jobs_screen.dart` | Assigned `GET /bookings` | Yes by role | Widget/source | EXISTS + WORKING for assigned records |
| Provider profile | Provider shell/Profile | Verified provider | Profile | `mobile/lib/features/provider/provider_onboarding_screen.dart` | Provider APIs | Yes by role | Widget/source | EXISTS + PARTIAL — onboarding composition reused |
| Provider live-location controls | Provider Active Job | Verified provider | Location/realtime | `mobile/lib/features/provider/provider_jobs_screen.dart`, `mobile/lib/features/realtime/realtime_client.dart` | Consent and current-device location publication controls for `EN_ROUTE` jobs | Yes by role | Mobile source + backend policy tests | EXISTS + PARTIAL — device permission/error recovery remains platform-dependent |
| Customer/provider cancellation | Booking details / Provider Active Job | Both | Booking | `mobile/lib/features/bookings/booking_detail_screen.dart`, `mobile/lib/features/provider/provider_jobs_screen.dart` | Reason, confirmation, expected-version command, loading/error recovery | Yes in permitted states | Widget + repository/controller tests | EXISTS + PARTIAL — backend remains authoritative for denial/reconciliation |

## Admin inventory

| Screen | Route | Role | Feature | Source file | Backend dependency | Reachable from UI? | Tested? | Result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Admin login | `/login` | Staff | Authentication | `admin/src/app/login/page.tsx` | Admin auth | Yes | Unit/build | EXISTS + WORKING in source; live login blocked by no documented local staff fixture |
| Dashboard/shell | `/` | Staff | Navigation | `admin/src/app/page.tsx` | Session | Yes | Unit/build | EXISTS + WORKING |
| Provider queue | `/providers` | Reviewer | Verification | `admin/src/app/providers/page.tsx` | Admin applications API | Yes | Build/source | EXISTS + WORKING |
| Provider review/documents | `/providers/:id` | Reviewer | Verification | `admin/src/app/providers/[applicationId]/page.tsx` | Claim/decision/private document APIs | Yes | Unit/build/backend tests | EXISTS + WORKING in source; live fixture unavailable |
| Customer/user management | `/users`, `/users/:id` | Staff | Users | `admin/src/app/users/` | Minimized admin user APIs | Yes | Build/backend tests | EXISTS + WORKING |
| Booking management | `/bookings`, `/bookings/:id` | Operations | Booking | `admin/src/app/bookings/` | Admin booking APIs | Yes | Build/source | EXISTS + WORKING |
| Service management | `/services` | Catalog manager | Taxonomy | `admin/src/app/services/page.tsx` | Admin service APIs | Yes | Build/source | EXISTS + WORKING |
| Complaints | None | Support/trust | Trust | None | Not implemented | No | Source audit | FUTURE / ROADMAP |
| Analytics | None | Operations | Analytics | None | Not implemented | No | Source audit | FUTURE / ROADMAP |

## Dead or unreachable implementation

- `BookingTrackingOverviewScreen` exists but is not used by production navigation; active booking tracking now routes through `BookingTrackingScreen`.
- The provider can view only bookings already assigned to that provider. There is no incoming/unassigned request route.

## MVP gaps

- Core: provider incoming-request discovery and request acceptance UI/contract (FN-088).
- Core: mobile realtime booking synchronization and provider live-location integration (FN-089).
- Supporting: Help remains an honest preview while FN-075 is in progress.

## Roadmap, not defects

Payments, invoices/refunds, earnings, ratings/reviews, AI/voice/image assistance, push notifications, emergency dispatch, complaints, and analytics remain future work.
