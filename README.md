# Environment

This project implements a hardware repair centre database covering service requests, quotation versions, repair jobs, inspections, incidents, corrective actions, and equipment returns.

The recorded implementation and testing environment used:

- MySQL Community Server 8.4.11.
- Python 3.13.
- Python dependencies listed in the root `requirements.txt`.

A running MySQL server is required. The database builder requires an account with permission to create databases, tables, views, and indexes.

Run all commands from the repository root. Use dedicated, disposable databases for testing; some test cases intentionally commit synthetic fixtures.

## Install Dependencies

For a POSIX shell:

```bash
python3.13 -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

For Windows PowerShell:

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1

python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Browser regression additionally requires Chromium:

```bash
python -m playwright install chromium
```

Database passwords are entered interactively. Replace the example connection settings in the following commands as appropriate.

# Build

## Build with the Python Tool

First, check the construction scripts without connecting to MySQL:

```bash
python tools/build_test_database.py --check
```

This validates the supported SQL statement structure and prints statement counts and SHA-256 hashes. It does not execute the scripts or verify database behavior.

Create and populate a new database:

```bash
python tools/build_test_database.py --host 127.0.0.1 --port 3306 --user root --database comp2411_test_marker
```

When prompted:

1. Enter the exact target database name: `comp2411_test_marker`.
2. Enter the MySQL password.

The builder creates the database and executes:

```text
sql/01_schema.sql
    → sql/02_data.sql
    → sql/03_views.sql
    → sql/04_indexes.sql
```

The database name must be `comp2411_test` or begin with `comp2411_test_`, followed by letters, digits, or underscores. The maximum name length is 64 characters.

The builder refuses to reuse an existing database. It does not drop databases or copy live data. If the target already exists, choose another name:

```bash
python tools/build_test_database.py --host 127.0.0.1 --port 3306 --user root --database comp2411_test_marker_2
```

Build execution details are retained in:

```text
evidence/build_runs/<run_timestamp>/build_log.json
```

The log records the target, script hashes, completed statement counts, and build outcome.

If construction fails after database creation, a partial database may remain because DDL changes cannot be fully rolled back. Correct the cause and rebuild under a new name before running queries or tests.

## Alternative: Manual SQL Construction

Using DBeaver or another MySQL client, create an empty database:

```sql
CREATE DATABASE comp2411_test_marker
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
```

Select it and execute each complete script in order:

1. `sql/01_schema.sql`
2. `sql/02_data.sql`
3. `sql/03_views.sql`
4. `sql/04_indexes.sql`

Check for errors before proceeding to the next script.

Use either the Python builder or the manual method for a particular database, not both. The construction scripts are not incremental migrations, and the seed should not be reloaded into populated tables.

## Verify Construction

Connect to the newly built database and execute:

```sql
SELECT DATABASE();

SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
```

The schema contains twelve tables:

```text
Customer
Staff
Equipment
ServiceRequest
RequestItem
Quotation
ServiceJob
Inspection
InspectionResult
Incident
CorrectiveAction
IncidentCorrectiveAction
```

# Queries

Execute `queries/Q01.sql` through `queries/Q08.sql` against the clean database using a MySQL client such as DBeaver.

Run the queries before mutation tests or WebUI regression. Those runs may commit fixtures and change subsequent query results.

## Query Summary


| Query | Purpose                                                                      | Retained clean-seed result                      |
| ----- | ---------------------------------------------------------------------------- | ----------------------------------------------- |
| Q01   | First-round inspection performance by component type                         | 7 groups; 71 inspected jobs and 30 failures     |
| Q02   | First-round inspection performance by responsible technician                 | 7 technicians; the same 71-job population       |
| Q03   | Overdue unverified corrective actions                                        | 10 actions: 8 RESOLVED and 2 IN_PROGRESS        |
| Q04   | Equipment received for repair more than once                                 | 14 equipment items                              |
| Q05   | Overdue unverified actions exceeding the population average overdue duration | 5 actions; population average of 11 days        |
| Q06   | Medium/high-severity incidents without corrective-action links               | 0 rows                                          |
| Q07   | Unresolved-action counts by technician, including zero counts                | 9 technicians; 7 with 2 actions and 2 with none |
| Q08   | Open repeat-repair jobs with qualifying earlier inspection failures          | 13 jobs                                         |

The final report groups the queries as follows:


| Management question | Topic                                                 | Queries       |
| ------------------- | ----------------------------------------------------- | ------------- |
| MQ01                | First-round inspection performance                    | Q01, Q02      |
| MQ02                | Repeat repairs                                        | Q04, Q08      |
| MQ03                | Corrective-action follow-up and missing-link auditing | Q03, Q05, Q06 |
| MQ04                | Technician unresolved-action workload                 | Q07           |

Query purposes, techniques, and output locations are recorded in `evidence/query_map.csv`.

Retained clean-seed outputs are provided in:

```text
evidence/query_results/Q01.csv
...
evidence/query_results/Q08.csv
```

## Reporting Definitions

- Q01 and Q02 include completed first-round inspections dated from `2026-03-01` to `2026-10-31`, inclusive.
- Q03 and Q05 use `2026-10-31` as the overdue reference date. Actions due on that date are not overdue.
- Q03 and Q05 include RESOLVED actions awaiting verification.
- Q07 counts only OPEN and IN_PROGRESS actions and retains technicians with zero unresolved actions, including inactive technicians stored in Staff.
- Q04, Q06, Q07, and Q08 do not apply a universal reporting-date cutoff.
- Q01 and Q02 use inspection-level `overall_result`.
- Q08 requires an open current job and an earlier job for the same equipment that was closed and returned before the current request date. The earlier job must contain at least one FAIL criterion in a completed first-round inspection.

Q06's header-only CSV represents zero matching rows, not a query failure.

For query-export tooling, see `tools/export_queries.py` and `tools/README.md`.

# Tests

## Automated SQL Suite

List the registered tests:

```bash
python tools/run_sql_tests.py --list
```

Run the suite against a newly constructed, disposable database:

```bash
python tools/run_sql_tests.py --host 127.0.0.1 --port 3306 --user root --database comp2411_test_marker
```

Follow the database-confirmation and password prompts. No concurrent writers should use the database during snapshot-based tests.

The selected final execution contains 95 cases across 93 SQL files:


| Category                          | Cases | PASS | FAIL |
| --------------------------------- | ----: | ---: | ---: |
| Positive operations and workflows |    14 |   14 |    0 |
| Negative and boundary cases       |    79 |   79 |    0 |
| Transaction demonstrations        |     2 |    2 |    0 |
| Total                             |    95 |   95 |    0 |

Each case is counted once. Expected rejections count as PASS only when the error outcome and required state checks match the registered expectation.

Representative transaction cases include:

- `TXC01`: related receipt changes persist after explicit COMMIT.
- `TXR01`: a deliberate duplicate-job failure is followed by explicit ROLLBACK and state verification.
- `IA02`: partial-operation writes are rolled back after failure. This case belongs to the negative and boundary category.

### SQL Evidence


| Location                      | Contents                               |
| ----------------------------- | -------------------------------------- |
| `tests/metadata.json`         | Registered cases and expected outcomes |
| `tools/boundary_coverage.csv` | Boundary-test mapping                  |
| `evidence/test_cases.csv`     | Selected final case outcomes           |
| `evidence/run_log.json`       | Selected final execution details       |
| `evidence/automated_runs/`    | Timestamped execution records          |

The selected final files correspond to original run `20261117T021159487358Z`, targeting `comp2411_test_rebuild_2` on MySQL Community Server 8.4.11. The log records an empty `not_run` list.

## Optional WebUI Regression

The optional WebUI supports query display/export and operation preview/commit. Its regression tooling is provided under `tools/regression/`.


| Suite     | Coverage summary                                                                                     | Recorded result      | Summary                                |
| --------- | ---------------------------------------------------------------------------------------------------- | -------------------- | -------------------------------------- |
| API/MySQL | Query equivalence, table browsing, selected validation, and preview/commit safeguards                | 14 named checks PASS | `webui_regression/api/result.json`     |
| Browser   | Query rendering/downloads, operation controls, rollback, and preview/export invalidation in Chromium | 14 named checks PASS | `webui_regression/broswer/result.json` |

Both summaries record commit `a90f9303ab8c33ce45b880a0208824a199c77ca4`, `passed: true`, and `error: null`.

The API run started on 17 November 2026 at 06:24:11 UTC. The browser run started at 06:25:52 UTC.

The browser evidence also includes `trace.zip`, `final.png`, and `page-errors.txt`.

These named checks are separate from the 95-case SQL suite and are not added to its case total.

## Synthetic Index Benchmark

`sql/04_indexes.sql` defines the additional Q03 reporting index:

```sql
CREATE INDEX idx_corrective_action_due_date
    ON CorrectiveAction (due_date);
```

The benchmark compared invisible and visible index conditions with `use_invisible_indexes=off`.

Both synthetic scenarios contained 100,000 corrective actions:


| Measurement                   |          Seed-like scenario |              Selective scenario |
| ----------------------------- | --------------------------: | ------------------------------: |
| Date-matching actions         |                      71,430 |                           1,000 |
| Q03 output rows               |                      23,810 |                             334 |
| Access with index available   |             Full table scan |                Index range scan |
| Median with index unavailable |                   65.567 ms |                       33.732 ms |
| Median with index available   |                   65.767 ms |                        4.668 ms |
| Result                        | No demonstrated improvement | Approximately 7.23-fold speedup |

Each condition received three warm-up executions and ten measured executions, with alternating condition order. Timings included query execution and complete result fetching. Result signatures matched between conditions.

Selected evidence is retained in:

```text
evidence/index_benchmark/seed_like/
evidence/index_benchmark/selective_like/
```

Each directory contains the run log, timing CSV, EXPLAIN JSON files, and EXPLAIN ANALYZE text files.

Original measurement identifiers:

- Seed-like: `20261118T155314941941Z`
- Selective: `20261118T155406958925Z`

The measurement logs record commit `a90bcc3eece981ca6ae90a10243218c6b3dae412`.

See `docs/index_benchmark.md` for the method and execution commands.

# Limitations

## Database and Workflow Enforcement

Schema constraints protect structural integrity and selected field requirements. The supplied operations additionally validate ownership, staff eligibility, inspector separation, workflow transitions, selected date boundaries, and closure conditions.

Arbitrary direct SQL can bypass validations implemented only in the controlled operations.

In particular:

- Staff foreign keys validate record existence, not role eligibility.
- Status CHECK constraints restrict allowed values, not every permitted transition.
- Foreign keys do not require parent records to have child rows.
- `Staff.active_status` has no explicit CHECK restricting it to 0 and 1.
- Only explicitly implemented date relationships are enforced.
- Valid incident–action links do not establish whether a shared action adequately addresses every linked incident.

## Database State

Some tests and WebUI operations commit synthetic fixtures. Their databases must not be treated as clean-seed reporting baselines.

To restore the baseline, create a new database using the builder. Rollback does not remove previously committed fixtures.

If a build fails, a partial database may remain. Do not use it for testing or query verification.

## Interpretation of Results

- Analytical findings describe synthetic data, not measured repair-centre performance.
- Repeat-repair associations do not establish causation.
- Technician failure rates and assignment counts are not complete measures of staff performance.
- A zero-row missing-link audit does not prove that missing links are impossible.
- Passing tests establish outcomes for the exercised cases, not every possible database mutation.

SQL tests, clean-seed query results, WebUI regression, and benchmark measurements are separate evidence sets and should not be combined into one test total or database population.

Recorded results refer to their identified executions. Later documentation edits or evidence reorganization do not constitute retesting.

## Interface and Performance Scope

The optional WebUI is intended for local execution and demonstration. Its regression results do not establish exhaustive security, accessibility, concurrency, load, mobile, cross-browser, or production-deployment validation.

The index benefit applies to the tested selective synthetic distribution. Index availability does not guarantee index use or a universal speedup. The local warm-cache benchmark did not quantify index storage or write-maintenance costs.

Payment processing, inventory, procurement, production authentication and authorization, and concurrent-user workflow coordination are outside the implemented scope.

# File inventory

## Database and Queries


| File                         | Purpose                                      |
| ---------------------------- | -------------------------------------------- |
| `sql/01_schema.sql`          | Twelve tables, keys, and CHECK constraints   |
| `sql/02_data.sql`            | Synthetic seed data                          |
| `sql/03_views.sql`           | Reporting views                              |
| `sql/04_indexes.sql`         | Additional due-date index                    |
| `queries/Q01.sql`–`Q08.sql` | Analytical queries                           |
| `evidence/query_map.csv`     | Query-purpose, technique, and output mapping |
| `evidence/query_results/`    | Retained clean-seed query CSVs               |

## Controlled Operations

The operation templates use Python-style parameter placeholders. See `operations/README.md` and `operations/examples/` for inputs and execution details.

```bash
python operations/run_operation.py --help
```


| File under`operations/`             | Purpose                                              |
| ----------------------------------- | ---------------------------------------------------- |
| `01_request_registration.sql`       | Register a service request                           |
| `02_quotation_acceptance.sql`       | Accept a quotation                                   |
| `03_receive_item.sql`               | Receive an item and create its job                   |
| `04_inspection.sql`                 | Record an inspection                                 |
| `05_incident_corrective_action.sql` | Create an incident, action, and link                 |
| `06_return_and_closure.sql`         | Return equipment and conditionally close its request |
| `07_issue_quotation.sql`            | Issue or revise a quotation                          |
| `08_add_request_item.sql`           | Add equipment to an eligible request                 |
| `09_submit_repair.sql`              | Submit repair work for inspection                    |
| `10_start_action.sql`               | Start a corrective action                            |
| `11_resolve_action.sql`             | Resolve a corrective action                          |
| `12_verify_action.sql`              | Verify a resolved action                             |
| `run_operation.py`                  | Parameterized execution with preview/commit support  |

## Build, Test, and Supporting Tools


| Location                       | Purpose                                 |
| ------------------------------ | --------------------------------------- |
| `requirements.txt`             | Python dependencies                     |
| `tools/build_test_database.py` | New-database construction               |
| `tools/export_queries.py`      | Query-output export                     |
| `tools/run_sql_tests.py`       | SQL test execution                      |
| `tools/README.md`              | Tooling documentation                   |
| `tests/`                       | SQL cases and registered expectations   |
| `tests/metadata.json`          | Test registration and expected outcomes |
| `tools/boundary_coverage.csv`  | Boundary-test mapping                   |
| `tools/benchmark/`             | Synthetic benchmark tooling             |
| `tools/regression/`            | WebUI regression tooling                |
| `webui/`                       | Optional local interface                |
| `docs/index_benchmark.md`      | Benchmark method and commands           |
| `ai_usage.md`                  | AI-use declaration                      |

## Execution Evidence


| Location                                   | Contents                               |
| ------------------------------------------ | -------------------------------------- |
| `evidence/build_runs/`                     | Timestamped build logs                 |
| `evidence/test_cases.csv`                  | Selected final SQL case outcomes       |
| `evidence/run_log.json`                    | Selected final SQL execution record    |
| `evidence/automated_runs/`                 | Timestamped SQL runs                   |
| `evidence/index_benchmark/seed_like/`      | Selected seed-like benchmark evidence  |
| `evidence/index_benchmark/selective_like/` | Selected selective benchmark evidence  |
| `webui_regression/api/`                    | Selected API/MySQL regression evidence |
| `webui_regression/broswer/`                | Selected browser regression evidence   |
