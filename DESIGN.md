# FixNow Design System

`DESIGN.md` is the authoritative UI/UX design source for FixNow customer, provider, and admin experiences. It governs product hierarchy, visual tokens, reusable patterns, interaction behavior, accessibility, and design changes. Product requirements and safety policy remain authoritative for business and risk behavior; where they constrain a visual choice, the safer requirement wins.

This document specifies design intent only. It does not approve a UI framework, package, hosted service, screen implementation, or third-party asset.

## 1. Product Design Philosophy

FixNow combines **Uber-like immediacy + TaskRabbit-like provider trust + Urban Company-like service discovery**:

- Immediacy means location-aware entry, visible ETA, legible job state, strong actions, and a distraction-free active-service experience.
- Provider trust means professional profiles, verification context, ratings, completed-job evidence, skills, availability, and useful comparison.
- Service discovery means understandable categories, clear service details, transparent indicative pricing, and a short booking path.

These products are references for interaction principles, not templates. Do not reproduce their branding, layouts, copy, illustrations, icons, trade dress, or component geometry. FixNow must remain recognizable as an original, calm, blue-led service platform.

Design decisions follow this order:

1. Speed
2. Trust
3. Clarity
4. Safety
5. Location awareness
6. Fast decision making
7. Consistency

A person facing a leaking pipe or broken lock should understand the next action within seconds. Remove decoration or choice when it competes with that outcome.

## 2. Brand Personality

| Trait | UI expression |
| --- | --- |
| Fast | Short paths, immediate feedback, prefilled known data, visible ETA, and decisive primary actions. |
| Reliable | Stable layouts, persistent booking state, accurate status language, and explicit recovery paths. |
| Trustworthy | Verification context, transparent price/ETA, plain consent, honest uncertainty, and no dark patterns. |
| Calm | Neutral surfaces, restrained color, generous spacing, readable hierarchy, and motion that never creates urgency by itself. |
| Professional | Consistent typography, precise alignment, real service information, and minimal decorative effects. |
| Accessible | Strong contrast, scalable text, large targets, keyboard/screen-reader support, and redundant status cues. |
| Helpful | Contextual guidance, safety-first messages, useful empty states, and next actions that solve the immediate problem. |

The voice is direct, respectful, and reassuring. Never sound playful during risk, blame the user for errors, manufacture scarcity, or promise an outcome the platform cannot guarantee.

## 3. UX Principles

1. Give each screen one obvious primary action. Secondary actions must look secondary.
2. Make genuine emergency actions immediately findable without turning every screen red.
3. Keep price, fees, ETA, provider identity, and booking state visible when they affect a decision.
4. Minimize steps and fields in urgent flows; reuse verified information with user control.
5. Show progress with named stages, not indefinite animation alone.
6. Always communicate system state: loading, searching, saved, offline, delayed, failed, or completed.
7. Pair errors with recovery: retry, edit, choose another method, contact support, or safely exit.
8. Avoid asking for decisions the system can safely infer; explain consequential defaults.
9. Use plain, specific language. Prefer “Provider is 8 minutes away” over “Dispatch in progress.”
10. Show price composition and whether a figure is fixed, estimated, or subject to inspection.
11. Show ETA as an estimate and update it honestly.
12. Preserve the active booking across navigation, relaunch, and temporary network loss.
13. Never use color, map position, or iconography as the only carrier of critical meaning.
14. Do not place promotions in emergency, payment, or active-service critical paths.

## 4. Color System

Use three layers: primitive values, semantic roles, then component tokens. Application code consumes semantic or component tokens, never raw hex values. The following light theme is the proposed baseline and requires contrast validation in implementation.

### Light-mode semantic tokens

| Token | Value | Use |
| --- | --- | --- |
| `color.primary` | `#1565D8` | Main CTA, selected navigation, trusted interactive emphasis. |
| `color.primaryHover` | `#0F56BE` | Pointer hover only. |
| `color.primaryPressed` | `#0B469D` | Pressed/active feedback. |
| `color.primarySoft` | `#EAF2FD` | Selected rows, informational emphasis, subtle blue containers. |
| `color.onPrimary` | `#FFFFFF` | Content on primary fills. |
| `color.background` | `#F7F9FC` | Page/app background. |
| `color.surface` | `#FFFFFF` | Cards, sheets, dialogs, inputs. |
| `color.surfaceSecondary` | `#F0F3F8` | Grouped sections, muted controls, skeleton bases. |
| `color.textPrimary` | `#172033` | Headings and primary body text. |
| `color.textSecondary` | `#536078` | Supporting text and metadata. |
| `color.textDisabled` | `#8C96A8` | Disabled content; never use for required readable information. |
| `color.border` | `#D7DEE9` | Standard dividers and component borders. |
| `color.focus` | `#2F7DE1` | Focus rings with sufficient surrounding contrast. |
| `color.success` | `#168A52` | Success, available, completed. |
| `color.successSoft` | `#E7F6EE` | Success container. |
| `color.warning` | `#A96500` | Caution, delay, attention required. |
| `color.warningSoft` | `#FFF3D6` | Warning container. |
| `color.danger` | `#C93636` | Validation failure and destructive actions. |
| `color.dangerSoft` | `#FDECEC` | Error container. |
| `color.emergency` | `#A91F2C` | Genuine urgent escalation/SOS only. |
| `color.emergencySoft` | `#FBEAEC` | Emergency message container. |
| `color.info` | `#286FBE` | Neutral operational information. |
| `color.infoSoft` | `#EAF3FC` | Informational container. |
| `color.scrim` | `rgba(10, 18, 32, 0.48)` | Modal/sheet scrim. |

`danger` covers errors and destructive actions. `emergency` is a separately governed role for an immediate safety escalation; neither is decorative. Green means verified success or current availability, not merely “good-looking.” Amber means caution or waiting, never failure.

### Future dark mode

Dark mode must override semantic tokens, not components or screen-level colors. Start from deep neutral navy surfaces rather than pure black; keep primary blue, status colors, text, borders, map overlays, and scrims contrast-tested. Preserve the meanings above and test WCAG contrast, OLED smearing, map legibility, photographs, disabled states, and elevation boundaries before release. Dark mode is not approved merely by inverting light tokens.

## 5. Typography

Use **Inter** as the single primary family when implementation begins, with a platform-appropriate sans-serif fallback while it loads. Do not introduce a display or secondary font without an approved design-system change. Use tabular numerals for prices, ETA countdowns, and aligned financial data when supported.

| Token | Size | Weight | Line height | Use |
| --- | ---: | ---: | ---: | --- |
| `type.display` | 40px | 700 | 48px | Rare marketing or major admin overview statement; not routine mobile screens. |
| `type.heading1` | 32px | 700 | 40px | Top-level page heading. |
| `type.heading2` | 24px | 700 | 32px | Major section or sheet heading. |
| `type.heading3` | 20px | 600 | 28px | Card group or subsection heading. |
| `type.title` | 18px | 600 | 24px | Card/dialog title and prominent provider name. |
| `type.bodyLarge` | 18px | 400 | 28px | High-priority explanatory text. |
| `type.body` | 16px | 400 | 24px | Default body and input value. |
| `type.label` | 14px | 600 | 20px | Buttons, field labels, navigation, status labels. |
| `type.caption` | 12px | 500 | 16px | Supporting metadata; never critical instructions. |

Mobile body text remains 16px equivalent by default. Support platform text scaling without clipping, hiding actions, or replacing text with ellipses where the full value is needed. Use only tokenized sizes, weights, and line heights.

## 6. Spacing System

Use a 4px primitive grid and a restrained semantic scale:

| Token | Value | Typical use |
| --- | ---: | --- |
| `space.xs` | 4px | Tight icon/label adjustment. |
| `space.sm` | 8px | Related inline content. |
| `space.md` | 12px | Compact control groups. |
| `space.lg` | 16px | Default component gap and mobile page padding. |
| `space.xl` | 24px | Card padding and form groups. |
| `space.2xl` | 32px | Section separation. |
| `space.3xl` | 48px | Major page sections/desktop whitespace. |

Defaults:

- Mobile page horizontal padding: `space.lg` (16px); 20–24px is allowed on large phones through a page token.
- Tablet/desktop page gutters: 24–32px, governed by responsive layout tokens.
- Standard card padding: 16px mobile, 24px comfortable/desktop.
- Section spacing: 32px; tightly related subsections: 24px.
- Inline icon-to-label gap: 8px.
- Stacked form field gap: 16px; field label-to-control gap: 8px; form section gap: 24px.

Do not create intermediate values inside screens. Add a documented token only when repeated evidence shows the scale is insufficient.

## 7. Border Radius

| Token | Value | Components |
| --- | ---: | --- |
| `radius.small` | 6px | Small chips, compact controls, map tooltips. |
| `radius.medium` | 10px | Inputs, standard buttons, menu items. |
| `radius.card` | 14px | Cards and contained panels. |
| `radius.large` | 20px | Dialogs, prominent panels, bottom-sheet top corners. |
| `radius.pill` | 999px | Status chips, avatars, segmented controls; not general cards. |

Nested components should use a radius smaller than their container. Do not use rounded shapes to make dangerous actions feel playful.

## 8. Elevation and Shadows

Use borders and surface contrast before shadow. Shadows are functional depth cues, not decoration.

| Token | Shadow | Use |
| --- | --- | --- |
| `elevation.flat` | none | Default sections, tables, inline cards. |
| `elevation.card` | `0 1px 3px rgba(20,32,51,.10)` | Cards requiring separation from page background. |
| `elevation.floating` | `0 6px 18px rgba(20,32,51,.14)` | Map controls, floating CTA, sticky panel. |
| `elevation.modal` | `0 16px 40px rgba(20,32,51,.20)` | Dialog and modal sheet above a scrim. |

Avoid colored, glowing, oversized, or stacked decorative shadows.

## 9. Iconography

Use **Material Symbols Rounded** as the one canonical outlined/rounded icon family across mobile and admin. Platform adapters may package or render those same approved glyphs, but they must not substitute another icon family. Do not mix Material, Lucide, Font Awesome, emoji, and arbitrary SVGs in one product.

| Size | Use |
| ---: | --- |
| 16px | Dense admin metadata or inline status. |
| 20px | Inputs, compact controls, secondary actions. |
| 24px | Default mobile navigation and buttons. |
| 32px | Service/category icons. |
| 40–48px | Empty-state/emergency illustration icon only. |

Icons require accessible labels when meaning is not adjacent in text. Use filled/selected variants consistently. Never use emoji as production control icons.

## 10. Buttons

Default button height is 48px mobile and 40px compact admin; urgent/mobile primary actions may use 52px. Minimum interactive target is 48×48px mobile and 44×44 CSS px on desktop/touch-capable admin.

| Variant | Treatment | Use |
| --- | --- | --- |
| Primary | Primary fill, on-primary label | The one main action on a screen or sheet. |
| Secondary | Surface fill, primary text, border | Important alternative that must not compete. |
| Tertiary/Text | Transparent, primary text | Low-emphasis navigation or contextual action. |
| Destructive | Danger fill or outlined danger | Delete, cancel with consequence, irreversible action. |
| Emergency | Emergency fill, explicit icon and label | Genuine safety escalation only; not ordinary urgent booking. |
| Icon | Square/circle, tooltip/semantic label | Common compact action such as locate, close, call. |

All use `radius.medium`, horizontal padding 20px (16px compact), `type.label`, and an 8px icon gap. Prefer a leading icon; trailing icons indicate continuation or direction. Do not place icons on both sides without a functional reason.

Disabled buttons must remain identifiable, meet applicable contrast, and explain why when the reason is not obvious. Loading keeps width stable, blocks duplicate submission, shows a spinner plus an accessible busy label, and preserves the action text when space allows. Never use a disabled button as the only explanation for invalid input.

## 11. Input Fields

Inputs use a persistent external label, 48px minimum height, `radius.medium`, surface background, standard border, 16px value text, and inline helper/error area. Placeholder text is an example, not a label.

| Input | Requirements |
| --- | --- |
| Text | Clear label, input purpose/autofill metadata, length guidance if constrained. |
| Phone | Country context, forgiving formatting, normalized storage, numeric-appropriate keyboard. |
| Password | Show/hide control, password-manager support, requirements before failure. |
| OTP | One accessible logical field or correctly grouped cells, paste/autofill, expiry and resend status. |
| Select | Current value visible; native/accessibility-friendly behavior; search for long lists. |
| Search | Search icon, clear action, query persistence, results/loading/empty state. |
| Location | Location icon, current address, edit/confirm action, permission fallback, map/list alternative. |
| Multiline | Visible label, sensible minimum rows, character count when constrained, no fixed height that clips text. |

States:

- Default: border + surface + label.
- Focus: primary/focus border and 2px visible ring; keyboard focus never removed.
- Filled: retain label; value uses primary text.
- Disabled: muted surface and text plus semantic disabled state.
- Error: danger border, icon, and specific inline message associated with the control.
- Success: success icon/message only when confirmation is useful; do not turn every valid field green.

Validate at the helpful time: format feedback after sufficient input, required feedback after blur/submit, and server errors near the responsible field. Never expose backend exception text.

## 12. Cards

Use `FixCard` foundations: surface, optional border, `radius.card`, 16/24px padding, and `elevation.flat` or `elevation.card`. Whole-card tap behavior must be clear and must not conflict with nested actions.

### Service Card

Supports category icon, service name, one-line scope, indicative starting price/visit charge, availability hint, and optional popularity/recent marker. Examples include plumber, electrician, AC repair, locksmith, and mechanic. It must not imply that an estimate is a guaranteed final price.

### Provider Card

Supports provider photo/avatar, name, verification badge with explanation, rating and review count, completed jobs/experience, primary skill/category, distance, ETA, indicative price/visit charge, availability, and one clear CTA. Trust facts precede promotional copy. Missing data is stated honestly rather than represented as zero or hidden.

### Booking Card

Supports service, provider, icon+label status, ETA/date, transparent price state, and the primary next action. Active bookings visually outrank historical bookings; destructive cancellation never becomes the default CTA.

### Emergency Card

Uses emergency-soft background/border, compact safety copy, one immediate action, and one safe alternative/escalation. Exclude ratings, promotions, carousels, and unrelated details.

Screens may compose these patterns but must not invent replacement card styles without a system change.

## 13. Customer Navigation

Primary mobile navigation:

1. Home
2. Bookings
3. Help / Support
4. Profile

Service discovery lives primarily in Home. Use labels with icons, preserve navigation state, and indicate active booking persistently without adding a fifth destination. Contextual flows such as payment, tracking, provider selection, and emergency escalation sit above this navigation and do not become permanent tabs.

## 14. Provider Navigation

Provider mobile navigation:

1. Home / Jobs
2. Active Job
3. Earnings
4. Profile

Availability is a prominent, accessible toggle on Home/Jobs with explicit Online, Busy, and Offline meaning. It must show sync/progress/errors and must not imply availability when location or required verification is unavailable. Incoming jobs and an active job outrank earnings summaries.

## 15. Admin Navigation

Admin is desktop-first with a collapsible, labeled sidebar:

- Overview
- Customers
- Providers
- Verification
- Services
- Bookings
- Complaints
- Payments
- Analytics
- Settings

Use permission-aware visibility without treating hidden navigation as authorization. Preserve current section, provide breadcrumbs for depth, and use compact density without shrinking targets or text below accessibility thresholds. High-risk actions require role checks, reason capture where policy requires, and confirmation.

## 16. Customer Home Screen Rules

Prioritize in this order:

1. Confirmed/current location
2. Search or plain-language problem entry
3. Clearly bounded emergency action
4. Popular/recent services
5. Nearby available providers
6. Existing active booking, if present

An active booking becomes the dominant first-viewport card. Do not show every category, provider, promotion, and history item at once. The first viewport should answer “Where?”, “What help?”, and “What is happening now?”

## 17. Service Discovery

Use recognizable, consistent category icons; short labels; and logical household/vehicle/safety groupings. Lead with recent, popular, and context-relevant services, then expose the full catalog through search or “View all.” Avoid a 20+ item equal-priority grid. Category detail states what is included, excluded, expected, how pricing works, and what information improves matching.

## 18. Provider Discovery

Provider results emphasize verified identity context, rating plus review count, relevant completed jobs/experience, ETA, distance, indicative price, availability, and service fit. Explain sorting/filtering and distinguish sponsored placement if ever introduced. Do not rank purely by lowest price; reliability, relevance, arrival, verification, quality, and fair choice matter. Auto-match must explain its basis and allow an alternative when operationally possible.

## 19. Booking Flow

Standard lifecycle:

`Service Selection → Problem Details → Location → Provider Matching → Provider Selection / Auto Match → Booking Confirmation → Provider Acceptance → Live Tracking → Service In Progress → Completion → Payment → Rating`

Combine steps when it reduces work without hiding consequences. Persist entered details, allow review/edit before confirmation, show estimates and cancellation terms before commitment, and use a single progress model. Provider rejection/timeout, no provider, price change, location correction, payment failure, and cancellation each need an explicit recovery path.

## 20. Live Tracking

The active booking view prioritizes the map, provider/customer position, ETA, provider name/photo, vehicle information when operationally relevant, service type, call/chat, booking status, and support/emergency access. The bottom panel communicates the current state and next expected event.

Status progression:

`Searching → Provider Found → Provider Accepted → On The Way → Arriving → Arrived → Work Started → Work Completed`

Do not pretend GPS is exact, or show stale location as live. Communicate delayed updates and provide a refresh/recovery path. Remove promotions, unrelated service suggestions, and marketplace browsing during active tracking.

## 21. Maps

- Customer marker: stable person/location symbol with text alternative.
- Provider marker: directional provider symbol; selected state is visually and semantically distinct.
- Destination/service marker: distinct pin when different from customer position.
- Route line: primary blue with sufficient contrast against the approved map style; never encode status solely in route color.
- ETA card: surface overlay with ETA, status label, and last-updated/stale state where needed.
- Actions: locate me, recenter route, accessibility/list alternative; 48px targets.
- Bottom sheet: uses defined snap points and never permanently obscures the full route/context.

Reuse the same marker and overlay components. Respect safe areas and map attribution. Keep interactive controls away from system gestures and sheet handles.

## 22. Bottom Sheets

Bottom sheets serve provider details, booking confirmation, tracking details, service options, and location selection. Use 20px top corners, surface background, modal/floating elevation as appropriate, 24px horizontal padding (16px on very small screens), a centered 32×4px drag handle, `heading2`/`heading3` title hierarchy, and a sticky bottom CTA area above the safe inset.

Define collapsed, medium, and expanded states only when each has a clear purpose. Preserve map context, announce expansion to assistive technology, trap focus only for modal sheets, support keyboard dismissal where appropriate, and never rely on dragging as the only way to close or expand.

## 23. Emergency UX

Emergency experiences reduce cognitive load, state the immediate safe action, and offer the smallest viable choice set. They contain no ads, promotions, cross-sells, long forms, celebratory motion, or ambiguous dismiss controls.

Rules:

1. Use emergency red only for genuine urgent escalation and immediate danger messaging.
2. State what FixNow can and cannot do. FixNow does **not** replace official emergency services.
3. For gas leaks, fire, electrical danger, medical emergencies, violence, or other imminent risk, lead with safety-first instructions and appropriate local emergency-service escalation options before ordinary provider booking.
4. Do not make unsupported diagnosis claims. Use concise, reviewed language and localize emergency numbers/policy.
5. Keep cancel/back visible and confirm cancellation only when accidental exit creates material risk.
6. Confirm whether a request was sent, is still searching, was accepted, or failed; never imply help is coming without evidence.
7. Provide support escalation and accessible call alternatives.
8. Minimize data entry and reuse verified location/contact details with a visible correction path.

Emergency copy and routing require safety/legal review before production.

## 24. Status System

Every status uses label plus icon and, where useful, color. Status text is the authority.

| Status | Semantic role | Suggested icon |
| --- | --- | --- |
| Available | Success | check-circle |
| Busy | Warning | schedule |
| Offline | Neutral | cloud-off |
| Pending | Warning/neutral | hourglass |
| Accepted | Info | task-alt |
| En Route | Info | navigation |
| Arrived | Primary/success | location-on |
| In Progress | Primary | build/service icon |
| Completed | Success | check-circle |
| Cancelled | Neutral or danger when consequential | cancel |
| Failed | Danger | error |
| Refunded | Info/success based on settlement state | currency-exchange |

Status chips use `type.caption` or `type.label`, `radius.pill`, and semantic soft containers. Do not overload one label with multiple backend meanings; map technical states to a stable user vocabulary.

## 25. Loading States

- Use shape-matched skeletons for cards/lists after the first brief load threshold; avoid layout shift.
- Buttons use an inline spinner, stable width, accessible busy announcement, and duplicate-action prevention.
- Map searching shows a clear centered/overlay state while retaining usable map context.
- Provider matching shows named progress, expected uncertainty, cancel/help where appropriate, and timeout recovery.
- Payment processing uses a blocking transaction state, prevents resubmission, and explains that leaving may not cancel processing.

Never show a blank white screen. Indeterminate loading must not imply guaranteed progress.

## 26. Empty States

An empty state contains a relevant icon/illustration, plain title, one-sentence explanation, and useful primary action when available.

| State | Helpful action |
| --- | --- |
| No bookings yet | Find a service. |
| No providers nearby | Expand time/radius, try another category, or get notified; do not fabricate availability. |
| No reviews | Explain that this provider has no reviews yet; show other trust evidence. |
| No notifications | Return to Home or manage notification preferences. |
| No earnings | Explain the selected period and link to available jobs/status. |

Do not make normal new-user emptiness look like an error.

## 27. Error States

Reusable error components include an icon, clear title, short explanation, retry CTA, and alternate action where possible. Preserve entered data and critical booking context. Translate technical failures into safe user language while recording diagnostic identifiers privately. Never expose stack traces, raw backend errors, provider payloads, secrets, or personal data.

Use inline errors for local/field problems, contained errors for one panel, and full-page errors only when the page cannot function. For destructive/payment/booking ambiguity, state what may already have happened before asking the user to retry.

## 28. Offline State

Show a persistent offline banner/status as soon as loss is confirmed. Keep the last verified critical booking state visible, marked with its update time and “may be out of date.” Queue only operations explicitly designed to be safe and idempotent; otherwise explain that the action was not sent. On reconnection, reconcile server state before claiming success and announce meaningful changes. Provide call/support fallback when appropriate.

## 29. Toasts, Snackbars and Alerts

- Snackbar: brief, non-critical confirmation or reversible action; one optional action; no essential details.
- Inline message: validation, local warning, persistent guidance, or recoverable component error.
- Modal: blocking, high-consequence decision or information requiring acknowledgment; use sparingly.
- Confirmation dialog: destructive/irreversible action, material cancellation fee, or sensitive permission change.

Avoid modal spam and stacked transient messages. Success that is already obvious from the updated screen needs no toast. Destructive confirmation names the action and consequence; never use vague “Are you sure?” alone.

## 30. Motion and Animation

| Token | Duration | Use |
| --- | ---: | --- |
| `motion.fast` | 150ms | Press, hover, color, focus feedback. |
| `motion.standard` | 200ms | Small component/state transitions. |
| `motion.emphasis` | 250ms | Provider accepted or compact success transition. |
| `motion.container` | 300ms | Screen/sheet/dialog transition. |

Motion supports comprehension: button feedback, screen hierarchy, provider acceptance, interpolated map movement, loading, success confirmation, and bottom-sheet transitions. Map markers move smoothly only between trustworthy updates and must not suggest false precision. Respect reduced-motion preferences by removing nonessential movement and replacing spatial transitions with fades/state changes. No parallax, autoplay decoration, confetti in urgent flows, or animation that delays action.

## 31. Accessibility

- Meet WCAG 2.2 AA contrast: 4.5:1 normal text, 3:1 large text and meaningful UI boundaries/focus indicators.
- Use 48×48px mobile and at least 44×44px web touch targets.
- Provide semantic labels, roles, values, hints, reading order, and live-region announcements where needed.
- Support text scaling/reflow without clipping at platform accessibility sizes.
- Admin is fully keyboard operable with logical tab order, skip navigation, visible focus, and no keyboard traps.
- Pair color with icons, labels, patterns, or position.
- Errors identify the field, cause in plain language, and recovery; focus moves predictably after submit.
- Images have useful alternatives; decorative imagery is ignored by assistive technology.
- Map flows provide a list/text alternative for status and location information.
- Test screen reader, keyboard, contrast, zoom, reduced motion, orientation, and dynamic text before completion.

## 32. Responsive Rules

Mobile supports small Android devices (~320px logical width), standard/large Android phones, iPhones, landscape where required, and tablets where practical. Use constraints, safe areas, flexible stacks, wrapping, and scroll; avoid absolute positioning tied to one screen. Keep the primary CTA reachable without hiding critical content behind it.

Admin breakpoints are implementation tokens, not scattered media queries. Support laptop (from ~1024px), desktop (~1280–1599px), and large desktop (1600px+). Use a content maximum around 1440px for dashboards and 720–960px for reading/forms, while data tables may use the available viewport with controlled horizontal scrolling. Collapse side navigation rather than deleting access, and never convert dense tables into unreadable squeezed columns.

## 33. Design Tokens

Centralize three layers:

1. **Primitive:** raw blue/neutral/status scales, 4px spacing, type values, radii, shadows, durations.
2. **Semantic:** `primary`, `surface`, `textSecondary`, `danger`, `pagePadding`, `focus`, and other purpose roles.
3. **Component:** `button.primary.background`, `input.focus.border`, `providerCard.padding`, etc., referencing semantic tokens.

The Flutter design-system structure is:

```text
mobile/lib/design_system/
    app_colors.dart
    app_typography.dart
    app_spacing.dart
    app_radius.dart
    app_shadows.dart
    app_theme.dart
```

Future Next.js/admin uses equivalent centralized source files and CSS/custom-property or framework mappings. Token names should remain conceptually aligned across platforms even when language conventions differ. Never hardcode a random color, font, radius, motion duration, or spacing value in screen code when a token exists.

## 34. Reusable Components

Planned conceptual components:

- `FixButton`
- `FixTextField`
- `FixCard`
- `FixServiceCard`
- `FixProviderCard`
- `FixBookingCard`
- `FixStatusChip`
- `FixAvatar`
- `FixRating`
- `FixAppBar`
- `FixBottomNavigation`
- `FixBottomSheet`
- `FixDialog`
- `FixSnackbar`
- `FixLoader`
- `FixEmptyState`
- `FixErrorState`
- `FixEmergencyBanner`
- `FixLocationSelector`
- `FixPriceDisplay`
- `FixVerificationBadge`

Names are conceptual and must adapt to approved project conventions when implementation begins. Each component specification includes anatomy, variants, sizes, semantic tokens, default/hover/focus/pressed/disabled/loading/error states as applicable, responsive rules, accessibility contract, and tests. Reuse or extend a component before creating another with the same responsibility.

## 35. Design Agent Rules

Before implementing any UI, an agent must:

1. Read `AGENTS.md`.
2. Read `DESIGN.md`.
3. Inspect existing design tokens.
4. Inspect existing reusable components.
5. Reuse existing components before creating new ones.
6. Follow typography tokens.
7. Follow spacing tokens.
8. Follow semantic colors.
9. Implement required component states.
10. Preserve accessibility.
11. Maintain responsive behavior.
12. Compare the result with the approved design direction.

Agents must not:

- Invent colors without approval.
- Introduce fonts or arbitrary type values.
- Create another spacing/radius/elevation system.
- Create a one-screen button or card language.
- Duplicate components.
- Mix random icon libraries.
- Introduce neon, excessive gradient, gaming, glassmorphism, decorative animation, or cluttered dashboard styles.
- Redesign unrelated screens.
- copy Uber, TaskRabbit, or Urban Company branding or layouts.
- Change the global design system during a feature task without explicit approval.

## 36. Design Change Protocol

If the system is insufficient, do not silently work around it:

1. Document the proposed change and affected platforms/components.
2. Explain the user need and why existing tokens/components cannot satisfy it.
3. Update `DESIGN.md` only with specific approval or within an explicitly assigned design-system task.
4. Update centralized tokens and reusable components with migration/compatibility notes.
5. Update affected screens and tests after the foundation is approved.

A feature task must not redefine the global visual language. Hard-to-reverse framework, font, icon, or cross-platform token decisions may also require an ADR.

## 37. Customer vs Provider Consistency

Customer and provider surfaces share colors, typography, spacing, icons, buttons, inputs, statuses, cards, dialogs, loading, error, and accessibility behavior. Information hierarchy differs:

- Customer: finding help, provider trust, ETA, booking, payment, and support.
- Provider: availability, incoming jobs, navigation, service status, completion, earnings, and safety.

Role context may change labels and content density, not the visual grammar.

## 38. Admin Consistency

Admin uses denser desktop layouts while retaining brand colors, Inter typography, semantic statuses, 4/8px spacing philosophy, radii, focus behavior, form rules, and component states. Dense does not mean cramped: tables keep readable rows, actions remain discoverable, and mobile-only patterns such as bottom navigation are translated to suitable desktop patterns rather than copied literally.

## 39. Do / Don't Examples

| Do | Don't |
| --- | --- |
| Present one strong primary CTA. | Present three competing primary buttons. |
| Show price type, fees, and ETA clearly. | Hide fees or imply estimates are guaranteed. |
| Reuse `FixProviderCard`. | Invent a provider card for every result page. |
| Use semantic status tokens plus icon and label. | Communicate status with color alone. |
| Show a shape-matched skeleton while loading. | Show a blank white screen or fake content. |
| Provide retry and an alternate action after network failure. | Display a raw exception or dead-end error. |
| Reserve red for danger, destruction, and true emergency. | Use red as a decorative brand/accent color. |
| Keep promotions out of emergency and active-service views. | Put promotional banners in emergency flow. |
| Use Inter and tokenized type styles consistently. | Use different fonts or arbitrary sizes between screens. |
| Use page/card spacing tokens. | Hardcode arbitrary padding to make one screenshot fit. |
| Communicate stale map/location data. | Animate stale coordinates as if they are live. |

## 40. Inspiration Reference

**Uber:** Use for interaction inspiration around real-time dispatch, maps, ETA, and active-job tracking.

**TaskRabbit:** Use for marketplace/provider profile and trust-information inspiration.

**Urban Company:** Use for home-service discovery, categorization, service information, and booking inspiration.

These references are inspiration only. FixNow must maintain its own original branding, layouts, components, content, and design identity. Do not download or copy their assets, reproduce their screens, or create trademark-confusing visual similarities.
