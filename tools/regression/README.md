# COMP2411 external regression tests

This add-only suite follows the COMP2021 external regression design: independent
runners, shared helpers, real application boundaries, dynamic generated IDs,
per-run evidence, explicit failure exit codes, and owned-process cleanup.
It does not modify production code, replace the 95-case SQL suite, overwrite
query baselines, or benchmark indexes. No endpoint or database layer is mocked.

Inspected target: COMP2411 main a90f9303ab8c33ce45b880a0208824a199c77ca4.
Reference: COMP2021 master tools/regression README/common/browser_smoke.
Selectors match the patched WebUI currently in main, not the older skeleton.

## Safety and setup

Use Python 3.9+ and run from the repository root. Install the existing WebUI
requirements (Flask, mysql-connector-python and sqlparse):

```bash
python -m pip install -r webui/requirements.txt
```

Create/select a NEW disposable database named, for example,
comp2411_regression_local. Load sql/01_schema.sql, sql/02_data.sql,
sql/03_views.sql, sql/04_indexes.sql in order. Do not reuse development,
submission-baseline, or operational-test databases. No database is created,
dropped, or reset by these tools. Run without concurrent writers.

Both runners REFUSE names outside comp2411_regression_<suffix>, ask for the
exact database name, then prompt for the password. Credentials are passed to
the owned server through stdin, not command-line arguments or saved config.
They start/stop their own server on 127.0.0.1:18080 and refuse an occupied port.
Use --web-port to change it. No existing application process is terminated.

WARNING: registration commit tests intentionally persist one new ServiceRequest
and RequestItem per runner; preview can consume auto-increment IDs. No automatic
DELETE/reset occurs. Rebuild the disposable database when a clean seed is needed.
Fixtures are identified in committed-fixture.json. Never export submission
baseline evidence from this database. Do not run API and browser concurrently.

## API + database regression

```bash
python tools/regression/api_regression.py --user root --database comp2411_regression_local
```

Runs the existing WebUI unit tests first, then tests real HTTP/MySQL:
- Q01-Q08 and 12 enabled operation discovery; connection identity.
- Host, Origin and CSRF rejection; invalid table/query and missing ticket.
- Every query HTTP result against direct execution of the same SQL, comparing
  exact columns and row multisets (so duplicates are not silently discarded).
- All table browsers and before/after read-only table snapshots.
- Invalid registration and successful preview leave table rows unchanged.
- Real commit, returned dynamic ID, request item creation, and ticket replay rejection.
- Quotation amount 0 rejected; 0.01 accepted in rollback preview without row changes.

The direct-query comparison tests transport/integration, NOT independent business
correctness. It deliberately does not hard-code changing analytical row totals.
Dependent workflows stop on failure and return nonzero; unrun cases are not PASS.

## Real browser regression

```bash
python -m pip install -r tools/regression/requirements-browser.txt
python -m playwright install chromium
python tools/regression/browser_smoke.py --user root --database comp2411_regression_local --headed
```

Omit --headed for headless. Checks:
- Actual query labels and Q01 period note.
- Q01-Q08 rendered cells vs API responses and downloaded CSVs, preserving headers,
  quoting, NULL as \N, duplicate rows, and empty-result handling.
- Q06 clean-seed empty result and explanation; query switching disables stale export.
- Connection identity; reads do not change table data.
- Quotation min/step behavior, result/criterion/severity dropdowns.
- Validation error display, preview rollback, input-edit preview invalidation.
- Confirmation cancellation preserves data and valid ticket; accepted commit
  persists the returned ID, disables commit, and clears stale query export.
- Uncaught JavaScript errors.

Not covered: every operation lifecycle in browser, screenshot pixel matching,
preview expiration, adversarial concurrency, all date boundaries, index speed,
or a full CLI acceptance suite. Those are not claimed by a PASS here.
The existing SQL suite remains responsible for its documented 95 cases.

## Evidence and failures

Each invocation writes regression-results/<runner>-<UTC timestamp>/ with
result.json, named completed cases, Git commit, and failure details. The API
runner saves unit logs and query responses. Browser additionally saves CSVs,
trace.zip, page-errors.txt, and a final screenshot; on failure it attempts
failure.html/failure.png. Server stdout/stderr are retained. PASS exits 0;
setup/assertion/runtime failure exits 1. Only the runner's own server is stopped.

```bash
python -m playwright show-trace regression-results/<browser-run>/trace.zip
```

Results may contain synthetic data and ephemeral CSRF tokens in the trace.
Review before sharing. Never commit credentials, virtual environments or generated
regression-results accidentally. No .gitignore is changed; use .git/info/exclude
locally or intentionally choose which evidence to retain.

## Verification of this patch

Python sources syntax-checked and patch application checked in a temporary Git
repository. No MySQL, Flask integration, or Chromium execution was performed by
the patch generator. Run locally before marking any corresponding UI item done.
