# AI Usage Declaration — Stage 2

## 1. Project Information

- Course: COMP2411 Database Systems
- Stage: 2 — Implementation
- Group ID: G083
- Scenario ID: D14-W08
- Project title: Computer Hardware Repair Centre: Quality, Incident and Corrective Action Management Database
- Members:
  - Tam King Yeung Oscar — 25074264d
  - Kong Kit Hou — 25129757d

This declaration covers AI assistance used during Stage 2 implementation, testing, analysis, documentation, and presentation preparation. It supplements the Stage 1 declaration, which records assistance with the original requirements and database design.

## 2. AI Tool Used

Perplexity was used through interactive conversations to generate, revise, explain, and review project material.

Inputs included project requirements, SQL code, repository content, execution logs, query outputs, benchmark files, report drafts, screenshots, and follow-up instructions.

## 3. Purpose and Extent of Assistance

AI assistance was substantial and was not limited to proofreading or explaining independently written code.

It included generating and revising SQL and Python code, proposing test cases, interpreting execution evidence, drafting report sections, producing README content, and preparing presentation material.

AI contributed substantially to the generation and revision of the supporting Python tooling and optional WebUI. Development followed an iterative process in which the group supplied requirements, executed components, reported issues, and requested revisions.

AI also contributed technical suggestions and explanations concerning SQL behavior, constraints, workflow validation, transactions, query populations, normalization, and index evaluation. Retained material therefore includes AI-originated code, wording, and technical suggestions.

### 3.1 SQL Implementation and Data

Assistance included:

- Consolidating and reviewing construction scripts.
- Suggesting and revising keys, CHECK constraints, nullability, and state-dependent field requirements.
- Generating or revising synthetic data and fixtures.
- Reviewing reporting views and analytical queries.
- Drafting or revising controlled SQL operation templates.
- Explaining the distinction between schema constraints and operation-level validation.
- Reviewing transaction failure handling, explicit rollback, and state verification.

### 3.2 Python Tooling and Optional WebUI

Assistance included substantial code generation and revision for:

- Database construction and script execution.
- Parameterized operation execution and preview/commit handling.
- SQL test execution, result recording, and snapshot comparisons.
- Query-output export.
- Synthetic benchmark preparation and measurement.
- Optional WebUI functionality.
- API/MySQL and browser regression tooling.

The use of AI-generated supporting tools is disclosed separately from the SQL implementation. The group used execution results and observed behavior to assess and refine the generated tools. Their role was to support database construction, operation execution, testing, and demonstration.

### 3.3 Testing and Evidence Analysis

Assistance included:

- Proposing positive, negative, workflow, boundary, and transaction cases.
- Drafting test SQL and expected outcomes.
- Reviewing test metadata and coverage mappings.
- Interpreting errors, logs, snapshots, and verification queries.
- Investigating differences between clean-seed results and databases containing committed fixtures.
- Reviewing EXPLAIN and EXPLAIN ANALYZE output.
- Summarizing repeated timing measurements.
- Identifying limitations in the conclusions supported by the retained evidence.

### 3.4 Documentation and Presentation

Assistance included substantial drafting and revision of:

- The Stage 2 report.
- Business-rule and enforcement explanations.
- Schema and data-dictionary descriptions.
- Functional-dependency and normalization discussions.
- Stage 1-to-Stage 2 change descriptions.
- Requirement–implementation–test traceability tables.
- Analytical findings and limitations.
- Index-selection rationale and benchmark interpretation.
- README installation, construction, execution, and evidence instructions.
- Presentation slides and speaking material.
- This declaration.

## 4. Group Contribution and Decision-Making

The group supplied the project requirements and design decisions, executed project components, examined outputs, reported issues, and directed revisions. AI-generated code and documentation were developed through this iterative process.

The group determined which suggestions and generated material to retain, adapt, or reject, and maintained the repository and submission documents. The group remains responsible for the final implementation, the interpretation of its evidence, and the submitted work.

## 5. Affected Files and Deliverables


| File or deliverable             | Nature of AI assistance                                                                           |
| ------------------------------- | ------------------------------------------------------------------------------------------------- |
| `sql/01_schema.sql`             | Consolidation, constraint suggestions, revisions, and explanation of enforcement boundaries       |
| `sql/02_data.sql`               | Synthetic-data generation or revision and baseline consistency checking                           |
| `sql/03_views.sql`              | Reporting-view generation, revision, and explanation                                              |
| `sql/04_indexes.sql`            | Index suggestions and interpretation of its relationship to the target query                      |
| `queries/Q01.sql`–`Q08.sql`    | Query generation or revision, SQL explanations, population definitions, and result interpretation |
| `operations/`                   | SQL templates, Python runner functionality, validation, transaction handling, and documentation   |
| `tests/`                        | Test SQL, fixtures, registered expectations, and workflow or boundary scenarios                   |
| `tools/`                        | Substantial generation and revision of build, export, test, benchmark, and regression utilities   |
| `webui/`                        | Substantial generation and revision of optional interface functionality                           |
| Evidence summaries and mappings | Organization, traceability, comparison, and interpretation of execution artifacts                 |
| Stage 2 report                  | Substantial drafting, restructuring, technical explanation, and language editing                  |
| `README.md`                     | Substantial drafting and revision of project and execution documentation                          |
| Presentation material           | Draft slides, structure, wording, and speaking guidance                                           |
| `ai_usage.md`                   | Drafting and revision of this disclosure                                                          |

This table identifies areas affected by assistance. It does not imply that every line in each location was generated by AI or that every generated suggestion was retained.

AI helped interpret and present execution evidence. It was not itself the source of measured query results or timings; those claims depend on the retained execution artifacts.

## 6. Verification and Revisions

### 6.1 Execution-Based Checks

Verification included the recorded SQL-suite execution, separate optional WebUI regression runs, clean-seed query outputs, and synthetic index measurements.

The retained evidence reports:

- 95 SQL cases passing across 93 SQL files.
- 14 named API/MySQL regression checks passing.
- 14 named browser regression checks passing.

These results are separate evidence sets. They are not combined into one test total, and the WebUI checks are not treated as equivalent to SQL cases.

The recorded runs support the tested behavior of the identified versions and database states. They do not establish exhaustive correctness or show that every later documentation or repository change was retested.

### 6.2 Technical and Documentation Review

AI-assisted review addressed distinctions including:

- Foreign-key existence checks versus staff-role eligibility.
- Allowed status values versus permitted workflow transitions.
- Statement failure versus explicit transaction rollback.
- RESOLVED actions versus VERIFIED actions.
- Unverified follow-up populations versus unresolved workload.
- Inspection-level results versus criterion-level failure.
- Clean construction-seed outputs versus post-test database state.
- Optimizer estimates versus observed execution counts.
- Index availability versus actual index selection.

These distinctions were used to revise explanations and avoid claiming stronger guarantees than the implementation or evidence supported.

### 6.3 Revisions to Generated Material

Generated material was revised during development to address execution feedback and consistency issues. Revisions included correcting setup instructions, aligning evidence references and management-question mappings, and distinguishing schema constraints from controlled-operation checks.

These changes formed part of the iterative preparation of the implementation and documentation.

## 7. Verification Scope

AI assisted with both implementation and test development. Verification therefore considered execution traces, expected errors, state comparisons, and query outputs, rather than relying on generated explanations alone. The reported results apply to the recorded cases, versions, and database states.

The report documents the coverage and limitations of the SQL tests, analytical findings, WebUI regression, and synthetic benchmarks. These evidence sets are interpreted separately.

## 8. Authorship and Responsibility

This declaration acknowledges substantial AI assistance in both implementation and documentation, including supporting Python code, SQL-related material, testing utilities, report text, and presentation preparation.

It does not characterize the assistance as proofreading only or claim that all submitted code, explanations, and technical suggestions originated independently from the group.

The group remains responsible for the submitted work, the accuracy of its claims, the identification of retained AI-generated material, and compliance with the course's academic-integrity requirements.

The group acknowledges the AI assistance described above and remains responsible for the accuracy of the submitted work and compliance with the course's academic-integrity requirements.