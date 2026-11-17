# Query release verification

Q01 and Q02 use completed first-round inspections dated 2026-03-01 through
2026-10-31 inclusive. Q01 and Q04 query base tables; Q02 and Q03 use views.
Technique tags describe the submitted SELECT, not joins hidden inside views.
The query map records business purpose, not a claim of formal group approval.

Q08 uses job status (not the enclosing multi-item request status), a completed
first inspection with a failed criterion, and an earlier return before the
current request. No causal inference is made. Its result membership may change;
regenerate evidence rather than retaining the old thirteen IDs by assumption.

## Execute before the operational tests

Use a disposable database loaded only from sql/01_schema.sql, sql/02_data.sql,
sql/03_views.sql, and sql/04_indexes.sql, in that order. Stop other writers.

```bash
python tools/verify_query_release.py --user root --database comp2411_test_rebuild
```

The verifier checks Q04/Q05/Q06/Q07 baseline invariants, runs all eight queries,
removes an existing qualifying incident's links inside a transaction, checks
that the actual Q06 detects it, and rolls back. It then compares all twelve
table snapshots and all eight query results before exporting baseline CSVs.
No INSERTs, DDL, or commits are performed. Errors trigger rollback/connection
close. Run only on a disposable database and retain the generated JSON.

Seed provenance is an explicit operator attestation, not something nine
technician rows can prove. The JSON records the attestation, snapshots, query
hashes, Q06 detection, and restoration. It does not prove arbitrary database
correctness, performance, or the 95-case operational suite result.

No PASS evidence is shipped by this patch. After the script succeeds, inspect
the generated CSVs and JSON, then run the operational suite and retain its
separate logs. Do not register this verifier as one of the existing 95 cases.
