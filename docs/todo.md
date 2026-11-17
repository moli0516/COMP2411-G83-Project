# COMP2411 — Final Submission TODO

Status baseline: 17 November 2026. Check off remaining tasks only after verification.

## 1. Completed / Reported Complete

- [X]  Implement the twelve-table hardware repair database and controlled operations.
- [X]  Consolidate the verified schema, preserving constraints and table dependencies.
- [X]  Fix non-blank checks and completed-inspection NULL handling.
- [X]  Obtain 95 PASS / 0 FAIL in the automated suite.
- [X]  Enable the test runner to continue to later SQL files after a failure.
- [X]  Reproduce the result after correcting an incomplete schema copy (reported by user).
- [X]  Prepare Q01, Q04, Q06, and Q07 alongside existing Q02, Q03, Q05, and Q08.
- [X]  Add the chosen Q01 inspection period: 2026-03-01 through 2026-10-31.
- [X]  Update the exporter to execute Q01–Q08 and overwrite corresponding CSVs.
- [X]  Verify the corrected Q07 output has nine seed technicians, including zero counts.
- [X]  Confirm Q06 has the intentionally empty seed result.
- [X]  Draft README and PR description.
- [X]  Generate the WebUI alignment patch; application and integration testing remain open.

## 2. Priority 1 — Final Query Verification and Evidence

- [X]  Confirm the final query database contains construction seed only, not committed test fixtures.
- [X]  Confirm the local `sql/02_data.sql` contains the revised due dates for actions 21–30.
- [ ]  Check Q01 SQL uses inspection completion dates in the chosen period.
- [ ]  Confirm and document Q02's period; align with Q01 if directly comparing results.
- [X]  Check Q02 ranks by failed-job count with deterministic tie-breakers.
- [X]  Verify Q03 includes RESOLVED actions awaiting verification.
- [X]  Verify Q04 returns 14 equipment items: ten with two jobs and four with three.
- [X]  Verify Q05 returns actions 21–25 with overdue days 20, 18, 16, 14, and 12; population average 11.
- [X]  Keep Q06's header-only CSV and explain the intentional zero-row result.
- [ ]  Separately demonstrate Q06 detects a missing required link; roll back the demonstration and do not export it as baseline.
- [ ]  Verify Q07 retains technicians 8 and 9 with zero counts, including inactive technician 9.
- [ ]  Inspect final Q08 SQL for open current jobs, earlier closed same-equipment jobs, completed failed first inspections, and return before current request.
- [ ]  Add deterministic Q08 ordering if not already present.
- [ ]  Export all eight CSVs together from the same clean baseline before running tests.
- [ ]  Confirm CSV headers, SQL NULL as `\N`, and header-only empty results.
- [ ]  Finalize `evidence/query_map.csv` with actual technique tags and meaningful business-question references.
- [ ]  Resolve or replace all “group approval pending” descriptions after actual group agreement.
- [ ]  Ensure documentation describes Q01/Q04 as base-table queries unless their final SQL uses views.

Expected reporting outputs discussed, not a substitute for final SQL/content checks:


| Query | Baseline expectation                                                                 |
| ----- | ------------------------------------------------------------------------------------ |
| Q01   | Seven hardware-type groups; supplied output totals 71 inspected jobs and 30 failures |
| Q02   | Supplied output totals 71 inspected jobs and 30 failures; verify period and ranking  |
| Q03   | Ten overdue unverified actions                                                       |
| Q04   | Fourteen equipment items                                                             |
| Q05   | Five actions, IDs 21–25                                                             |
| Q06   | Zero rows, headers retained                                                          |
| Q07   | Nine technicians; IDs 1–7 each count two, IDs 8–9 count zero                       |
| Q08   | Previously supplied set has thirteen jobs; independently verify membership logic     |

## 3. Priority 2 — Index Justification

- [ ]  Confirm `sql/04_indexes.sql` defines `idx_corrective_action_due_date` exactly once.
- [ ]  Cite target Query ID Q03 in index comments and report.
- [ ]  Explain the supported due-date filter, expected selectivity/benefit, storage, and maintenance costs.
- [ ]  Optionally retain EXPLAIN evidence from the actual query and database.
- [ ]  Do not claim measured speedup without measurements; proof of speedup is not required.

## 4. Priority 3 — Report and Required Documents

- [ ]  Complete `report.pdf`: scope, rules, management questions, final ER diagram, schema/data dictionary, normalization, and implementation change log.
- [ ]  Document schema-enforced rules separately from operation validations and limitations.
- [ ]  Explain at least two analytical findings using verified query outputs and denominators.
- [ ]  Include transaction commit and failure/rollback before/intermediate/after evidence.
- [ ]  Explain the boundary-test defects found, their fixes, and successful retesting.
- [ ]  Update README using required headings: Environment, Build, Queries, Tests, Limitations, File inventory.
- [ ]  Replace generic view-script references with `sql/03_views.sql` where applicable.
- [ ]  Document that TXC01 commits fixtures and TXR01 commits setup before its tested rollback.
- [ ]  Explain that query baseline exports precede tests and how to restore seed state.
- [ ]  Verify root `metadata.json`: stage, Group ID, current Canvas group name, members, DBMS/version/database, and approval reference.
- [ ]  Complete `contribution.pdf` with accurate responsibilities/categories, any disagreement, and all signatures.
- [ ]  Update `ai_usage.md` honestly with assistance, affected files, accepted/rejected material, and verification.
- [ ]  Retain authorship/development history and ensure both members can explain and modify submitted work.
- [ ]  Check the guidance for the required report acknowledgement and preserve its wording accurately.

## 5. Priority 4 — Final Release Rebuild

- [ ]  Build from the exact submission files, not an uncommitted working database.
- [ ]  Use a fresh empty dedicated database with matching charset/collation.
- [ ]  Run `01_schema.sql` → `02_data.sql` → `03_views.sql` → `04_indexes.sql` without manual repairs.
- [ ]  Confirm all twelve tables, views, and indexes exist; check `IncidentCorrectiveAction` is not omitted.
- [ ]  Capture final query baselines before tests.
- [ ]  Run the full suite; expected discovery is 93 SQL files / 95 cases if inventory is unchanged.
- [ ]  Preserve same-run `test_cases.csv` and `run_log.json`; confirm no planned scripts are unrun.
- [ ]  Put the selected final results in `evidence/test_cases.csv` and retain the timestamped originals.
- [ ]  Keep earlier failure evidence separately; never edit FAIL results into PASS manually.

Commands from project root (use actual script filename for the query exporter):

```bash
python tools/run_sql_tests.py --list
python tools/run_sql_tests.py --host 127.0.0.1 --port 3306 --user root --database comp2411_test_rebuild
```

## 6. Optional — WebUI Patch

- [ ]  Back up local changes and run `git apply --unidiff-zero --check` on the downloaded patch.
- [ ]  Apply only if compatible with the local WebUI; inspect the diff.
- [ ]  Run existing WebUI unit tests.
- [ ]  Test Q01–Q08 labels, Q01 period note, and Q06 empty-result CSV.
- [ ]  Test minimum quotation amount 0.01 and inspection/severity dropdowns.
- [ ]  Verify edits invalidate preview and commit requires a fresh preview.
- [ ]  Verify query changes/commit attempts clear stale exports.
- [ ]  Test preview rollback, committed IDs, error display, and connection identity against MySQL.
- [ ]  Do not describe UI checks as covered by the 95-case SQL suite.
- [ ]  Defer optional UI work if it threatens required deliverables.

## 7. Presentation and Submission

- [ ]  Finish `presentation.pdf` with correct group/member/project identity.
- [ ]  Rehearse a four-minute presentation/live SQL demonstration.
- [ ]  Practice the two-minute live modification/test task with both members participating.
- [ ]  Prepare SQL and local connection before the slot; check current Canvas appointment.
- [ ]  Do not use AI, messaging, or remote assistance during the assessed live task.
- [ ]  Audit exact archive/file naming and required CSV headers against the guidance.
- [ ]  Package one top-level directory matching the archive name.
- [ ]  Exclude passwords, `.venv`, `__pycache__`, editor caches, and database binaries.
- [ ]  Open all PDFs, verify signatures, and test the extracted archive.
- [ ]  Submit the complete Stage 2 package, including presentation, by 23 November 2026, 23:55 HKT.
- [ ]  Verify upload confirmation and share the submitted package with both members.

## Working Rule

Freeze new features. Prioritize verified query evidence, reproducibility, required documents,
and demonstration readiness. A generated draft or patch is not a verified deliverable.
