# Consolidated CLI tools

Replace the tools directory with this one (first move the old directory OUTSIDE the
project or save it separately). This is a tools-only package. Keep existing sql/,
tests/ and operations/ files. Requires the ORIGINAL W01-W10 fixture SQL files from
workflow_tests_W01_W10.zip; fixtures use @wr, @wi, @wt, @ws, @wm, @wj, @wa variables.
Do not substitute unrelated W SQL versions without updating metadata accordingly.

Files kept:
- build_test_database.py: new isolated seed database, optional.
- run_sql_tests.py: ONLY test entry point, scans all tests recursively.
- configure_tests.py: one-time metadata merge (no DB or operations modifications).
- workflow_cases.json: full W operation parameters/postconditions.
- requirements-sql-tests.txt: dependencies.
- README.md: these instructions.

From project root:
python -m pip install -r tools/requirements-sql-tests.txt
python tools/configure_tests.py
python tools/run_sql_tests.py --list
python tools/run_sql_tests.py --user root --database comp2411_test

Expected 25 SQL files / 27 cases if only the supplied suite is present. Additional
SQL requires metadata: missing/extra entries, empty scripts, unsupported modes cause
preflight failure; no silent skips. Every registered case must have descriptions.
Failures stop execution; later files are NOT RUN in log (not falsely PASS in CSV).

No operation_core.py required. No install_negative_tests.py or install_workflow_tests.py.
No modifications to operations/run_operation.py. Workflow tests execute REAL operation
SQL using the same first-SELECT 'ok' protocol, NOT the CLI Python function itself.
The guard predicates are not duplicated. This is template integration coverage, not
end-to-end CLI coverage. If a previous installer changed run_operation.py to import
operation_core, this package does NOT undo that file; restore its reviewed original
from backup/Git before using that CLI. Test runner itself is independent of the core.

Workflow details: W01-W06/W08/W09 expect rejection and exact row snapshot equality.
W07 returns an eligible job but leaves request IN_PROGRESS with undelivered item.
W10 tests a FAIL result produces FAIL+REWORK_REQUIRED, not arbitrary manual editing.
These are NOT positive+negative pairs for every workflow. N01-N12 expect MySQL errors.
All isolated tests use full-row snapshot hashes (excluding auto-increment counters),
roll back fixtures and verify baseline. Use transactional tables/no concurrent writers.
Earlier transaction tests intentionally COMMIT fixtures; full suite does not preserve
fresh seed. Export query baselines before mutations, rebuild when required.

Fresh DB if required:
python tools/build_test_database.py --check
python tools/build_test_database.py --user root --database comp2411_test_run2
python tools/run_sql_tests.py --user root --database comp2411_test_run2

Builder supports an optional outer seed transaction and alias-qualified columns.
Never drops an existing DB. Failure may leave partial DDL: do not test that DB.
Project SQL is trusted code: review for hard-coded development-schema references.
This is a seed baseline mirror, NOT a live database clone/replication tool.

Results: evidence/automated_runs/<UTC timestamp>/test_cases.csv and run_log.json.
Canonical evidence/test_cases.csv is never overwritten. Review before promoting.
Build logs: evidence/build_runs/. Passwords are prompted, never written to metadata.
Update ai_usage.md. This consolidated release has syntax/discovery tests only;
no live MySQL or full workflow suite was run by the assistant.
