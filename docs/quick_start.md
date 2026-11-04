# Quick start

1. Confirm G083 versus G084 and current Canvas name; fix metadata before release.
2. Verify MySQL 8.4.11 and DBeaver using the course setup guide.
3. Clone repository; select a personal empty disposable project database.
4. Author schema and seed files. Current comment-only SQL is not a working build.
5. Build 01_schema -> 02_data -> 03_views -> 04_indexes.
6. Implement one complete repair workflow before expanding data and queries.
7. Run Q01-Q08 on fresh seed; export real CSVs, headers and SQL NULL as \N.
8. Implement/run tests; record real results and rollback restoration.
9. Another member independently rebuilds solely from README instructions.

## Release
Deadline: 23 November 2026, 23:55 HKT.
Archive: COMP2411_2026_Gxxx_Stage2.zip, with exactly one matching top-level directory.
Replace Gxxx with the confirmed Group ID.
Required: metadata.json, README.md, report.pdf, contribution.pdf with signatures,
ai_usage.md, presentation.pdf, sql/, queries/, tests/ and evidence/.
Exclude .git, caches, editor dependencies and database binaries.
No PDF or query-output placeholders count as final evidence.
Presentation: four prepared minutes plus two live-task minutes; both participate.
AI/chat/remote assistance is prohibited during assessment. Bring a working local database.
