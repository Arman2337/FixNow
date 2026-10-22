"""Rebuild the documentation-only reconciliation from reviewed local evidence.

Run from the repository root. Reads source files; writes only audit_reports/.
No databases, network requests, dependencies, application edits or test execution.
"""
from pathlib import Path
from collections import Counter
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'audit_reports'
DATA = OUT / 'reconciliation'
DATE = '2026-10-21'
HEAD = 'a45d9c5'
# Regenerate only the reviewed snapshot; changed source requires a new review.
if (DATA / 'source-manifest.json').exists():
    previous_manifest = json.loads((DATA / 'source-manifest.json').read_text(encoding='utf-8'))
    drift = [e['path'] for e in previous_manifest if not (ROOT / e['path']).is_file() or hashlib.sha256((ROOT / e['path']).read_bytes()).hexdigest() != e['sha256']]
    if drift:
        raise SystemExit('Source changed since review; re-review before regeneration: ' + ', '.join(drift))
REPORTS = sorted(p for p in OUT.glob('*.md') if p.name != 'FIXNOW_CURRENT_RECONCILIATION.md')
START = '<!-- CURRENT-RECONCILIATION-START -->'
END = '<!-- CURRENT-RECONCILIATION-END -->'
APPENDIX = '\n<!-- RECONCILIATION-APPENDIX -->'

def read_json(name):
    return json.loads((DATA / name).read_text(encoding='utf-8-sig'))

def clean_historical(text):
    text = re.sub(re.escape(START) + r'.*?' + re.escape(END) + r'\n*', '', text, flags=re.S)
    return text.split(APPENDIX)[0].rstrip() + '\n'

def ev(path, line):
    return {'path': path, 'line': line}

historical = {p.name: clean_historical(p.read_text(encoding='utf-8-sig')) for p in REPORTS}
source_index = []
for name, text in historical.items():
    for number, line in enumerate(text.splitlines(), 1):
        ids = sorted(set(re.findall(r'\b(?:GAP-\d+|DIA-\d+)\b', line)))
        if ids:
            source_index.append({'report': name, 'historical_line': number, 'ids': ids, 'text': line})

rows = {}
# Prefer the domain owner on shared claims: admin follows backend for UI contracts.
for filename in ['backend-findings.json', 'admin-findings.json', 'mobile-findings.json']:
    for record in read_json(filename)['findings']:
        rows[record['id']] = dict(record)

# Normalize the same cross-report ID collision to a single, explicit variant.
for alias, canonical in {
    'GAP-18:api-inventory': 'GAP-18/API-pagination',
    'GAP-25:database-inventory': 'GAP-25/DB-audit-cascade',
    'GAP-89/backend-test-harness': 'GAP-89',
}.items():
    rows.pop(alias, None)

rows['GAP-01'].update(status='fixed', current='Historical allowlist remediation remains. Scanner self-test passes all 11 rules. Current full invocation exits 0, reporting 1,557 available history blobs, 37 untracked-not-ignored files, 5,251 unavailable Git objects and 3 files over 1 MiB skipped. This is a bounded local result, not a clean complete-history or current CI claim.')
rows['GAP-25/DB-audit-cascade'].update(status='duplicate', current='Database inventory uses GAP-25 for canonical GAP-10. Later migration implements SET NULL; deployment and live constraints were not checked.')
rows['GAP-18/API-pagination'].update(status='fixed', current='This API-inventory use of GAP-18 concerns pagination, not analytics access. Complaint and trust queries now accept bounded limit/offset. Filtering remains separately open under DIA-004; complaint status DTO is not consumed by the management query.')
rows['GAP-43'].update(status='partial', current='Original no-backend/local-only assertion is fixed: owned DELETE endpoints and real requests exist. The repository still marks items deleted locally before an unawaited request, ignores token errors, and does not validate response success or roll back the local dismissal. Successful persistence and reload behavior were not established by a live test.')
rows['GAP-32'].update(status='review_required', current='Precise coordinates are sent to BigDataCloud by the current reverse-geocoding implementation. This is an integration/privacy review item; the historical reports do not establish an approved policy violation. No external request or legal conclusion was made in this reconciliation.')
rows['GAP-42']['current'] = 'UI/PDF use shared compile-time configuration, removing duplicated conflicting addresses. The default GSTIN and verification URL remain placeholders with no production-specific required override check in AppEnvironment. Production configuration and URL availability were not inspected; the old specific 404 claim is unverified.'
rows['GAP-88'] = {'id': 'GAP-88', 'status': 'unverified', 'claim': 'E2E suite was unexecuted because browser binaries were missing.', 'current': 'Existing Playwright journeys target the real admin app with a local stub API. Trust role test is active, not fixme. The e2e dependency directory is absent in this checkout; no dependencies/browsers were installed and no current browser run is claimed. Historical browser-unavailability diagnosis is not a current runtime result.', 'evidence': [ev('e2e/playwright.config.ts', 68), ev('e2e/tests/admin-operations.spec.ts', 148), ev('e2e/package.json', 1)]}

for i in [31, 33, 37, 60, 61, 62, 63, 64, 65, 66]:
    rows[f'GAP-{i:02}'].update(status='undefined', current='No definition or reference exists in the nine historical reports. This is a missing report ID, not a verified application defect.')

rows['REPORT-counts-and-confidence'] = {
    'id': 'REPORT-counts-and-confidence', 'status': 'unsupported',
    'claim': '89 verified distinct gaps, 82% integrity, 36 PASS / 5 WARN / 4 FAIL, and feature completion percentages are established measurements.',
    'current': 'The gaps register references 74 distinct GAP IDs; the nine reports together reference 79. Ten IDs in 1–89 are absent. The 45-row integrity matrix actually has 34 PASS / 6 WARN / 5 FAIL. No scoring formula or reproducible feature-status denominator supports 82% or the summary percentages. Historical reported test counts are not current execution evidence. Source facts here use HIGH confidence; no live DB/device/HTTP persistence verification is claimed.',
    'evidence': [ev('audit_reports/data_integrity_audit_report.md', 19), ev('audit_reports/FIXNOW_AUDIT_SUMMARY.md', 40)]
}

labels = {'fixed': 'FIXED_IN_SOURCE', 'partial': 'PARTIAL', 'open': 'OPEN', 'unsupported': 'UNSUPPORTED', 'unverified': 'UNVERIFIED', 'duplicate': 'DUPLICATE', 'undefined': 'UNDEFINED_ID', 'review_required': 'REVIEW_REQUIRED'}
expected = {f'GAP-{i:02}' for i in range(1, 90)} | {f'DIA-{i:03}' for i in range(1, 7)}
assert expected <= rows.keys(), sorted(expected - rows.keys())
actual_gap_ids = set(re.findall(r'\bGAP-\d+\b', '\n'.join(historical.values())))
undefined = [f'GAP-{i:02}' for i in range(1, 90) if f'GAP-{i:02}' not in actual_gap_ids]
assert len(actual_gap_ids) == 79, len(actual_gap_ids)

def sort_key(item):
    key = item['id']
    if re.fullmatch(r'GAP-\d+', key): return (0, int(key[4:]), key)
    if key.startswith('GAP-'): return (1, 0, key)
    if key.startswith('DIA-'): return (2, 0, key)
    return (3, 0, key)

ordered = sorted(rows.values(), key=sort_key)
for record in ordered:
    record['status_label'] = labels[record['status']]
    record['confidence'] = 'HIGH (source)' if record['status'] in ('open', 'fixed', 'partial') else 'See disposition; no live verification'
    # Raw review ledgers refer to the original report lines. The banner adds four.
    for evidence in record['evidence']:
        if evidence['path'].startswith('audit_reports/') and Path(evidence['path']).name in historical:
            evidence['line'] += 4

def esc(value):
    return str(value).replace('|', '\\|').replace('\n', ' ')

def links(record, prefix=''):
    return '; '.join(f"[{e['path']}:{e['line']}]({prefix}{e['path']}#L{e['line']})" for e in record['evidence'])

def table(items, prefix=''):
    lines = ['| ID | Current disposition | Original claim / current evidence | Source references |', '|---|---|---|---|']
    for f in items:
        lines.append(f"| {esc(f['id'])} | **{f['status_label']}** | {esc(f['claim'])}<br>**Current:** {esc(f['current'])} | {links(f, prefix)} |")
    return '\n'.join(lines)

counts = Counter(r['status_label'] for r in ordered if re.fullmatch(r'GAP-\d+', r['id']))
checks = read_json('validation.json')
summary = f'''# FixNow — Current Bug and Gap Reconciliation

Reconciled {DATE}, Asia/Calcutta. Baseline: commit `{HEAD}`, existing `feat/system-audit-and-ui-fixes` branch, plus the pre-existing working-tree change to `mobile/lib/features/provider/provider_controller.dart`. This is a reconciliation of historical claims, not a new production audit or an implementation of the remaining fixes.

All nine historical reports were reviewed. The source register covers **89 numbered GAP slots**, **6 DIA findings**, the conflicting uses of GAP IDs, unresolved policy questions, and unsupported integration/report claims. Only **79 GAP IDs actually occur** in the historical reports; the other ten slots are explicitly undefined. Duplicates and variants must not be summed as unique bugs.

## Dispositions and evidence limits

- `FIXED_IN_SOURCE`: the reported condition has changed or the source remediation exists. This does not certify deployed migrations, device behavior, provider availability, or full production readiness.
- `OPEN` / `PARTIAL`: a current source gap remains; partial records state which historical assertions are fixed or wrong.
- `UNSUPPORTED`: evidence does not support the original bug, security, runtime or integration claim. This is not proof of overall safety.
- `UNVERIFIED` / `REVIEW_REQUIRED`: runtime evidence or an adopted product/privacy requirement is still needed.
- `DUPLICATE` / `UNDEFINED_ID`: aliases or missing report definitions, not additional defects.

| Numbered GAP slot disposition | Count |
|---|---:|
''' + '\n'.join(f'| {k} | {v} |' for k, v in sorted(counts.items())) + f'''
| **Total numbered slots** | **89** |

Undefined historical IDs: {', '.join(undefined)}.

Source references identify current repository files and one-based lines. The machine-readable [register](reconciliation/current-findings.json) includes every disposition; [historical claim index](reconciliation/historical-claims.json) preserves each original GAP/DIA reference and its original report line. Historical sections in the nine original reports are retained and explicitly superseded. The [source manifest](reconciliation/source-manifest.json) records hashes of referenced application files so future drift can be detected.

## Remaining work, in practical order

1. **Extra charges — DIA-001:** align UI/repository payload with the server-priced sub-service DTO and required `expectedVersion`. The missing-`toJson()` runtime crash claim is false; do not implement the old proposed patch blindly.
2. **Complaint entry points — DIA-002:** reconcile general/platform complaints with booking-required authorization. Choose an authorized support flow or a properly scoped backend capability; do not remove relationship checks as a shortcut.
3. **Calling — GAP-51 / DIA-003:** connect the call UI and full session lifecycle. A repository constructor or successful session creation does not establish a working audio connection.
4. **Guarantees — GAP-07 / DIA-006:** enforce transitions on the backend as well as the corrected UI, and align client minimum-length validation.
5. **Admin queues/search — GAP-23 / DIA-004:** filter before pagination; support continuation/search across all claims and complaints; bound the admin catalog query. Current slice-local counts are not global queue totals.
6. **Honest presentation/persistence — DIA-005 / GAP-42 / GAP-43 / GAP-45 / GAP-48:** remove unsupported VIP benefits, require real statutory configuration, handle notification delete failures, persist or remove local-only push switches, and resolve cancellation/settlement copy against approved behavior.
7. **Data/test follow-up — GAP-09 / GAP-12 / GAP-15 / GAP-16 / GAP-71 / GAP-81 / GAP-84–88:** verify deployed constraints and concurrency on an isolated DB, close schema-probe skips and relevant coverage gaps, and review existing migration timestamps without casually renaming applied migrations.
8. **Maintenance/review — GAP-32 / GAP-53 / GAP-72 / GAP-75 / GAP-79 / GAP-89:** review geocoding privacy, remaining unreachable source files, duplicated helpers and developer scripts. Source presence alone does not prove inclusion in a release binary.

## Current verification

''' + '\n'.join(f"- **{c['name']} — {c['result']}** {c['details']}" for c in checks['checks']) + '''

The Data Integrity Audit skill, its local static scanner, source/import tracing, specialized parallel reviewers, existing Jest/Vitest tests and the repository secret scanner contributed. The static scanner found zero mobile/admin heuristic matches and two backend matches: an audio fixture declaration and a best-effort post-save notification catch. Neither demonstrates failed message persistence or production mock data. Regex scans are supporting evidence, not comprehensive coverage.

No live database, authenticated browser, external provider or device persistence run was performed. Database schema scripts and integration fixtures can mutate data, so they were not executed during this documentation-only reconciliation. No health score or percentage of production readiness is asserted.

## Complete numbered GAP register

''' + table([f for f in ordered if re.fullmatch(r'GAP-\d+', f['id'])], '../') + '''

## Conflicting identifiers, DIA findings, policy and report corrections

''' + table([f for f in ordered if not re.fullmatch(r'GAP-\d+', f['id'])], '../') + '\n'

(OUT / 'FIXNOW_CURRENT_RECONCILIATION.md').write_text(summary, encoding='utf-8')
(DATA / 'current-findings.json').write_text(json.dumps({'date': DATE, 'head': HEAD, 'method': 'Source reconciliation; see validation.json for actual executions and limitations.', 'numbered_gap_counts': dict(counts), 'findings': ordered}, indent=2) + '\n', encoding='utf-8')
(DATA / 'historical-claims.json').write_text(json.dumps(source_index, indent=2) + '\n', encoding='utf-8')

for p in REPORTS:
    original = historical[p.name]
    referenced = set(re.findall(r'\b(?:GAP-\d+|DIA-\d+)\b', original))
    relevant = [f for f in ordered if f['id'] in referenced or ('/' in f['id'] and f['id'].split('/')[0] in referenced)]
    if p.name == 'FIXNOW_DATABASE_AND_INTEGRATIONS.md':
        relevant += [f for f in ordered if f['id'].startswith('REPORT-integration') or f['id'] in ['REPORT-map-geocode', 'REPORT-metrics-mail']]
    if p.name == 'FIXNOW_DOMAIN_AND_WORKFLOW_INVENTORY.md':
        relevant += [f for f in ordered if f['id'].startswith('POLICY-') or f['id'] == 'REPORT-emergency-policy']
    if p.name in ['FIXNOW_AUDIT_SUMMARY.md', 'data_integrity_audit_report.md']:
        relevant += [rows['REPORT-counts-and-confidence']]
    banner = f'''{START}
> **Superseded status claims — reconciled {DATE}.** The original audit below is retained as history. Its OPEN/FIXED labels, runtime assertions, scores, totals, paths and recommended patches are not current verification. Use [Current Reconciliation](FIXNOW_CURRENT_RECONCILIATION.md) and this file's [current disposition appendix](#current-dispositions-2026-10-21). Source fixes do not establish deployed database/device behavior. No application fixes were made by this reconciliation.
{END}

'''
    appendix = APPENDIX + '\n\n## Current dispositions 2026-10-21\n\nThe following source-backed dispositions supersede the corresponding historical claims above. See the central register for validation limits and remaining priorities. Reused IDs include separate variant rows.\n\n' + table(relevant, '../') + '\n'
    p.write_text(banner + original + appendix, encoding='utf-8')

manifest = []
errors = []
for path in sorted({e['path'] for f in ordered for e in f['evidence']}):
    target = ROOT / path
    if not target.is_file():
        errors.append(f'Missing evidence file: {path}')
        continue
    content = target.read_bytes()
    if not path.startswith('audit_reports/'):
        manifest.append({'path': path, 'sha256': hashlib.sha256(content).hexdigest(), 'bytes': len(content)})
    if target.suffix.lower() != '.ttf':
        line_count = len(content.decode('utf-8-sig').splitlines())
        for f in ordered:
            for e in f['evidence']:
                if e['path'] == path and not 1 <= e['line'] <= line_count:
                    errors.append(f"Invalid line: {f['id']} {path}:{e['line']}")
(DATA / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
assert not errors, '\n'.join(errors)
assert sum(counts.values()) == 89
assert len({f['id'] for f in ordered}) == len(ordered)
print(f'Generated {len(ordered)} dispositions, 89 GAP slots, 6 DIA records, {len(source_index)} historical references, {len(manifest)} source hashes; evidence files and line bounds valid.')
