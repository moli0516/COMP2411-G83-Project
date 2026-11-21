# COMP2411 — Hardware Repair Centre Database

A MySQL database project for managing hardware repair requests, quotation
versions, repair jobs, inspections, incidents, corrective actions, and returns.

The implementation includes twelve related tables, synthetic seed data, reporting
views, eight business queries, parameterized SQL operations, automated SQL tests,
and an optional local WebUI.

## 1. Scope

The database supports:

* Customer records and equipment ownership.
* Service requests containing equipment items.
* Request-level quotation versions and acceptance.
* Receipt after quotation acceptance, with at most one job per request item.
* Technician assignment, repair submission, rework, and inspection history.
* Inspection-level outcomes and criterion-level results.
* Incidents linked to corrective actions, including shared actions.
* Corrective-action resolution and managerial verification.
* Equipment return and conditional request closure.
* Management reporting on inspection performance, repeat repairs,
  corrective-action follow-up, and technician workload.

Payments, inventory and procurement, production authentication and authorization,
and concurrent-user workflow coordination are outside the implemented scope.
The optional WebUI is a local execution aid, not a production deployment.

## 2. Requirements

The recorded development environment used:

* MySQL Community Server 8.4.11.
* Python 3.13 for the operation and test tooling.
* The MySQL command-line client or a SQL client such as DBeaver.
* Python dependencies for the selected tooling.

The SQL test runner imports `mysql.connector` and `sqlparse`.
Browser regression additionally requires Playwright and Chromium; see the
regression tooling under `tools/regression/` for its configuration.

Use dedicated, disposable databases for tests and regression runs. Some tests
intentionally commit synthetic fixtures. Do not run them against valuable data.

## 3. Repository Structure


| Path                                       | Purpose                                                           |
| ------------------------------------------ | ----------------------------------------------------------------- |
| `sql/01_schema.sql`                        | Tables, keys, and CHECK constraints                               |
| `sql/02_data.sql`                          | Synthetic construction seed                                       |
| `sql/03_views.sql`                         | Reporting views                                                   |
| `sql/04_indexes.sql`                       | Additional due-date reporting index                               |
| `queries/Q01.sql`–`Q08.sql`               | Eight business queries                                            |
| `operations/`                              | Parameterized SQL templates and operation runner                  |
| `tests/`                                   | SQL tests and test metadata                                       |
| `tests/metadata.json`                      | Test registration and expected outcomes                           |
| `tools/run_sql_tests.py`                   | Automated SQL test runner                                         |
| `tools/configure_tests.py`                 | Test-metadata configuration utility                               |
| `tools/boundary_coverage.csv`              | Boundary-test traceability                                        |
| `tools/benchmark/`                         | Synthetic index-benchmark tooling                                 |
| `tools/regression/`                        | Optional WebUI regression tooling                                 |
| `webui/`                                   | Optional local interface                                          |
| `evidence/query_map.csv`                   | Query purposes, techniques, and output-file mapping               |
| `evidence/query_results/`                  | Retained clean-seed query CSVs                                    |
| `evidence/test_cases.csv`                  | Selected final SQL-suite case outcomes                            |
| `evidence/run_log.json`                    | Selected final SQL-suite execution record                         |
| `evidence/automated_runs/`                 | Timestamped SQL-suite run records                                 |
| `evidence/index_benchmark/seed_like/`      | Selected seed-like benchmark evidence                             |
| `evidence/index_benchmark/selective_like/` | Selected selective benchmark evidence                             |
| `webui_regression/api/`                    | Selected API/MySQL regression evidence                            |
| `webui_regression/broswer/`                | Selected browser regression evidence; existing directory spelling |
| `docs/index_benchmark.md`                  | Benchmark method and execution instructions                       |
| `ai_usage.md`                              | Recorded AI assistance and verification                           |

The paths above reflect the repository layout checked at commit
`bb0420c5920d0e0ddee453181dffe033d3d4f344`.
In particular, `selective_like` and `broswer` are the existing directory names,
not alternative scenario definitions. If evidence is subsequently renamed or
moved, update this README and the report references together.

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

## Main relationships

* A customer owns equipment and submits service requests.
* `RequestItem` connects equipment to service requests.
* A request may retain multiple quotation versions.
* A request item has zero or one service job.
* A job may have multiple inspection rounds and incidents.
* An inspection may have multiple criterion-result rows.
* `IncidentCorrectiveAction` implements a many-to-many relationship between
  incidents and corrective actions.
* Staff references identify responsibility, inspection, reporting, assignment,
  return handling, and verification.

Foreign keys do not require parent records to have children. For example, the
schema permits a request without items or an inspection without result rows.
Minimum-child and workflow requirements must be distinguished from the
structural guarantees provided by the DDL.

Equipment identity is separate from repair history. A repeat repair is represented
through another request item and job for the same equipment, rather than by
reopening a closed job.

## 5. Environment Setup

Run these commands from the project root in a POSIX shell:

<pre class="not-prose w-full rounded font-mono text-sm font-light m-0"><figure class="relative flex w-full min-w-0 flex-col rounded-lg border border-soft bg-subtle font-mono font-medium text-primary selection:bg-super-soft selection:text-super-primary [&_.token.deleted]:!text-negative-primary [&_.token.inserted]:!text-positive-primary text-xs"><figcaption class="flex min-h-7 items-center justify-between gap-2 overflow-hidden rounded-t-lg pl-2 pr-1 pt-1 text-xs text-secondary"><span>bash</span><div class="ml-auto flex items-center gap-2"><button aria-label="Wrap lines" tabindex="0" aria-pressed="false" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0 aria-pressed:text-super-primary aria-pressed:bg-super-soft aria-pressed:enabled:hover:bg-super-soft aria-pressed:enabled:hover:text-super-primary"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-text-wrap"></use></svg></button><button aria-label="Copy code" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0"><div class="relative flex items-center justify-center"><div class="inline-flex"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-copy"></use></svg></div><div class="absolute inset-0 flex items-center justify-center"></div></div></button></div></figcaption><div class="[&_.token]:[all:unset] overflow-hidden rounded-b-lg"><span><code><span>python3.13 -m venv .venv
</span><span></span><span class="token token">source</span><span> .venv/bin/activate
</span>
<span>python -m pip </span><span class="token token">install</span><span> --upgrade pip
</span><span>python -m pip </span><span class="token token">install</span><span> -r operations/requirements.txt
</span><span>python -m pip </span><span class="token token">install</span><span> mysql-connector-python sqlparse</span></code></span></div></figure></pre>

On Windows PowerShell, activate the environment with:

<pre class="not-prose w-full rounded font-mono text-sm font-light m-0"><figure class="relative flex w-full min-w-0 flex-col rounded-lg border border-soft bg-subtle font-mono font-medium text-primary selection:bg-super-soft selection:text-super-primary [&_.token.deleted]:!text-negative-primary [&_.token.inserted]:!text-positive-primary text-xs"><figcaption class="flex min-h-7 items-center justify-between gap-2 overflow-hidden rounded-t-lg pl-2 pr-1 pt-1 text-xs text-secondary"><span>powershell</span><div class="ml-auto flex items-center gap-2"><button aria-label="Wrap lines" tabindex="0" aria-pressed="false" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0 aria-pressed:text-super-primary aria-pressed:bg-super-soft aria-pressed:enabled:hover:bg-super-soft aria-pressed:enabled:hover:text-super-primary"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-text-wrap"></use></svg></button><button aria-label="Copy code" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0"><div class="relative flex items-center justify-center"><div class="inline-flex"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-copy"></use></svg></div><div class="absolute inset-0 flex items-center justify-center"></div></div></button></div></figcaption><div class="[&_.token]:[all:unset] overflow-hidden rounded-b-lg"><span><code><span class="token token punctuation">.</span><span>venv\Scripts\Activate</span><span class="token token punctuation">.</span><span>ps1</span></code></span></div></figure></pre>

Enter database credentials when prompted. Do not commit passwords or place
password values directly in command-line arguments. In the MySQL examples below,
`--password` without a value requests an interactive prompt.

## 6. Clean Database Construction

## 6.1 Create an empty database

Using an account with the necessary privileges:

<pre class="not-prose w-full rounded font-mono text-sm font-light m-0"><figure class="relative flex w-full min-w-0 flex-col rounded-lg border border-soft bg-subtle font-mono font-medium text-primary selection:bg-super-soft selection:text-super-primary [&_.token.deleted]:!text-negative-primary [&_.token.inserted]:!text-positive-primary text-xs"><figcaption class="flex min-h-7 items-center justify-between gap-2 overflow-hidden rounded-t-lg pl-2 pr-1 pt-1 text-xs text-secondary"><span>sql</span><div class="ml-auto flex items-center gap-2"><button aria-label="Wrap lines" tabindex="0" aria-pressed="false" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0 aria-pressed:text-super-primary aria-pressed:bg-super-soft aria-pressed:enabled:hover:bg-super-soft aria-pressed:enabled:hover:text-super-primary"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-text-wrap"></use></svg></button><button aria-label="Copy code" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0"><div class="relative flex items-center justify-center"><div class="inline-flex"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-copy"></use></svg></div><div class="absolute inset-0 flex items-center justify-center"></div></div></button></div></figcaption><div class="[&_.token]:[all:unset] overflow-hidden rounded-b-lg"><span><code><span class="token token">CREATE</span><span> </span><span class="token token">DATABASE</span><span> comp2411_test_rebuild
</span><span>    </span><span class="token token">CHARACTER</span><span> </span><span class="token token">SET</span><span> utf8mb4
</span><span>    </span><span class="token token">COLLATE</span><span> utf8mb4_0900_ai_ci</span><span class="token token punctuation">;</span></code></span></div></figure></pre>

If this database already contains tables, select a different empty database.
The construction scripts are a clean-build baseline, not incremental migrations.
The schema script does not create or select a database.

## 6.2 Execute all four scripts in order

<pre class="not-prose w-full rounded font-mono text-sm font-light m-0"><figure class="relative flex w-full min-w-0 flex-col rounded-lg border border-soft bg-subtle font-mono font-medium text-primary selection:bg-super-soft selection:text-super-primary [&_.token.deleted]:!text-negative-primary [&_.token.inserted]:!text-positive-primary text-xs"><figcaption class="flex min-h-7 items-center justify-between gap-2 overflow-hidden rounded-t-lg pl-2 pr-1 pt-1 text-xs text-secondary"><span>text</span><div class="ml-auto flex items-center gap-2"><button aria-label="Wrap lines" tabindex="0" aria-pressed="false" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0 aria-pressed:text-super-primary aria-pressed:bg-super-soft aria-pressed:enabled:hover:bg-super-soft aria-pressed:enabled:hover:text-super-primary"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-text-wrap"></use></svg></button><button aria-label="Copy code" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0"><div class="relative flex items-center justify-center"><div class="inline-flex"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-copy"></use></svg></div><div class="absolute inset-0 flex items-center justify-center"></div></div></button></div></figcaption><div class="[&_.token]:[all:unset] overflow-hidden rounded-b-lg"><span><code><span>sql/01_schema.sql
</span>    → sql/02_data.sql
    → sql/03_views.sql
    → sql/04_indexes.sql</code></span></div></figure></pre>

In DBeaver, select the new database and execute each complete script in order.
Do not omit the final `IncidentCorrectiveAction` table definition.

Alternatively, use the MySQL command-line client from the project root:

<pre class="not-prose w-full rounded font-mono text-sm font-light m-0"><figure class="relative flex w-full min-w-0 flex-col rounded-lg border border-soft bg-subtle font-mono font-medium text-primary selection:bg-super-soft selection:text-super-primary [&_.token.deleted]:!text-negative-primary [&_.token.inserted]:!text-positive-primary text-xs"><figcaption class="flex min-h-7 items-center justify-between gap-2 overflow-hidden rounded-t-lg pl-2 pr-1 pt-1 text-xs text-secondary"><span>bash</span><div class="ml-auto flex items-center gap-2"><button aria-label="Wrap lines" tabindex="0" aria-pressed="false" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0 aria-pressed:text-super-primary aria-pressed:bg-super-soft aria-pressed:enabled:hover:bg-super-soft aria-pressed:enabled:hover:text-super-primary"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-text-wrap"></use></svg></button><button aria-label="Copy code" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0"><div class="relative flex items-center justify-center"><div class="inline-flex"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-copy"></use></svg></div><div class="absolute inset-0 flex items-center justify-center"></div></div></button></div></figcaption><div class="[&_.token]:[all:unset] overflow-hidden rounded-b-lg"><span><code><span>mysql --host</span><span class="token token operator">=</span><span class="token token">127.0</span><span>.0.1 --port</span><span class="token token operator">=</span><span class="token token">3306</span><span> --user</span><span class="token token operator">=</span><span>root --password </span><span class="token token punctuation">\</span><span>
</span><span>  comp2411_test_rebuild </span><span class="token token operator"><</span><span> sql/01_schema.sql
</span>
<span>mysql --host</span><span class="token token operator">=</span><span class="token token">127.0</span><span>.0.1 --port</span><span class="token token operator">=</span><span class="token token">3306</span><span> --user</span><span class="token token operator">=</span><span>root --password </span><span class="token token punctuation">\</span><span>
</span><span>  comp2411_test_rebuild </span><span class="token token operator"><</span><span> sql/02_data.sql
</span>
<span>mysql --host</span><span class="token token operator">=</span><span class="token token">127.0</span><span>.0.1 --port</span><span class="token token operator">=</span><span class="token token">3306</span><span> --user</span><span class="token token operator">=</span><span>root --password </span><span class="token token punctuation">\</span><span>
</span><span>  comp2411_test_rebuild </span><span class="token token operator"><</span><span> sql/03_views.sql
</span>
<span>mysql --host</span><span class="token token operator">=</span><span class="token token">127.0</span><span>.0.1 --port</span><span class="token token operator">=</span><span class="token token">3306</span><span> --user</span><span class="token token operator">=</span><span>root --password </span><span class="token token punctuation">\</span><span>
</span><span>  comp2411_test_rebuild </span><span class="token token operator"><</span><span> sql/04_indexes.sql</span></code></span></div></figure></pre>

Check each execution for errors before continuing. Replace the example user and
database name as appropriate. Do not repeatedly load the seed into populated tables.

## 6.3 Verify the selected database and tables

<pre class="not-prose w-full rounded font-mono text-sm font-light m-0"><figure class="relative flex w-full min-w-0 flex-col rounded-lg border border-soft bg-subtle font-mono font-medium text-primary selection:bg-super-soft selection:text-super-primary [&_.token.deleted]:!text-negative-primary [&_.token.inserted]:!text-positive-primary text-xs"><figcaption class="flex min-h-7 items-center justify-between gap-2 overflow-hidden rounded-t-lg pl-2 pr-1 pt-1 text-xs text-secondary"><span>sql</span><div class="ml-auto flex items-center gap-2"><button aria-label="Wrap lines" tabindex="0" aria-pressed="false" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0 aria-pressed:text-super-primary aria-pressed:bg-super-soft aria-pressed:enabled:hover:bg-super-soft aria-pressed:enabled:hover:text-super-primary"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-text-wrap"></use></svg></button><button aria-label="Copy code" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0"><div class="relative flex items-center justify-center"><div class="inline-flex"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-copy"></use></svg></div><div class="absolute inset-0 flex items-center justify-center"></div></div></button></div></figcaption><div class="[&_.token]:[all:unset] overflow-hidden rounded-b-lg"><span><code><span class="token token">SELECT</span><span> </span><span class="token token">DATABASE</span><span class="token token punctuation">(</span><span class="token token punctuation">)</span><span class="token token punctuation">;</span><span>
</span>
<span></span><span class="token token">SELECT</span><span> TABLE_NAME
</span><span></span><span class="token token">FROM</span><span> information_schema</span><span class="token token punctuation">.</span><span class="token token">TABLES</span><span>
</span><span></span><span class="token token">WHERE</span><span> TABLE_SCHEMA </span><span class="token token operator">=</span><span> </span><span class="token token">DATABASE</span><span class="token token punctuation">(</span><span class="token token punctuation">)</span><span>
</span><span>  </span><span class="token token operator">AND</span><span> TABLE_TYPE </span><span class="token token operator">=</span><span> </span><span class="token token">'BASE TABLE'</span><span>
</span><span></span><span class="token token">ORDER</span><span> </span><span class="token token">BY</span><span> TABLE_NAME</span><span class="token token punctuation">;</span></code></span></div></figure></pre>

Confirm that all twelve tables listed in Section 4 exist.

## 6.4 Capture query baselines before mutation tests

After construction:

1. Execute `queries/Q01.sql` through `queries/Q08.sql`.
2. Verify the query definitions and results.
3. Export the clean-seed result CSVs.
4. Run mutation tests only afterwards, or use a separate database.

A database containing committed test or WebUI fixtures is not the clean
construction baseline. Do not use it to regenerate seed-only reporting evidence.

## 6.5 Restore the baseline

Stop testing, create a new empty dedicated database, and rerun the four
construction scripts in order. Rollback does not remove fixtures that were
previously committed. Do not treat rerunning the seed over populated tables
as a restoration procedure.

## 7. Integrity and Enforcement Boundaries

## Schema-level guarantees

The DDL defines primary and foreign keys, additional unique keys, domain checks,
nonblank-text checks, and state-dependent field requirements. Examples include:

* Unique equipment serial numbers.
* Unique request–equipment pairs and quotation versions per request.
* At most one job per request item.
* Unique inspection rounds per job and criteria per inspection.
* Positive quotation amounts, quotation versions, and inspection rounds.
* Required completion values for completed inspections.
* Required return details for closed jobs.
* Corrective-action date and state-field consistency.

Nullable descriptions remain nullable where allowed. Nonblank checks reject
empty or ordinary space-only values when those descriptions are supplied;
separate state constraints determine when a value is required.

## Controlled-operation validations

The supplied operations validate rules requiring cross-record comparisons or
workflow context, including ownership, quotation acceptance before receipt,
staff eligibility, inspector separation, selected date boundaries, permitted
transitions, and request-closure conditions.

Arbitrary direct SQL may bypass these validations. A Staff foreign key proves
that a staff record exists, not that its role is appropriate. A status-domain
CHECK restricts allowed values, not every permitted transition.

## Explicit limitations

* `Staff.active_status` uses `TINYINT(1)` without an explicit 0/1 CHECK.
* Operation-level date checks must not be described as general schema guarantees.
* Both submitted inspection-completion CHECKs are retained; the stronger check
  explicitly rejects a NULL final result for a completed inspection.
* Referential integrity does not establish whether a shared corrective action
  adequately addresses every linked incident.

## 8. Business Operations


| SQL file under`operations/`         | Purpose                                              |
| ----------------------------------- | ---------------------------------------------------- |
| `01_request_registration.sql`       | Register a request                                   |
| `02_quotation_acceptance.sql`       | Accept a quotation                                   |
| `03_receive_item.sql`               | Receive an item and create its job                   |
| `04_inspection.sql`                 | Record a completed inspection                        |
| `05_incident_corrective_action.sql` | Create an incident, action, and link                 |
| `06_return_and_closure.sql`         | Return equipment and conditionally close its request |
| `07_issue_quotation.sql`            | Issue or revise a quotation                          |
| `08_add_request_item.sql`           | Add equipment to an eligible request                 |
| `09_submit_repair.sql`              | Submit repair work for inspection                    |
| `10_start_action.sql`               | Start a corrective action                            |
| `11_resolve_action.sql`             | Resolve a corrective action                          |
| `12_verify_action.sql`              | Verify a resolved action                             |

The templates use Python-style placeholders. They are not standalone scripts
for direct execution as complete files in DBeaver. Use the operation runner and
its documented JSON inputs:

<pre class="not-prose w-full rounded font-mono text-sm font-light m-0"><figure class="relative flex w-full min-w-0 flex-col rounded-lg border border-soft bg-subtle font-mono font-medium text-primary selection:bg-super-soft selection:text-super-primary [&_.token.deleted]:!text-negative-primary [&_.token.inserted]:!text-positive-primary text-xs"><figcaption class="flex min-h-7 items-center justify-between gap-2 overflow-hidden rounded-t-lg pl-2 pr-1 pt-1 text-xs text-secondary"><span>bash</span><div class="ml-auto flex items-center gap-2"><button aria-label="Wrap lines" tabindex="0" aria-pressed="false" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0 aria-pressed:text-super-primary aria-pressed:bg-super-soft aria-pressed:enabled:hover:bg-super-soft aria-pressed:enabled:hover:text-super-primary"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-text-wrap"></use></svg></button><button aria-label="Copy code" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0"><div class="relative flex items-center justify-center"><div class="inline-flex"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-copy"></use></svg></div><div class="absolute inset-0 flex items-center justify-center"></div></div></button></div></figcaption><div class="[&_.token]:[all:unset] overflow-hidden rounded-b-lg"><span><code><span>python operations/run_operation.py --help</span></code></span></div></figure></pre>

The runner supports rollback preview and explicit commit. Use identifiers from
committed operations for subsequent committed steps; preview-allocated IDs must
not be treated as persisted records.

A failed statement does not, by itself, prove that earlier writes in the same
transaction were undone. Failure handling must explicitly roll back the relevant
transaction and verify the resulting state.

## 9. Automated SQL Tests

## Discover registered tests

<pre class="not-prose w-full rounded font-mono text-sm font-light m-0"><figure class="relative flex w-full min-w-0 flex-col rounded-lg border border-soft bg-subtle font-mono font-medium text-primary selection:bg-super-soft selection:text-super-primary [&_.token.deleted]:!text-negative-primary [&_.token.inserted]:!text-positive-primary text-xs"><figcaption class="flex min-h-7 items-center justify-between gap-2 overflow-hidden rounded-t-lg pl-2 pr-1 pt-1 text-xs text-secondary"><span>bash</span><div class="ml-auto flex items-center gap-2"><button aria-label="Wrap lines" tabindex="0" aria-pressed="false" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0 aria-pressed:text-super-primary aria-pressed:bg-super-soft aria-pressed:enabled:hover:bg-super-soft aria-pressed:enabled:hover:text-super-primary"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-text-wrap"></use></svg></button><button aria-label="Copy code" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0"><div class="relative flex items-center justify-center"><div class="inline-flex"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-copy"></use></svg></div><div class="absolute inset-0 flex items-center justify-center"></div></div></button></div></figcaption><div class="[&_.token]:[all:unset] overflow-hidden rounded-b-lg"><span><code><span>python tools/run_sql_tests.py --list</span></code></span></div></figure></pre>

The retained final suite comprises 93 SQL files and 95 cases. SQL test files
must have matching metadata; missing registrations, missing files, or duplicate
Test IDs cause discovery to fail.

## Execute the suite

<pre class="not-prose w-full rounded font-mono text-sm font-light m-0"><figure class="relative flex w-full min-w-0 flex-col rounded-lg border border-soft bg-subtle font-mono font-medium text-primary selection:bg-super-soft selection:text-super-primary [&_.token.deleted]:!text-negative-primary [&_.token.inserted]:!text-positive-primary text-xs"><figcaption class="flex min-h-7 items-center justify-between gap-2 overflow-hidden rounded-t-lg pl-2 pr-1 pt-1 text-xs text-secondary"><span>bash</span><div class="ml-auto flex items-center gap-2"><button aria-label="Wrap lines" tabindex="0" aria-pressed="false" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0 aria-pressed:text-super-primary aria-pressed:bg-super-soft aria-pressed:enabled:hover:bg-super-soft aria-pressed:enabled:hover:text-super-primary"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-text-wrap"></use></svg></button><button aria-label="Copy code" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0"><div class="relative flex items-center justify-center"><div class="inline-flex"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-copy"></use></svg></div><div class="absolute inset-0 flex items-center justify-center"></div></div></button></div></figcaption><div class="[&_.token]:[all:unset] overflow-hidden rounded-b-lg"><span><code><span>python tools/run_sql_tests.py </span><span class="token token punctuation">\</span><span>
</span><span>  --host </span><span class="token token">127.0</span><span>.0.1 </span><span class="token token punctuation">\</span><span>
</span><span>  --port </span><span class="token token">3306</span><span> </span><span class="token token punctuation">\</span><span>
</span><span>  --user root </span><span class="token token punctuation">\</span><span>
</span>  --database comp2411_test_rebuild</code></span></div></figure></pre>

The runner prompts for the exact disposable database name and MySQL password.
No concurrent writers should use the database during snapshot-based tests.

## Coverage and counting


| Reporting category                | Cases | Retained result |
| --------------------------------- | ----- | --------------- |
| Positive operations and workflows | 14    | All PASS        |
| Negative and boundary cases       | 79    | All PASS        |
| Transaction demonstrations        | 2     | All PASS        |
| Total                             | 95    | 95 PASS; 0 FAIL |

Each case is counted once. Negative and boundary coverage includes both accepted
boundary values and expected rejections. An expected error counts as PASS only
when the required rejection and state checks match the expectation.

The suite covers quotation history, receipt, inspection completion, rework and
reinspection, returns, corrective-action lifecycles, shared links, nonblank text,
NULL boundaries, and selected operation-date boundaries.

`TXC01` demonstrates explicit commit. `TXR01` demonstrates explicit rollback after
a deliberate duplicate-job failure. `IA02` tests partial-operation failure and
rollback; it is included in the negative and boundary category, not counted again
as a third transaction demonstration.

## Execution behavior

The runner records failures and continues to the next SQL file. Unexpected
failure within a file or dependent workflow stops that file's remaining work
and invokes its cleanup logic. Each SQL test file uses a separate connection.
Isolated tests use snapshot comparisons and rollback; transaction demonstrations
intentionally include committed fixtures.

* Exit status `0`: all planned cases executed and passed.
* Exit status `1`: one or more cases failed, or execution was incomplete.

Discovery errors and rejected database-name confirmation prevent a normal run
from starting.

## 10. Retained Test Evidence

The SQL runner writes timestamped output under `evidence/automated_runs/`.
The selected final evidence is also retained at:

* [`evidence/test_cases.csv`](evidence/test_cases.csv)
* [`evidence/run_log.json`](evidence/run_log.json)

These selected files correspond to the original run directory
`20261117T021159487358Z/`, targeting `comp2411_test_rebuild_2` on MySQL 8.4.11.
The retained result is 95 PASS and 0 FAIL, with an empty `not_run` list.

The CSV contains case outcomes. The JSON records execution details, SQL events
or operation traces, errors, verification results, and applicable snapshot checks.
Test definitions are registered in `tests/metadata.json`.

These are records of the identified execution, not a claim that every subsequent
repository snapshot was retested. Moving evidence files or editing documentation
does not constitute a new test run. Preserve original execution metadata when
repackaging evidence.

SQL-suite outcomes, clean-seed query outputs, WebUI regression results, and
synthetic benchmark measurements are separate evidence sets. They must not be
combined into a single test count or treated as one database population.

## 11. Management Questions and Business Queries

The final report groups the queries as follows:


| Management question | Information need                                      | Supporting queries |
| ------------------- | ----------------------------------------------------- | ------------------ |
| MQ01                | First-round inspection performance                    | Q01, Q02           |
| MQ02                | Repeat repairs                                        | Q04, Q08           |
| MQ03                | Corrective-action follow-up and missing-link auditing | Q03, Q05, Q06      |
| MQ04                | Technician unresolved-action workload                 | Q07                |

The current `evidence/query_map.csv` retains legacy MQ labels in its
`business_question` column. The table above states the final report grouping;
Q01–Q08 are the stable identifiers linking SQL files and result CSVs. The legacy
MQ labels should not be interpreted as a different query implementation.


| Query | Purpose                                                                      | Retained clean-seed result                              |
| ----- | ---------------------------------------------------------------------------- | ------------------------------------------------------- |
| Q01   | First-round failures by component type                                       | 7 groups; 71 inspected jobs and 30 failed jobs in total |
| Q02   | First-round performance by responsible technician                            | 7 technicians; same 71-job population                   |
| Q03   | Overdue unverified actions                                                   | 10 actions: 8 RESOLVED and 2 IN\_PROGRESS               |
| Q04   | Equipment received for repair more than once                                 | 14 equipment items                                      |
| Q05   | Overdue unverified actions exceeding the population average overdue duration | 5 actions; population average 11 days                   |
| Q06   | Medium/high-severity incidents without an action link                        | 0 rows                                                  |
| Q07   | Unresolved actions by technician, including zero counts                      | 9 technicians; 7 with 2 actions and 2 with none         |
| Q08   | Open repeat-repair jobs with qualifying earlier inspection failures          | 13 jobs                                                 |

SQL is retained in `queries/Q01.sql`–`Q08.sql`; baseline outputs are retained
in `evidence/query_results/Q01.csv`–`Q08.csv`.

## Dates and populations

* Q01 and Q02 use completed first-round inspections dated from `2026-03-01`
  to `2026-10-31`, inclusive.
* Q03 and Q05 use `2026-10-31` as the overdue reference date. An action due on
  that date is not overdue.
* Q04, Q06, Q07, and Q08 apply their own conditions without a universal
  reporting-date cutoff.
* Q03 and Q05 include RESOLVED actions awaiting verification. Q07 instead
  counts only OPEN and IN\_PROGRESS actions.
* Q07 retains technicians with zero unresolved actions, including inactive
  technicians present in the staff records.

## Interpretation boundaries

Q01 and Q02 use inspection-level `overall_result`. Q08 uses a different
condition: the current job is open, and an earlier job for the same equipment
was closed and returned before the current request date, with at least one
FAIL criterion in a completed first-round inspection. This is criterion-level
failure, not a test of the earlier inspection's `overall_result`.

Repeat-repair associations do not establish causation. Failure rates should be
read with their denominators and are not adjusted measures of technician
performance. Q07 counts assignments, not task complexity or total staff effort.

Q06's header-only CSV represents a successful zero-row audit result for the
seed population. It does not prove that missing links are impossible.

All retained baseline findings describe synthetic data, not measured performance
of a real repair centre. Query-output verification is separate from the 95-case
SQL operational suite.

## 12. Additional Index and Benchmark

`sql/04_indexes.sql` defines:

<pre class="not-prose w-full rounded font-mono text-sm font-light m-0"><figure class="relative flex w-full min-w-0 flex-col rounded-lg border border-soft bg-subtle font-mono font-medium text-primary selection:bg-super-soft selection:text-super-primary [&_.token.deleted]:!text-negative-primary [&_.token.inserted]:!text-positive-primary text-xs"><figcaption class="flex min-h-7 items-center justify-between gap-2 overflow-hidden rounded-t-lg pl-2 pr-1 pt-1 text-xs text-secondary"><span>sql</span><div class="ml-auto flex items-center gap-2"><button aria-label="Wrap lines" tabindex="0" aria-pressed="false" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0 aria-pressed:text-super-primary aria-pressed:bg-super-soft aria-pressed:enabled:hover:bg-super-soft aria-pressed:enabled:hover:text-super-primary"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-text-wrap"></use></svg></button><button aria-label="Copy code" data-state="closed" type="button" class="reset interactable select-none [-webkit-user-drag:none] outline-hidden font-medium transition-[background-color,border-color,color,opacity] duration-300 ease-out font-sans text-center items-center justify-center leading-loose whitespace-nowrap disabled:cursor-default disabled:opacity-50 data-[state=open]:text-primary data-[state=open]:bg-soft h-6 text-xs cursor-pointer inline-flex rounded-full aspect-square aspect-[9/8] text-secondary hover:text-primary hover:bg-soft p-0"><div class="relative flex items-center justify-center"><div class="inline-flex"><svg role="img" class="inline-flex fill-current shrink-0" width="14" height="14" stroke-width="1.75" aria-hidden="true"><use xlink:href="#pplx-icon-copy"></use></svg></div><div class="absolute inset-0 flex items-center justify-center"></div></div></button></div></figcaption><div class="[&_.token]:[all:unset] overflow-hidden rounded-b-lg"><span><code><span class="token token">CREATE</span><span> </span><span class="token token">INDEX</span><span> idx_corrective_action_due_date
</span><span>    </span><span class="token token">ON</span><span> CorrectiveAction </span><span class="token token punctuation">(</span><span>due_date</span><span class="token token punctuation">)</span><span class="token token punctuation">;</span></code></span></div></figure></pre>

The index provides a possible range-access path for Q03's due-date predicate.
It does not include `action_status` or cover the complete query. Availability
does not guarantee that the optimizer will select it.

The method and execution instructions are documented in
[`docs/index_benchmark.md`](docs/index_benchmark.md). Chapter 7 of the report
interprets the retained plans and measurements.

## Recorded synthetic comparison

Both scenarios contained 100,000 corrective actions on MySQL 8.4.11.


| Measurement                                       | Seed-like scenario          | Selective scenario              |
| ------------------------------------------------- | --------------------------- | ------------------------------- |
| Date-matching actions                             | 71,430                      | 1,000                           |
| Q03 output rows                                   | 23,810                      | 334                             |
| Selected action-table access with index available | Full table scan             | Index range scan                |
| Median with index unavailable                     | 65.567 ms                   | 33.732 ms                       |
| Median with index available                       | 65.767 ms                   | 4.668 ms                        |
| Interpretation                                    | No demonstrated improvement | Approximately 7.23-fold speedup |

The comparison changed index visibility, with `use_invisible_indexes=off`;
it did not physically remove the index. Each condition received three warm-up
executions followed by ten measured executions, with alternating condition order.
Timings included execution and complete result fetching, excluding plan capture
and index-visibility changes. Result signatures matched between conditions.

Selected evidence is retained in:

* `evidence/index_benchmark/seed_like/`
* `evidence/index_benchmark/selective_like/`

Each directory contains `run_log.json`, `timings.csv`, the two EXPLAIN JSON files,
and the two EXPLAIN ANALYZE text files. The original measurement-directory
identifiers were `20261118T155314941941Z` and `20261118T155406958925Z`, respectively.
The measurement logs record commit
`a90bcc3eece981ca6ae90a10243218c6b3dae412`.

## Limitations

The selective benefit applies to the tested synthetic distribution, not all Q03
workloads. A larger table alone does not guarantee index use or improvement.
These local warm-cache measurements do not establish production performance,
a cold-cache result, or the selectivity threshold at which the optimizer changes
access paths. Index storage and write-maintenance costs were not measured.
Single EXPLAIN ANALYZE executions are supporting observations, not replacements
for the repeated timing comparison.

## 13. Optional Local WebUI and Regression

The optional interface under `webui/` supports local query display/export and
operation preview/commit. Consult the interface's own documentation and tooling
for launch configuration. It does not replace the SQL construction or evidence.

Separate retained regression summaries record:


| Suite     | Coverage summary                                                                                                         | Recorded result      | Summary                                |
| --------- | ------------------------------------------------------------------------------------------------------------------------ | -------------------- | -------------------------------------- |
| API/MySQL | Q01–Q08 against direct SQL, table browsing, selected validation and preview/commit safeguards                           | 14 named checks PASS | `webui_regression/api/result.json`     |
| Browser   | Query rendering/downloads, operation controls, rollback, preview/export invalidation, and selected Chromium interactions | 14 named checks PASS | `webui_regression/broswer/result.json` |

Both summaries record commit
`a90f9303ab8c33ce45b880a0208824a199c77ca4`, `passed: true`, and `error: null`.
The API run started on 17 November 2026 at 06:24:11 UTC, followed by the browser
run at 06:25:52 UTC. Original run identifiers were
`api-20261117-062411-021720` and `browser-20261117-062552-762430`.

The browser directory also retains artifacts including `trace.zip`, `final.png`,
and `page-errors.txt`. Their availability does not extend the regression coverage
beyond the exercised interactions.

These named checks may contain multiple assertions and are not added to the
95-case SQL total. The summaries do not identify the target database. The retained
coverage is not exhaustive security, accessibility, concurrency, load, production,
mobile, or cross-browser validation. WebUI regression databases must not be used
to regenerate clean-seed submission query CSVs.

## 14. Known Limitations

* Tests cover registered scenarios, not every possible database mutation.
* Controlled-operation checks can be bypassed by arbitrary direct SQL.
* Operation-template integration tests are not complete CLI end-to-end tests.
* The supplied inspection operation creates one meaningful criterion result
  per new inspection; the schema supports multiple criterion rows.
* Whitespace boundaries cover empty strings and ordinary spaces, not every
  Unicode whitespace character.
* Shared-action suitability remains a business judgement.
* Concurrent-user workflow coordination is outside scope.
* Baseline reporting, operational testing, interface regression, and performance
  measurements require separate interpretation.
* Recorded historical results are not proof that an untested later snapshot
  has identical behavior.

## 15. Final Submission Verification

Before freezing the submission:

1. Record the final submitted commit or release identifier and actual submission
   date in the report.
2. Confirm that the four construction scripts complete in a new empty database.
3. Capture query results from clean seed data before mutation tests.
4. Identify the exact SQL run used for the reported result and retain its CSV,
   JSON, and original metadata.
5. Keep WebUI regression and benchmark evidence separate from SQL case totals.
6. Synchronize evidence paths across the repository, README, report, and package.
7. Reconcile legacy MQ labels in the query map and SQL comments with the final
   report grouping; do not change query logic merely to rename labels.
8. Check that `ai_usage.md` accurately describes assistance and verification.
9. Check the submission for credentials and unintended personal or real customer data.
10. Inspect the final exported report and presentation PDFs.

This is a verification checklist, not a declaration that every item has been
re-executed or independently audited for the current repository snapshot.

## 16. AI Assistance

AI assistance was used during development and documentation. See
[`ai_usage.md`](ai_usage.md) for the recorded scope, generated material,
corrections, and verification.

Claims about implementation behavior should be checked against the submitted
SQL and actual execution evidence. Generated code, a passing test summary, and
an author's understanding of the implementation are distinct matters; none
should be inferred solely from the others.
