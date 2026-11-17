# COMP2411 — Hardware Repair Centre Database

A MySQL database project for managing computer hardware repair requests,
quotation revisions, individual repair jobs, quality inspections, incidents,
corrective actions, and hardware returns.

The implementation includes schema and seed scripts, business queries,
parameterized SQL operations, and an automated test runner.

## 1. Project Scope

The database supports:

- Customers and their hardware equipment.
- Service requests containing one or more hardware items.
- Request-level quotations and quotation revisions.
- Quotation acceptance before hardware receipt.
- One service job for each received request item.
- Responsible technician assignment.
- Quality inspections performed by an eligible inspector who differs from
  the responsible technician.
- Multiple inspection rounds following rework.
- Incidents and corrective actions, including shared actions.
- Corrective-action resolution and managerial verification.
- Hardware return and request closure after all items have been returned.
- Management reporting on inspection failures, overdue actions, and repeat repairs.

Payments, inventory management, customer authentication, and concurrent-user
workflow control are outside the project scope.

## 2. Requirements

The project has been developed using:

- MySQL Community Server 8.4.11.
- Python 3.13.
- DBeaver or the MySQL command-line client.
- Python packages declared by the operation and test tooling.

The test runner imports:

- `mysql.connector`
- `sqlparse`

Use a disposable database when executing automated tests. Some transaction
tests intentionally commit synthetic fixtures.

## 3. Repository Structure

The principal project paths are:


| Path                       | Purpose                                                |
| -------------------------- | ------------------------------------------------------ |
| `sql/01_schema.sql`        | Table definitions and structural constraints           |
| `sql/02_data.sql`          | Synthetic seed data                                    |
| `sql/04_indexes.sql`       | Additional reporting index definitions                 |
| `operations/`              | Parameterized business-operation SQL and Python runner |
| `tests/`                   | SQL tests and test metadata                            |
| `tests/metadata.json`      | Registration of test files and expected outcomes       |
| `tools/run_sql_tests.py`   | Automated SQL test runner                              |
| `tools/configure_tests.py` | Test-metadata configuration utility                    |
| `evidence/automated_runs/` | Timestamped automated test results                     |
| `ai_usage.md`              | Record of AI assistance and verification               |

Views, business-query SQL, and query result CSVs are maintained separately.
Use their actual repository locations when following the rebuild sequence below.

## 4. Database Model

The schema contains twelve tables:

1. `Customer`
2. `Staff`
3. `Equipment`
4. `ServiceRequest`
5. `RequestItem`
6. `Quotation`
7. `ServiceJob`
8. `Inspection`
9. `InspectionResult`
10. `Incident`
11. `CorrectiveAction`
12. `IncidentCorrectiveAction`

### Main Relationships

- A customer owns equipment and submits service requests.
- A request contains equipment through `RequestItem`.
- A request may retain multiple quotation versions.
- A request item has at most one service job.
- A job may have multiple inspection rounds.
- Each inspection contains criterion-level results.
- Incidents belong to jobs.
- `IncidentCorrectiveAction` supports multiple actions per incident and
  actions shared across incidents.

Equipment and service history are kept separate. Repeat repairs use the
existing equipment record with a new request and job rather than reopening
a closed job.

## 5. Environment Setup

From the project root:

```bash
python3.13 -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip
python -m pip install -r operations/requirements.txt
python -m pip install mysql-connector-python sqlparse
```

The final command explicitly installs the packages imported by the test runner.

Do not put database passwords in this README, committed configuration files,
or command-line arguments. Enter credentials when prompted by the tools.

## 6. Database Setup and Rebuild

### 6.1 Create an Empty Database

Create a new database for a clean rebuild:

```sql
CREATE DATABASE comp2411_test_rebuild
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
```

If that database already contains tables or test data, choose a different
empty database rather than rerunning the creation scripts over it.

The schema script does not create or select a database.

### 6.2 Execute the Scripts in Order

Select the new database in DBeaver, then execute complete scripts in this order:

1. `sql/01_schema.sql`
2. `sql/02_data.sql`
3. The project's view-definition script.
4. `sql/04_indexes.sql`

Execute the whole schema file, including its final
`IncidentCorrectiveAction` definition.

Alternatively, run the known scripts from the project root:

```bash
mysql --host=127.0.0.1 --port=3306 --user=root --password \
  comp2411_test_rebuild < sql/01_schema.sql

mysql --host=127.0.0.1 --port=3306 --user=root --password \
  comp2411_test_rebuild < sql/02_data.sql
```

Execute the actual view-definition script next, followed by:

```bash
mysql --host=127.0.0.1 --port=3306 --user=root --password \
  comp2411_test_rebuild < sql/04_indexes.sql
```

The scripts are intended to be executed once in the documented order.
The schema is a clean-build baseline, not an incremental migration script.

Do not run the seed script repeatedly against populated tables.

### 6.3 Verify Table Creation

```sql
SELECT DATABASE();

SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
```

Confirm that all twelve tables listed in Section 4 exist.

### 6.4 Capture Query Baselines Before Tests

After loading the seed data, views, and indexes:

1. Execute Q01–Q08.
2. Verify their results.
3. Export the corresponding baseline CSVs.
4. Run automated tests afterwards.

Do not use a database containing committed test fixtures to regenerate
seed-only reporting baselines.

## 7. Integrity and Enforcement

### 7.1 Schema Constraints

The consolidated schema includes:

- Primary and foreign keys.
- Unique equipment serial numbers.
- Unique request–equipment membership.
- Unique quotation versions within a request.
- At most one job per request item.
- Unique inspection rounds within a job.
- Unique criterion names within an inspection.
- Status and result domains.
- Positive quotation amounts and sequence numbers.
- Non-blank checks for required text fields.
- Required inspection completion fields.
- Required return fields for closed jobs.
- Corrective-action state and field-consistency checks.

The consolidated baseline retains 39 CHECK constraints and 17 foreign keys.

Nullable descriptions remain nullable where appropriate. Non-blank checks
reject empty or space-only values when those descriptions are supplied;
separate state checks determine when a value is required.

### 7.2 Controlled Operations

Some rules require relationships or previous states to be checked. These
are validated by the provided operations rather than by row-level CHECK
constraints alone.

Examples include:

- Equipment ownership.
- Accepted quotation before receipt.
- Staff role eligibility.
- Inspector separation from the responsible technician.
- Permitted action-state transitions.
- Request closure only after all request items qualify.

Arbitrary direct SQL can bypass controlled-operation validations. The project
does not claim that every workflow rule is enforced against every possible
direct database update.

### 7.3 Preserved Baseline Behaviour

The schema consolidation preserves the tested structure rather than adding
unrelated restrictions.

For example:

- `active_status` is stored as `TINYINT(1)` without an additional explicit
  `IN (0, 1)` CHECK.
- Operation date validation should not be assumed to exist as an equivalent
  row-level constraint.
- Two inspection completion CHECKs are retained for compatibility with the
  tested baseline; the stronger one explicitly rejects a NULL overall result.

## 8. Business Operations

The `operations/` directory contains parameterized SQL templates:


| File                                | Operation                                           |
| ----------------------------------- | --------------------------------------------------- |
| `01_request_registration.sql`       | Register a request                                  |
| `02_quotation_acceptance.sql`       | Accept a quotation                                  |
| `03_receive_item.sql`               | Receive an item and create its job                  |
| `04_inspection.sql`                 | Record a completed inspection                       |
| `05_incident_corrective_action.sql` | Create an incident, action, and link                |
| `06_return_and_closure.sql`         | Return hardware and conditionally close its request |
| `07_issue_quotation.sql`            | Issue or revise a quotation                         |
| `08_add_request_item.sql`           | Add equipment to an eligible request                |
| `09_submit_repair.sql`              | Submit repair work for inspection                   |
| `10_start_action.sql`               | Start a corrective action                           |
| `11_resolve_action.sql`             | Resolve a corrective action                         |
| `12_verify_action.sql`              | Verify a resolved action                            |

Use the Python operation runner and its documented JSON inputs.
The templates contain Python-style placeholders and are not intended to be
executed directly as complete files in DBeaver.

Inspect the runner's command-line options with:

```bash
python operations/run_operation.py --help
```

The operation runner supports rollback preview and explicit commit.
Use IDs returned by committed operations for subsequent committed steps;
do not rely on IDs allocated during previews.

## 9. Automated Tests

### 9.1 Discover Tests Without Executing Them

```bash
python tools/run_sql_tests.py --list
```

The current suite is expected to discover:

```text
93 SQL files
95 cases
```

Every SQL test file must have matching metadata. Missing files, missing
registrations, or duplicate Test IDs cause discovery to fail.

### 9.2 Execute the Suite

```bash
python tools/run_sql_tests.py \
  --host 127.0.0.1 \
  --port 3306 \
  --user root \
  --database comp2411_test_rebuild
```

The runner prompts for:

1. The exact disposable database name.
2. The MySQL password.

### 9.3 Coverage


| Group          | Cases | Coverage                                                          |
| -------------- | ----: | ----------------------------------------------------------------- |
| Original suite |    45 | Positive SQL, constraints, transactions, and operation workflows  |
| BB             |    28 | Empty-string and space-only text rejection                        |
| BT             |    12 | Amounts, sequence numbers, dates, state fields, and NULL handling |
| BD             |    10 | Operation date boundaries and quotation amount boundaries         |
| Total          |    95 | Combined suite                                                    |

The workflow tests include:

- Quotation issue, revision, acceptance, and version retention.
- Legal receipt after quotation acceptance.
- A completed PASS inspection.
- FAIL, rework, and second-round PASS with history retention.
- Multi-item return and final request closure.
- Corrective-action creation, lifecycle, invalid transitions, and shared links.
- Partial-operation failure and rollback verification.

### 9.4 Failure and Transaction Behaviour

The runner continues to the next SQL file after recording a test failure.

Within an individual SQL file or dependent workflow, unexpected failure stops
that file's remaining work and invokes the existing cleanup logic.

Each test file uses a separate connection. Isolated tests compare snapshots
and roll back their fixtures. Transaction demonstration tests intentionally
include committed data.

The final exit status is:

- `0`: all planned cases executed and passed.
- `1`: one or more cases failed, or execution was incomplete.

Discovery errors and a rejected database-name confirmation prevent the
normal test run from starting.

## 10. Test Evidence

Each execution produces a timestamped directory under:

```text
evidence/automated_runs/
```

The directory contains:

- `test_cases.csv`
- `run_log.json`

The evidence records case results, SQL events or operation traces, errors,
verification results, and applicable snapshot comparisons.

The verified suite reached:

```text
95 PASS
0 FAIL
```

Schema rebuild results were subsequently reported as reproducible after
correcting an incomplete copy of the schema file.

Retain the actual CSV and JSON from the rebuild run as its evidence.
Do not treat a result from another database or an earlier execution as proof
of the current rebuild.

Automated test success does not by itself validate all business-query
outputs, query performance, or optional UI integration.

## 11. Business Queries

Reporting uses the fixed reference date:

```text
2026-10-31
```


| Query | Business Question                                                                             |
| ----- | --------------------------------------------------------------------------------------------- |
| Q01   | First-round inspection failure rates by component type                                        |
| Q02   | First-round inspection failure counts and rates by technician                                 |
| Q03   | Overdue corrective actions that have not been verified                                        |
| Q04   | Equipment received for repair more than once                                                  |
| Q05   | Overdue unverified actions whose days overdue exceed their population average                 |
| Q06   | Medium/high-severity incidents missing a corrective-action link                               |
| Q07   | Unresolved action counts by technician, including zero counts                                 |
| Q08   | Currently open repeat-repair jobs associated with qualifying earlier failed first inspections |

For Q08, the earlier job must be closed and returned before the current
request date. A repeat-repair association does not establish causation.

Final query evidence should include:

- Query ID and business purpose.
- SQL technique mapping.
- Verified result CSV.
- Reporting date and relevant interpretation.
- Any known limitations.

Query correctness and final CSV verification are separate from the
95-case operational test result.

## 12. Additional Index

`sql/04_indexes.sql` defines:

```sql
CREATE INDEX idx_corrective_action_due_date
    ON CorrectiveAction (due_date);
```

This index is maintained separately from the baseline table definitions.

Its intended reporting use concerns due-date filtering, particularly Q03.
Final justification should include the actual query and EXPLAIN evidence.

Do not assume the optimizer uses an index simply because it exists, or claim
a measured performance improvement without measurements.

## 13. Known Limitations

- The tests cover documented cases, not every possible database mutation.
- Operation-template integration tests are not complete CLI end-to-end tests.
- The supplied inspection operation creates one meaningful criterion result
  per new inspection.
- Whitespace boundary cases cover empty strings and ordinary spaces, not
  all Unicode whitespace characters.
- Shared-action applicability remains a business judgement.
- Concurrent-user race conditions are outside the stated project scope.
- An optional UI is not a substitute for SQL and database evidence.
- Reporting baselines must be verified independently using clean seed data.

## 14. Submission and Reproducibility Checklist

- [X]  The complete schema creates all twelve tables in an empty database.
- [X]  Seed data loads without manual repairs.
- [X]  Views and additional indexes build successfully.
- [ ]  Q01–Q08 results are verified and exported before test mutations.
- [X]  The rebuilt database passes all 95 automated cases.
- [X]  CSV and JSON from that rebuild run are retained.
- [ ]  Index justification includes EXPLAIN evidence.
- [X]  Requirements, operations, and Test IDs are traceable.
- [ ]  Implementation changes from the proposal are documented.
- [ ]  `ai_usage.md` reflects the assistance used and verification performed.
- [X]  No credentials or real customer data are committed.

## 15. AI Assistance

AI assistance was used during development and documentation.
See `ai_usage.md` for the recorded scope, generated material, corrections,
and verification.

Generated code and documentation are reviewed against the implemented
database and actual execution evidence. Test outcomes are recorded from
real runs rather than assigned in advance.
