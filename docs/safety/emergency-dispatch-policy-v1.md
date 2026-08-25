# Emergency dispatch policy (v1)

## Status, scope, and authority

This document is the **FN-063 legal/product gate artifact** required by `PROJECT_TASKS.md` and closes open product decision **OD-011** (*definition and scope of "emergency," public-service guidance, provider qualification, and escalation*). It proposes normative rules for FixNow's emergency request and priority-dispatch capability. It does not authorize production launch by itself: the owner's recorded approval of this document, plus the release gates in §11, are required first.

Authority chain: implements the emergency journey in [`docs/product/requirements.md`](../product/requirements.md) (steps 83–91, FR-EMG-001…005), the permission-matrix emergency rows, and the AI governance safety taxonomy ([ADR-0014](../architecture/decisions/0014-adopt-advisory-ai-governance.md)). It binds FN-063, FN-064, and the FN-062 emergency notification remainder.

**Approval record:** see §12. Until signed there, implementation code may be written behind disabled-by-default flags but must not ship enabled.

---

## 1. Non-negotiable boundaries

1. FixNow priority dispatch is **not** a public emergency service. It never replaces, represents, or relays to police, fire, medical, or ambulance services.
2. FixNow never promises response times, arrival windows, or successful resolution of an emergency.
3. Priority applies **inside the FixNow verified-provider network only**.
4. Provider qualification rules are never bypassed: an emergency offer goes only to admins-flagged-category-skilled, account-active, online, in-radius providers — the same eligibility gates as ordinary matching (FN-040).
5. Every customer-facing surface that offers emergency dispatch must simultaneously show public-emergency guidance.

## 2. Definition and launch scope

**Emergency (launch definition):** an active safety hazard inside a home that falls within an admin-designated emergency service category, currently limited to:

| Hazard | Example category |
| --- | --- |
| Gas leak / smell of gas | Gas safety |
| Major water leak or flooding | Emergency plumbing |
| Exposed live wiring / electrical burning smell | Emergency electrical |
| Active fire risk (not an active fire) | Fire-risk mitigation |

Explicitly out of scope at launch: medical emergencies, personal-safety/attack situations, crime in progress, active fires, any situation where the customer is advised to contact public emergency services *first*. The app shows that guidance on every emergency entry point.

Adding or removing categories from this table is an admin action (`is_emergency` flag) recorded through normal category management and audited.

## 3. Customer journey and mandatory copy

Journey (from product requirements, now concretized):

1. **Entry** — emergency card on Home (only if ≥1 active emergency category exists). Fixed notice text (v1, non-editable by callers):
   > "FixNow priority dispatch alerts nearby verified professionals for these home hazards. **It is not an emergency service. If anyone is in danger, call your local emergency number first.**"
2. **Deliberate confirmation** — two-step creation (category+details screen → explicit confirm). No auto-create, no time-pressured defaults; accessible without relying on color/motion only (NFR-ACC-003).
3. **Dispatch progress reported honestly** — customer sees wave progression ("alerting more professionals nearby") and assigned-provider state via the ordinary tracking surfaces.
4. **Fallback** — §7 outcomes; a false success state is prohibited.
5. **Cancellation** — allowed while unassigned or safe per normal cancellation rules; all transitions audited.

## 4. Lifecycle and data model

An emergency is an ordinary **Booking** whose category is `is_emergency`, plus one sidecar row. No duplicate lifecycle exists.

```
emergency_dispatches (reversible migration)
  booking_id        uuid PK/FK → bookings, unique
  current_wave      smallint NOT NULL DEFAULT 0     -- 0..3
  last_escalated_at timestamptz NULL
  wave_history      jsonb NOT NULL DEFAULT '[]'     -- [{wave, at, eligibleCount}]
  created_at / updated_at
```

- `Booking.is_emergency` remains **derived** from the category at creation time; never stored, never editable after creation.
- Dispatch rows are created atomically with the booking in one transaction and are immutable except for wave fields.
- New permissions (permission matrix): `emergency.create.self` (customer, deliberate confirmation); `emergency.dispatch.manage` (`operations_administrator`, `trust_safety_reviewer`).

## 5. Priority dispatch and escalation ladder

Waves are driven by a bounded interval scanner (same pattern as FN-062 reminders). All constants live in one versioned `EMERGENCY_POLICY_V1` block, pinned by tests:

| Constant | Value | Meaning |
| --- | --- | --- |
| `fanOutCap` | 50 | Max providers pushed per wave |
| `wave2AfterMinutes` | 3 | Re-push + widen radius ×2 |
| `wave3AfterMinutes` | 8 | Ops alert + customer fallback state |
| `radiusMultiplier.wave2` | 2 | Wave-2 radius widening |
| `dailyCustomerCap` | 3 | Abuse control (§6) |

Behaviour:

- **Wave 1 (t=0):** high-priority, sound-on push to *all* eligible providers within radius (cap 50), bypassing quiet hours. Eligibility = FN-040 gates unchanged.
- **Wave 2 (t≈3 min, still unassigned):** re-push same pool + providers within doubled radius.
- **Wave 3 (t≈8 min, still unassigned):** ops administrators receive dashboard + push alert; the customer's emergency screen switches to the approved fallback state (§7).
- The moment any acceptance wins the CAS race (FN-041 unchanged), escalation stops permanently for that booking; later waves are no-ops even if scheduled late.
- Escalation failures never fail the booking; they are recorded and retried next tick.

## 6. Abuse controls

Applied at creation, before any dispatch:

1. Maximum **1 active** emergency per customer.
2. Minimum **30-minute cooldown** between an emergency's creation and the customer's next emergency.
3. Maximum **3 emergencies per rolling 24 hours** per customer.
4. Every creation writes an immutable audit event (actor, category, coarse outcome only — no precise coordinates in audit payloads).
5. Patterns (≥3 emergencies/7 days, or admin-flagged false alarms) raise a HIGH-severity `customer-emergency-frequency-v1` trust signal into the existing human review queue (FN-055/FN-060 infrastructure).

Genuine repeat users experience at most a brief confirm screen — limits never hard-block a customer mid-hazard without human review having occurred.

## 7. Fallback outcomes (FR-EMG-004)

| Outcome | Customer sees (approved copy family) |
| --- | --- |
| No provider accepted by wave 3 | "No professional is available right now. If this is dangerous, call your local emergency services. You can keep waiting or cancel." Cancel always available. |
| Notification failure | Realtime projection remains authoritative; push marked FAILED in delivery records; no customer-visible error beyond normal progress states. |
| Offline customer | Last known state labelled with timestamp; never faked freshness. |
| Assigned provider cancels | Normal cancellation flow + immediate re-entry into wave 1 (fresh dispatch row reset). |

## 8. Notification overrides unlocked (FN-062 remainder)

Upon approval: dedicated lock-screen-safe emergency templates ("Emergency request near you — open FixNow"), Android high-priority channel, and quiet-hour override **for emergency dispatch pushes only**, exactly per §5. No other notification class gains override rights.

## 9. Admin oversight

- Emergencies appear in the existing bookings workspace flagged `EMERGENCY`, filterable.
- Ops can force-cancel with reason via existing intervention flow (audited).
- Dispatch wave history is readable by `trust_safety_reviewer` / `operations_administrator` for post-incident review.
- Enhanced audit on every emergency read/write touching location (permission matrix row: restricted projection, minimum precision).

## 10. Privacy and data minimization

Precise location follows FN-044 rules (consent-gated, ephemeral ≤60 s during EN_ROUTE). Audit payloads carry coarse outcomes only. Emergency requests inherit standard retention until a retention schedule is separately approved; export requires the exceptional-purpose permission row already defined in the matrix.

## 11. Testing and release gates

Required before enabled rollout (mirrors acceptance criteria):

- [ ] Priority: wave timing, radius widening, cap behaviour, stop-on-accept.
- [ ] Abuse: active-limit, cooldown, daily cap, trust-signal raising — each unit + integration tested.
- [ ] No-match: wave-3 fallback copy and states.
- [ ] Concurrency: acceptance race unchanged under simultaneous waves.
- [ ] Authorization: matrix rows enforced end-to-end; cross-role denials tested.
- [ ] Audit: immutable events for create/wave/assign/cancel/fallback.
- [ ] Policy constants pinned by eval-style test (drift fails build).
- [ ] FN-062 emergency templates + quiet-hour override covered.

Rollout: disabled by default; internal synthetic testing; staff pilot; then enablement by config flip owned by product.

## 12. Approval record

| Role | Name/Agent | Decision | Date |
| --- | --- | --- | --- |
| Product owner (Arman2337) | — | ☐ Approved ☐ Rejected ☐ Changes requested | — |
| Legal review | — | ☐ N/A for internal pilot ☐ Approved | — |
| Safety/operations review | — | ☐ Approved | — |

> Signing (or written equivalent in chat) of this table by the owner constitutes the OD-011 decision record and lifts the FN-063 gate.
