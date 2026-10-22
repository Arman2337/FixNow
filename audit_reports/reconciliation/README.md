# Reconciliation evidence — 2026-10-21

Read [Current Reconciliation](../FIXNOW_CURRENT_RECONCILIATION.md) first. It and `current-findings.json` are the consolidated dispositions after review, conflict resolution and current validation.

The `*-findings.json` files are domain review notes. They retain intermediate classifications and pre-banner historical report line numbers. Where they differ, the consolidated register takes precedence. They are not three additional audits or three independent bug counts.

- `historical-claims.json` indexes every GAP/DIA reference in the nine original reports using original historical line numbers.
- `source-manifest.json` contains SHA-256 hashes of 137 referenced application, test and configuration files. It does not read environment secret files or describe live deployments.
- `validation.json` records actual check results and limitations. The Flutter log, when present, is a current local run, not a device result.
- `*-static-scan.json` are heuristic scanner results requiring source interpretation. Zero matches do not establish clean data integrity.
- `build_reconciliation.py` regenerates the report and nine appendices from reviewed notes and validation. Run from the repository root with `python audit_reports/reconciliation/build_reconciliation.py`. It refuses to regenerate if referenced source has drifted; a new source review is required first. Regeneration is not itself a fresh audit or test execution.

Application code and live database contents were not modified. Existing uncommitted user work was included in the reviewed snapshot and preserved. No dependencies or plugins were installed.
