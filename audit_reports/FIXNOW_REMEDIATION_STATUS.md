# FixNow — FN-146 Remediation Status

Updated 2026-10-22 (Asia/Calcutta). This document is the remediation overlay for the frozen [FN-145 reconciliation](FIXNOW_CURRENT_RECONCILIATION.md). It records what the FN-146 working tree changes do without rewriting the source review, its hashes, or its historical dispositions.

**State:** implementation and required local validation are complete. These are local working-tree results; nothing in this report means the changes are deployed to production.

The machine-readable companion, [fn146-remediation.json](reconciliation/fn146-remediation.json), contains an entry for all 109 rows in the reconciliation register. Fixed rows are carried forward, aliases point to their canonical outcomes, unsupported claims remain report corrections, and undefined IDs remain explicitly non-findings.

## Remediation outcome

| Area | FN-146 outcome | Evidence boundary |
|---|---|---|
| Authorization and transactions | Platform-only general complaints are supported without weakening booking participant checks. Guarantee transitions use one shared table, assignment is restricted to re-service, and updates use optimistic version comparison. Concurrent chat replay recovers the sender's unique-key collision without duplicate publish. | Local source and tests; production traffic not exercised. |
| Database integrity | A forward migration adds guarantee versioning and the remaining indexed foreign keys as `NOT VALID`. Empty-database probes create fixtures and roll back. Duplicate historical migration timestamps are preserved and guarded rather than renamed. | Applied only to a disposable loopback PostgreSQL cluster. Production migration rollout, validation and orphan cleanup were not executed. |
| Admin completeness | Support/trust filtering occurs before pagination; guarantees and catalog queries are bounded; global search reaches backend queries. Role, proxy, status and later-page regressions were added. | Local unit, type, lint, build and browser checks passed. Browser tests use the actual Next app with a local stub API. |
| Mobile persistence | Notification delete/clear waits for server success and preserves state on failure. Push enrollment validates HTTP results and permission/registration readiness. Saved-address production setup fails fast rather than silently using a no-op transport. | Static analysis, the full Flutter suite and crawler passed locally; no live FCM or physical-device persistence claim. |
| Honest UI and data | Fake VIP/cashback, tax registration defaults, cancellation/refund fees, escrow schedules and payout promises were removed. Missing tax configuration produces a Payment Receipt. Hidden third-party reverse geocoding was removed. | Real statutory identity and approved business policy remain external inputs. |
| Calling | All supported call entry points open one shared screen and launch the authorized phone number through the device phone app, with visible failure handling. | In-app VoIP media capture/playback is not implemented. Signaling endpoints alone are not described as a working audio stack. |
| Maintenance | Broken arbitrary extra-charge UI was removed in favor of the server-priced catalog item flow. Unreachable design/voice prototypes moved to test support, rewrite scripts were removed, and shared lifecycle/role/format helpers replaced duplication. | Source cleanup preserves prototype tests; tree-shaken binary size was not measured. |

## Canonical findings changed by FN-146

- Transactional and authorization: GAP-07, GAP-12, GAP-15, GAP-16, DIA-002 and DIA-006.
- Query completeness and tests: GAP-23, GAP-81, GAP-84–88 and DIA-004.
- Mobile behavior and honest presentation: GAP-32, GAP-42, GAP-43, GAP-45, GAP-48, GAP-51, DIA-001 and DIA-005.
- Maintenance and shared contracts: GAP-09, GAP-53, GAP-71, GAP-72, GAP-75, GAP-79 and GAP-89.
- Policy rows: cancellation and escrow copy were corrected without inventing rules. Provider reverification remains an explicit policy decision, not a silently fabricated code requirement.

Duplicate aliases, including GAP-40, GAP-56, GAP-58, GAP-59, GAP-67, GAP-68, GAP-78, GAP-80 and the five conflicting report-ID variants, inherit their canonical outcomes. GAP-31, GAP-33, GAP-37 and GAP-60–66 remain undefined historical IDs rather than application bugs. Unsupported report claims remain corrected in the machine register.

## Completed local validation

- Mobile: `flutter analyze` reported no issues; the full Flutter run passed 95 suites / 745 tests, including the 56 / 56 interaction crawler cases.
- Backend: 124 suites / 1,051 unit tests passed. Full TypeScript checking, production build, body-DTO guard and environment-declaration guard passed. ESLint reported zero errors and 39 pre-existing warnings.
- Isolated PostgreSQL: all 41 migrations applied; the schema gate passed 67 / 67 checks; the existing integration suite passed 14 suites / 100 tests; the new domain-reconciliation suite passed 1 suite / 5 tests. The owned scratch cluster was stopped afterward.
- Admin: 18 files / 50 tests, type-check, lint and production build passed.
- Admin browser: Playwright passed 18 / 18 against the actual Next app with a local stub API.
- Secret scanner: self-test passed 11 / 11 and the bounded scan was clean across 1,557 available history blobs and 6,013 untracked-not-ignored files. The clone lacked 5,251 Git objects and skipped five files larger than 1 MiB, so this is not a complete-history assertion.

## Release and verification boundary

FN-146 changes are local working-tree changes. Completed local checks do not establish production deployment or external-provider readiness. These limitations remain:

- No production database migration, constraint validation, orphan cleanup or production-data inspection was performed.
- No live FCM, S3 or ClamAV service was contacted.
- No physical-device phone call or push-delivery run was performed.
- In-app VoIP audio is a future capability; the implemented behavior is a system-phone fallback.
- A real GSTIN, legal address, SAC and verification URL must be supplied by deployment configuration to issue a tax invoice.
- No authoritative 365-day provider reverification requirement was available. Product/legal ownership must decide it before code or scheduling is added.

The secret scan remains bounded by the clone's missing Git objects and large-file exclusions. Production readiness must not be inferred from local source and test results alone.

