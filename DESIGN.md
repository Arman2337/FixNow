# FixNow Design System

Status: authoritative cross-platform design contract
Revision: 2026-09-12 — approved full professional redesign

FixNow is a trusted, real-time services platform. Customer mobile, provider mobile, and the admin web workspace share one visual language but use role-appropriate information architecture. This document governs visual decisions and reusable UI; product, accessibility, privacy, safety, permissions, and backend contracts remain authoritative.

## 1. Product promise and priorities

**Professional help, clearly coordinated.** Customers must quickly understand where they are, what help is available, what it costs, and what happens next. Providers must act on live work without losing safety or context. Administrators must resolve operational queues with traceable, role-appropriate actions.

Priority order: safety and honest system state; speed to the next action; trust (verification, price type, ETA, identity); clarity in dense operational information; consistency across roles and devices; refined visual quality without decoration that impairs use.

The approved visual reference informs tone, hierarchy, density, and component quality only. It does not supply application data, copy, assets, flows, or layouts to copy.

## 2. Visual language and tokens

FixNow uses warm ivory information surfaces, deep evergreen brand framing, restrained gold for ratings and trust, and dark readable typography. The overall feel is calm, precise, and international—not playful, generic, or ornamental. Applications consume semantic tokens, not raw hex values.

| Token | Value | Purpose |
| --- | --- | --- |
| `backgroundPrimary` | `#F6F3EC` | Page background / warm ivory |
| `backgroundSecondary` | `#ECE8DD` | Grouped page areas |
| `surfacePrimary` | `#FFFFFF` | Cards, inputs, sheets, tables |
| `surfaceSecondary` | `#F2EFE7` | Quiet grouped controls and skeleton tracks |
| `surfaceElevated` | `#063F3A` | Dark brand panels and high-emphasis surfaces |
| `primary` / `primaryPressed` | `#075D53` / `#044942` | CTA, selected navigation, pressed feedback |
| `primarySoft` | `#DDF0E9` | Selected/light primary state |
| `accentGold` / `accentGoldSoft` | `#C78A19` / `#FFF1CF` | Rating and trust emphasis only |
| `textOnSurface` / secondary | `#142420` / `#5A6863` | Light-surface foregrounds |
| `textPrimary` / secondary | `#FFFFFF` / `#CEE2DA` | Dark-surface foregrounds |
| `borderDefault` / strong | `#DFE3DC` / `#B9C5BD` | Quiet / high-definition boundary |
| `focus` | `#146EDE` | Keyboard focus indicator |
| `success`, `warning`, `danger`, `info` | `#1B7D4E`, `#B66B05`, `#C83C36`, `#236FBE` | Semantic operational status |

`emergency` uses the danger color but is reserved for genuine safety escalation. Status is always an icon plus a plain-language label; color is never its only signal. Gold never substitutes for a success or warning status.

## 3. Typography, icons, spacing, and motion

Use **Inter** as the primary UI typeface, falling back to system sans-serif until bundled font files are present. Use tabular figures for money, ratings, counts, and ETAs. A restrained serif display face may be used only for welcome/marketing entry surfaces; product workspaces use Inter for speed and legibility.

| Role | Size / line height | Weight | Use |
| --- | --- | --- | --- |
| Display | 36 / 44 | 700 | Welcome and rare marketing moment |
| Page heading | 28 / 36 | 700 | Screen title |
| Section heading | 20 / 28 | 700 | Major card/list group |
| Title | 16 / 24 | 600 | Card, provider, row title |
| Body | 14–16 / 20–24 | 400–500 | Description and field values |
| Label | 13–14 / 20 | 600 | Controls and status |
| Caption | 12 / 16 | 400–600 | Supporting metadata, never critical instruction |

Use Material Symbols Rounded as the shared icon family. Mobile targets are at least 48×48 logical pixels; desktop targets are at least 44×44px. Use the 4px spacing scale: `4, 8, 12, 16, 24, 32, 48`. Page padding is 16px on small phones, 20–24px on large phones/tablets, and 24–32px in desktop admin. Motion clarifies state, respects reduced motion, and never manufactures urgency or GPS precision.

## 4. Components and states

| Component | Contract |
| --- | --- |
| `FixButton` | One clear primary CTA per decision point; secondary, outline, destructive, loading, disabled variants |
| `FixTextField` / search | Label, helpful input mode, validation, error recovery, focus and disabled states |
| `FixCard` | Warm white surface, 12–16px radius, subtle border, restrained elevation; nested cards use a smaller radius |
| `FixStatusChip` | Icon + label + semantic tone, never color alone |
| `FixProviderCard` | Real identity, verification, rating/review count, availability/ETA, service fit, price type, one action |
| `FixServiceCard` | Real category/service content, concise scope, forward action |
| `FixNavigation` | Persistent role-specific destinations with selected state; never authorization |
| `FixPageFrame` | Responsive safe-area/gutter/sticky-action behavior |
| `FixStateView` | Loading skeleton, empty invitation, or error with retry/alternate action—no fabricated data |
| `FixBottomSheet` / dialog | Clear title, explicit close path, focus behavior, sticky action region where needed |
| `FixPriceDisplay` | Amount, currency, estimate/final state, fee composition and explanatory note |

Every component supports default, pressed/hover where applicable, focus, disabled, loading, error, text scaling, and reduced-motion behavior. Do not introduce one-off visual languages or hardcoded raw visual values in screen files.

## 5. Role-specific information architecture

### Customer mobile

Home follows: **confirmed location → greeting and search → AI Assistant → relevant categories → recommended services/providers → active booking**. An active booking becomes the first meaningful card.

The AI Assistant is a flagship entry with real **Text, Photo, and Voice** inputs. Results order: detected issue, recommended category, confidence/uncertainty, urgency and safety guidance, required skills, estimate range/type, then “find experts.” Preserve advisory wording from the real analysis; never promise a diagnosis, price, or availability the API did not provide.

Service/provider discovery makes verification, ETA/distance, experience/reviews, price type, availability, filters, and comparison legible. Booking preserves location, recurrence, cancellation rules, confirmation, payment, review/photo, invoice, support, chat, and calls. Tracking is map-first: status, provider identity, ETA, freshness, call/chat, support, and emergency stay visible. Stale/unavailable location is explicitly labeled and never animated as live.

### Provider mobile

Provider home is an operations workspace: availability first, incoming requests next, then active work, schedule, earnings/performance, and notifications. Incoming requests display only policy-permitted data before acceptance. The active-job cockpit prioritizes state, customer/service context, navigation/location-sharing consent, OTP, lifecycle controls, proof/completion, chat/call, cancellation and recovery.

Provider verification, service radius, skills, documents, availability, earnings, history, and profile retain their real workflows. The redesign must not expose customer data sooner than the permission model allows.

### Admin web

Admin is an enterprise workspace, not a consumer dashboard. It uses a collapsible labeled sidebar, responsive top/compact navigation, clear page header, role-filtered navigation, actionable queues, filter/search bars, semantic table statuses, compact metrics, and drill-down detail pages.

Existing routes are the source of truth: Overview, Users, Providers, Services, Bookings, Support/Complaints, Analytics, Trust, and Access. “Applications,” “Emergency/Dispatch,” “Reviews,” “Payments,” and “Settings” may appear only when a current authorized route and data contract exists; otherwise never use fake modules or metrics.

## 6. Safety, accessibility, and responsive behavior

- Meet WCAG 2.2 AA contrast, visible focus, semantic labels, keyboard support in admin, and screen-reader announcements for meaningful updates.
- Support small/large Android and iOS phones, tablets, text scaling, safe areas, portrait/required landscape, and desktop web input methods.
- Emergency views reduce choices, give safety-first guidance, contain no promotion, and state FixNow’s limits. Emergency red is never decorative.
- Loading, empty, offline, error, permission-denied, and unavailable states preserve user context and provide truthful recovery. No demo data or placeholder metrics in production UI.

## 7. Implementation rules

1. Do not change an API contract, authorization rule, business rule, or live data shape for visual convenience.
2. Retain authentication/email OTP, sessions, bookings, realtime/WebSockets, live location, service OTP, chat, calls, recurrence, reviews/photos, AI, emergency, payments/refunds/invoices, push, complaints, provider verification, earnings, and admin operations.
3. Migrate by flow: foundation; customer; provider; admin. Each phase leaves the product buildable and the migrated workflow testable.
4. Reuse or extend `mobile/lib/design_system/`; centralize equivalent admin tokens/components under `admin/src/`.
5. Before changing a screen, identify its real data source, permission gates, loading/error behavior, and navigation exits; preserve them during layout migration.
6. Test representative small/large mobile, provider active-job, and desktop admin states, plus behavioral regressions.

## 8. Avoid

No excessive gradients, glassmorphism, oversized rounded controls, cartoon illustration, generic AI-dashboard layouts, copied reference content, random colors, unlabelled icon-only actions, or decorative animation. Do not make an unavailable feature look live.
