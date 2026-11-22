# Environment

This project implements a hardware repair centre database covering service
requests, quotation versions, individual repair jobs, inspections, incidents,
corrective actions, and equipment returns.

Project identifiers:

- Course: COMP2411 Database Systems.
- Group ID: G083.
- Canvas group: Group 83, Nov 26, 15:06-15:11, TU101.
- Scenario ID: D14-W08.
- Intended database: `comp2411_test_marker`.
- Approval reference: none; see `metadata.json`.

The recorded implementation and testing environment used:

- MySQL Community Server 8.4.11.
- Python 3.13.
- Python dependencies listed in the root `requirements.txt`.

DBeaver or another compatible MySQL client can execute the construction
scripts and business queries directly. Python is required for the supplied
build, export, operation, and automated-test tools.

Run all commands from the project's top-level directory. Use dedicated,
disposable databases for testing; some test cases intentionally commit
synthetic fixtures.

## SQL Dialect and Compatibility

The submitted SQL targets MySQL Community Server 8.4.11. Compatibility
with other database systems or MySQL versions has not been verified.

Material dialect and implementation choices include:

- `AUTO_INCREMENT` for generated integer identifiers.
- `ENGINE=InnoDB` for transactional tables and foreign-key enforcement.
- `utf8mb4` with the MySQL collation `utf8mb4_0900_ai_ci`.
- Enforced `CHECK` constraints for permitted values and field consistency.
- MySQL's `DATEDIFF(end_date, start_date)` function for overdue-day
  calculations.
- `TINYINT(1)` for `Staff.active_status`. This declaration does not itself
  restrict values to 0 and 1; no binary-value CHECK is defined.
- MySQL session variables, `LAST_INSERT_ID()`, and `IF()` in transaction
  demonstrations. Session variables require connection continuity between
  execution blocks.

The optional index benchmark additionally uses MySQL invisible-index
controls, `EXPLAIN FORMAT=JSON`, and `EXPLAIN ANALYZE`. These are benchmark
features, not prerequisites for running the eight business queries.

Controlled-operation templates use Python-style parameter placeholders and
must be executed through the supplied operation runner with bound parameters.
They are not standalone SQL scripts for direct execution in DBeaver.

The four construction scripts operate within the selected database using
unqualified project table names. They do not create database accounts or
perform server administration.

## Database Account and Credentials

Use a course database account with the necessary privileges on the dedicated
project database.

For construction in an already-created empty database, the account needs
`CREATE`, `REFERENCES`, `INSERT`, `SELECT`, `CREATE VIEW`, and `INDEX`
privileges as required by the submitted scripts. Operation and mutation
tests additionally require `UPDATE` and `DELETE`.

The optional Python builder also requires permission to create its target
database. If the course account cannot create databases, use an empty
database provisioned by the teaching team and execute the four construction
scripts manually in order.

The optional index-visibility benchmark requires `ALTER` privileges on
the benchmark table. Do not run it against a shared or live database.

`COURSE_DB_USER` in the following commands is a placeholder. Replace it with
your assigned course database username; it is not a literal account name.
Replace the host, port, and database settings where appropriate.

Passwords are entered interactively. Do not embed real passwords in commands
or committed files.

Do not include real passwords, connection secrets, credential files,
or database-client connection exports containing credentials in the
submission archive. Account creation and privilege administration are
not part of the submitted construction scripts.

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

Virtual environments, caches, and installed browser binaries are local
dependencies and should not be included in the submission archive.

# Build

## Standard Assessment Construction

The evaluator creates an empty dedicated database and selects it as the
active database before executing the construction scripts.

Using DBeaver or another MySQL client, select that empty database and execute
each complete script in this order:

1. `sql/01_schema.sql`
2. `sql/02_data.sql`
3. `sql/03_views.sql`
4. `sql/04_indexes.sql`

Check for errors before proceeding to the next script.

Database provisioning is separate from the submitted construction scripts.
If your course account cannot create a database, request an empty dedicated
database from the teaching team.

The scripts are not incremental migrations. Do not execute them against
an existing populated schema or reload the seed into populated tables.

## Optional Build with the Python Tool

The Python builder is a convenience tool for creating a new disposable
test database. It requires database-creation privileges and is not required
for the standard assessment construction described above.

First, check the construction scripts without connecting to MySQL:

```bash
python tools/build_test_database.py --check
```

This validates the supported SQL statement structure and prints statement
counts and SHA-256 hashes. It does not execute the scripts or verify database
behavior.

Create and populate a new database:

```bash
python tools/build_test_database.py --host 127.0.0.1 --port 3306 --user COURSE_DB_USER --database comp2411_test_marker
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

For this safety-restricted builder, the database name must be `comp2411_test`
or begin with `comp2411_test_`, followed by letters, digits, or underscores.
The maximum name length is 64 characters.

The builder refuses to reuse an existing database. It does not drop databases
or copy live data. If the target already exists, choose another name:

```bash
python tools/build_test_database.py --host 127.0.0.1 --port 3306 --user COURSE_DB_USER --database comp2411_test_marker_2
```

Build execution details are retained in:

```text
evidence/build_runs/<run_timestamp>/build_log.json
```

The log records the target, script hashes, completed statement counts, and
build outcome.

If construction fails after database creation, a partial database may remain
because DDL changes cannot be fully rolled back. Correct the cause and rebuild
in a new empty database before running queries or tests.

Use either the Python builder or manual construction for a particular
database, not both.

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

Execute `queries/Q01.sql` through `queries/Q08.sql` against the clean
database using a MySQL client such as DBeaver.

Run and export the queries before mutation tests or WebUI regression.
Those runs may commit fixtures and change subsequent query results.

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

Query purposes, techniques, and output locations are recorded in
`evidence/query_map.csv`.

Retained clean-seed outputs are provided in:

```text
evidence/query_results/Q01.csv
...
evidence/query_results/Q08.csv
```

## Reporting Definitions

- Q01 and Q02 include completed first-round inspections dated from
  `2026-03-01` to `2026-10-31`, inclusive.
- Q03 and Q05 use `2026-10-31` as the overdue reference date. Actions due
  on that date are not overdue.
- Q03 and Q05 include RESOLVED actions awaiting verification.
- Q07 counts only OPEN and IN_PROGRESS actions and retains technicians
  with zero unresolved actions, including inactive technicians stored
  in Staff.
- Q04, Q06, Q07, and Q08 do not apply a universal reporting-date cutoff.
- Q01 and Q02 use inspection-level `overall_result`.
- Q08 requires an open current job and an earlier job for the same equipment
  that was closed and returned before the current request date. The earlier
  job must contain at least one FAIL criterion in a completed first-round
  inspection.

Q06's header-only CSV represents zero matching rows, not a query failure.

## Result Export Convention

Export each query's complete output, including column headers, to its
matching `evidence/query_results/Qxx.csv` file.

Represent SQL NULL using the reserved text `\N`; keep empty strings empty.
Do not replace NULL with an empty string or the literal text `NULL`.

Preserve the query's specified ordering. Where no ordering is specified,
compare row contents while retaining duplicates rather than relying on
display order.

For query-export tooling, see `tools/export_queries.py` and
`tools/README.md`.

# Tests

## Automated SQL Suite

List the registered tests:

```bash
python tools/run_sql_tests.py --list
```

Run the suite against a newly constructed, disposable database:

```bash
python tools/run_sql_tests.py --host 127.0.0.1 --port 3306 --user COURSE_DB_USER --database comp2411_test_marker
```

Follow the database-confirmation and password prompts. No concurrent writers
should use the database during snapshot-based tests.

The selected final execution contains 95 cases across 93 SQL files:


| Category                          | Cases | PASS | FAIL |
| --------------------------------- | ----: | ---: | ---: |
| Positive operations and workflows |    14 |   14 |    0 |
| Negative and boundary cases       |    79 |   79 |    0 |
| Transaction demonstrations        |     2 |    2 |    0 |
| Total                             |    95 |   95 |    0 |

Each case is counted once. Expected rejections count as PASS only when the
error outcome and required state checks match the registered expectation.

Representative transaction cases include:

- `TXC01`: related receipt changes persist after explicit COMMIT.
- `TXR01`: a deliberate duplicate-job failure is followed by explicit
  ROLLBACK and state verification.
- `IA02`: partial-operation writes are rolled back after failure. This case
  belongs to the negative and boundary category.

### Manual Transaction Execution

Run each transaction demonstration on a freshly constructed dedicated
database, with no unrelated active transaction. Export the clean-seed query
results before running the transaction scripts, because their setup blocks
commit synthetic fixture records.

Use the same connection throughout each demonstration. Do not reconnect
or change the active database between execution blocks.

Check the selected database and session autocommit setting:

```sql
SELECT DATABASE() AS database_name,
       @@autocommit AS autocommit_setting;
```

The retained transaction run recorded `autocommit = 1`. The demonstrated
changes are nevertheless enclosed by explicit `START TRANSACTION` and
`COMMIT` or `ROLLBACK` statements.

Do not execute DDL within the demonstrated transaction.

#### TXC01: Successful Commit

Open `tests/transaction_commit.sql` and execute its statements in order
in the same connection.

The script first creates and commits its prerequisite fixture. This setup
commit is separate from the receipt transaction being demonstrated.

The receipt transaction then:

1. Captures `TXC01_BEFORE`.
2. Executes `START TRANSACTION`.
3. Marks the request item as received, inserts its service job, and updates
   the request status.
4. Executes `COMMIT`.
5. Displays `TXC01_AFTER` and checks that the related receipt changes persist.

The after-state should show:

- Request status `IN_PROGRESS`.
- Request item status `RECEIVED`.
- One corresponding service job with status `RECEIVED`.
- Final verification `PASS` with `persisted_receipts = 1`.

If an unexpected error occurs, stop and explicitly roll back any active
transaction before investigating. Do not treat a partial execution as
a successful commit demonstration.

#### TXR01: Expected Failure and Explicit Rollback

Open `tests/transaction_rollback.sql` and execute its labelled blocks
separately, in the following order:

1. `BLOCK A`: create and commit the prerequisite fixture, then display
   `TXR01_BEFORE`.
2. `BLOCK B1`: start the receipt transaction, execute its successful changes,
   and display `TXR01_INTERMEDIATE`.
3. `BLOCK B2`: execute only the labelled duplicate-job `INSERT`. Expect
   MySQL error `1062`, SQLSTATE `23000`, because a service job already
   exists for the same request item.
4. `BLOCK C`: explicitly execute `ROLLBACK`, followed by all verification
   queries.

If the SQL client stops at the expected error, manually select and execute
`BLOCK C` in the same connection. Do not rerun the setup or successful
transaction blocks, reconnect, or issue `COMMIT` before the rollback.

Configure the client so that it does not automatically roll back the
transaction on the expected statement error; this demonstration uses the
explicit `ROLLBACK` in `BLOCK C`.

After rollback, confirm that:

- The request status is restored to `ACCEPTED`.
- The request item status is restored to `AWAITING_DELIVERY`.
- No service job remains for the fixture request item.
- The final verification returns `PASS` with `remaining_jobs = 0`.

The duplicate-key error rejects the second insertion. The explicit
`ROLLBACK` undoes the earlier successful changes in the transaction.

#### Restoring the Clean Seed

The prerequisite fixtures were committed before the demonstrated
transactions and therefore remain after the tested rollback.

For another test requiring a clean seed, select a new empty dedicated
database and rerun the four construction scripts in the documented order.
The optional builder can do this when database-creation privileges are
available.

Do not reload the seed script into a populated database. Rollback alone
does not remove previously committed fixtures.

### Manual Negative Tests

Execute files under `tests/negative/` separately from construction.
Each file contains one expected-failure statement and documents its
prerequisites, Test ID, and expected MySQL error number or SQLSTATE.

Before each test, establish its documented initial state. After the expected
rejection, verify that the relevant data remain unchanged.

An error is an expected result only when it matches the registered test
expectation. Unexpected errors are failures and must be investigated.

`tests/transaction_rollback.sql` is the documented exception to the
single-error-file convention: its setup, successful changes, expected
failure, explicit rollback, and verification form one transaction test.

### SQL Evidence


| Location                      | Contents                               |
| ----------------------------- | -------------------------------------- |
| `tests/metadata.json`         | Registered cases and expected outcomes |
| `tools/boundary_coverage.csv` | Boundary-test mapping                  |
| `evidence/test_cases.csv`     | Selected final case outcomes           |
| `evidence/run_log.json`       | Selected final execution details       |
| `evidence/automated_runs/`    | Timestamped execution records          |

The selected final files correspond to original run
`20261117T021159487358Z`, targeting `comp2411_test_rebuild_2` on MySQL
Community Server 8.4.11. The log records an empty `not_run` list.

This historical database name identifies the retained execution. It is
not required to match the intended database name used for a new rebuild.

## Optional WebUI Regression

The optional WebUI supports query display/export and operation
preview/commit. Its regression tooling is provided under
`tools/regression/`.


| Suite     | Coverage summary                                                                                     | Recorded result      | Summary                                |
| --------- | ---------------------------------------------------------------------------------------------------- | -------------------- | -------------------------------------- |
| API/MySQL | Query equivalence, table browsing, selected validation, and preview/commit safeguards                | 14 named checks PASS | `webui_regression/api/result.json`     |
| Browser   | Query rendering/downloads, operation controls, rollback, and preview/export invalidation in Chromium | 14 named checks PASS | `webui_regression/broswer/result.json` |

The spelling `broswer` is retained because it is the actual submitted
evidence directory name.

Both summaries record commit
`a90f9303ab8c33ce45b880a0208824a199c77ca4`, `passed: true`, and
`error: null`.

The API run started on 17 November 2026 at 06:24:11 UTC. The browser run
started at 06:25:52 UTC.

The browser evidence also includes `trace.zip`, `final.png`, and
`page-errors.txt`.

These named checks are separate from the 95-case SQL suite and are not
added to its case total.

Use a separate disposable database for WebUI regression. Do not use a
WebUI regression database to regenerate clean-seed submission CSVs.

## Synthetic Index Benchmark

`sql/04_indexes.sql` defines the additional Q03 reporting index:

```sql
CREATE INDEX idx_corrective_action_due_date
    ON CorrectiveAction (due_date);
```

The benchmark compared invisible and visible index conditions with
`use_invisible_indexes=off`.

Both synthetic scenarios contained 100,000 corrective actions:


| Measurement                   |          Seed-like scenario |              Selective scenario |
| ----------------------------- | --------------------------: | ------------------------------: |
| Date-matching actions         |                      71,430 |                           1,000 |
| Q03 output rows               |                      23,810 |                             334 |
| Access with index available   |             Full table scan |                Index range scan |
| Median with index unavailable |                   65.567 ms |                       33.732 ms |
| Median with index available   |                   65.767 ms |                        4.668 ms |
| Result                        | No demonstrated improvement | Approximately 7.23-fold speedup |

Each condition received three warm-up executions and ten measured
executions, with alternating condition order. Timings included query
execution and complete result fetching. Result signatures matched between
conditions.

Selected evidence is retained in:

```text
evidence/index_benchmark/seed_like/
evidence/index_benchmark/selective_like/
```

Each directory contains the run log, timing CSV, EXPLAIN JSON files, and
EXPLAIN ANALYZE text files.

Original measurement identifiers:

- Seed-like: `20261118T155314941941Z`.
- Selective: `20261118T155406958925Z`.

The measurement logs record commit
`a90bcc3eece981ca6ae90a10243218c6b3dae412`.

See `docs/index_benchmark.md` for the method and execution commands.

# Limitations

## Database and Workflow Enforcement

Schema constraints protect structural integrity and selected field
requirements. The supplied operations additionally validate ownership,
staff eligibility, inspector separation, workflow transitions, selected
date boundaries, and closure conditions.

Arbitrary direct SQL can bypass validations implemented only in the
controlled operations.

In particular:

- Staff foreign keys validate record existence, not role eligibility.
- Status CHECK constraints restrict allowed values, not every permitted
  transition.
- Foreign keys do not require parent records to have child rows.
- `Staff.active_status` has no explicit CHECK restricting it to 0 and 1.
- Only explicitly implemented date relationships are enforced.
- Valid incident–action links do not establish whether a shared action
  adequately addresses every linked incident.

## Database State

Some tests and WebUI operations commit synthetic fixtures. Their databases
must not be treated as clean-seed reporting baselines.

To restore the baseline, use a new empty dedicated database and execute the
four construction scripts in order. The optional builder can provision
this database when the account has the necessary privileges.

Rollback does not remove previously committed fixtures.

If a build fails, a partial database may remain. Do not use it for testing
or query verification.

## Interpretation of Results

- Analytical findings describe synthetic data, not measured repair-centre
  performance.
- Repeat-repair associations do not establish causation.
- Technician failure rates and assignment counts are not complete measures
  of staff performance.
- A zero-row missing-link audit does not prove that missing links are
  impossible.
- Passing tests establish outcomes for the exercised cases, not every
  possible database mutation.

SQL tests, clean-seed query results, WebUI regression, and benchmark
measurements are separate evidence sets and should not be combined into
one test total or database population.

Recorded results refer to their identified executions. Later documentation
edits or evidence reorganization do not constitute retesting.

## Interface and Performance Scope

The optional WebUI is intended for local execution and demonstration.
Its regression results do not establish exhaustive security, accessibility,
concurrency, load, mobile, cross-browser, or production-deployment validation.

The index benefit applies to the tested selective synthetic distribution.
Index availability does not guarantee index use or a universal speedup.
The local warm-cache benchmark did not quantify index storage or
write-maintenance costs.

Payment processing, inventory, procurement, production authentication and
authorization, and concurrent-user workflow coordination are outside the
implemented scope.

# File inventory

Paths below are relative to the submission's top-level directory.

## Submission Documents


| File                 | Purpose                                                              |
| -------------------- | -------------------------------------------------------------------- |
| `metadata.json`      | Group, scenario, members, and database-environment metadata          |
| `README.md`          | Setup, execution, testing, limitations, and file inventory           |
| `report.pdf`         | Final design, implementation, testing, analysis, and index rationale |
| `contribution.pdf`   | Responsibilities, contribution categories, and member signatures     |
| `presentation.pdf`   | Submitted presentation slides                                        |
| `ai_usage.md`        | AI-use declaration                                                   |
| `docs/change_log.md` | Changes from the Stage 1 proposal                                    |

The final PDFs are included in the submission package; they need not be
published in the public repository.

## Database and Queries


| File                                 | Purpose                                      |
| ------------------------------------ | -------------------------------------------- |
| `sql/01_schema.sql`                  | Twelve tables, keys, and CHECK constraints   |
| `sql/02_data.sql`                    | Synthetic seed data                          |
| `sql/03_views.sql`                   | Reporting views                              |
| `sql/04_indexes.sql`                 | Additional due-date index                    |
| `queries/Q01.sql`–`queries/Q08.sql` | Analytical queries                           |
| `evidence/query_map.csv`             | Query-purpose, technique, and output mapping |
| `evidence/query_results/`            | Retained clean-seed query CSVs               |

## Controlled Operations

The operation templates use Python-style parameter placeholders.
See `operations/README.md` and `operations/examples/` for inputs and
execution details.

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


| Location                         | Purpose                                      |
| -------------------------------- | -------------------------------------------- |
| `requirements.txt`               | Python dependencies                          |
| `tools/build_test_database.py`   | New-database construction                    |
| `tools/export_queries.py`        | Query-output export                          |
| `tools/run_sql_tests.py`         | SQL test execution                           |
| `tools/README.md`                | Tooling documentation                        |
| `tests/`                         | SQL cases and registered expectations        |
| `tests/positive.sql`             | Labelled successful-operation tests          |
| `tests/transaction_commit.sql`   | TXC01 explicit-commit demonstration          |
| `tests/transaction_rollback.sql` | TXR01 expected failure and explicit rollback |
| `tests/negative/`                | Separately executable expected-failure tests |
| `tests/metadata.json`            | Test registration and expected outcomes      |
| `tools/boundary_coverage.csv`    | Boundary-test mapping                        |
| `tools/benchmark/`               | Synthetic benchmark tooling                  |
| `tools/regression/`              | WebUI regression tooling                     |
| `webui/`                         | Optional local interface                     |
| `docs/index_benchmark.md`        | Benchmark method and commands                |

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
