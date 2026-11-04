# Environment

Stage 2 development skeleton only: no schema, data, query or test implementation is complete.
Planned DBMS: MySQL Community Server 8.4.11. Verify the actual environment before release.
Group identity is UNCONFIRMED: proposal G083; repository name contains G84.
No application or HTTP API is required by this scaffold.

# Build

Prepare and select an empty disposable project database using the course setup procedure.
Implement, then run sql/01_schema.sql through sql/04_indexes.sql in order.
Currently these files contain comments only; running them does not build a database.
Never include CREATE/DROP DATABASE, credentials or expected failures in construction scripts.

# Queries

Implement Q01-Q08 as eight distinct business SELECT statements.
Execute on fresh seed data before mutation tests. Export matching CSVs with headers.
Use fixed reporting dates and stable ordering when required. Export SQL NULL as \N.

# Tests

Implement positive, negative and transaction scripts. No tests have been executed.
Start from fresh seed data unless exact prerequisites are documented.
Run negative files independently, one expected-failure statement per file.
Rollback demonstration: successful change, related failure, explicit ROLLBACK in the same connection,
then verify restoration. Document autocommit and client execution blocks.

# Limitations

This is an incomplete skeleton, not a working system or submission-ready package.
Validation queries alone do not guarantee prevention of arbitrary direct updates.
Core implementation, design decisions and explanations remain the group's responsibility.

# File inventory

- sql/: required construction placeholders.
- operations/: optional controlled workflow specifications.
- queries/: required business query placeholders.
- tests/: test implementation placeholders.
- evidence/: exact CSV headers and proposed mappings, not executed evidence.
- docs/: editable planning and deliverable outlines.
- metadata.json: incomplete development metadata; confirm identity and actual environment.
- ai_usage.md: skeleton assistance declaration; retain prior assistance history.

Final release also requires report.pdf, signed contribution.pdf, presentation.pdf and real query CSVs.
See docs/quick_start.md for packaging. Do not package the entire development repository blindly.
