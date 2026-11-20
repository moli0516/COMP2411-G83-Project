# Optional Q03 index scale benchmark

This experiment is separate from the construction seed, Q01-Q08 baseline CSVs,
and the 95-case SQL suite. No performance improvement is assumed.

## Scope

The builder uses the existing schema, views and index scripts, but deliberately
skips `02_data.sql`. It inserts eight synthetic staff and the requested number
of corrective actions. Other business tables remain empty. This is a focused
Q03 reporting microbenchmark, not a complete repair-centre dataset or a workflow
fixture. No foreign-key or CHECK enforcement is disabled.

`seed_like` preserves 30/42 overdue-date matches and 10/42 Q03 matches in complete
42-row blocks. The overdue unverified subset has eight RESOLVED actions for
every two IN_PROGRESS actions. It does not replicate every seed characteristic.
`selective` has approximately 1% date matches and one third of those unverified.
Partial blocks are rounded through the deterministic bucket assignment.
Synthetic action IDs are shuffled relative to date/status buckets. Dates and
text widths are synthetic; the random seed defaults to 2411.

## Run from the repository root

Use the existing project requirements (mysql-connector-python and sqlparse).
Choose NEW database suffixes. Both commands require a password prompt and exact
database-name confirmation. The builder refuses existing databases and never
uses DROP DATABASE. A failed build can leave partial DDL: choose another suffix.

```sh
python tools/benchmark/test_q03_data.py
python tools/benchmark/run_q03_benchmark.py build --user root --database comp2411_index_bench_seed100k --scenario seed_like --rows 100000
python tools/benchmark/run_q03_benchmark.py run --user root --database comp2411_index_bench_seed100k
python tools/benchmark/run_q03_benchmark.py build --user root --database comp2411_index_bench_selective100k --scenario selective --rows 100000
python tools/benchmark/run_q03_benchmark.py run --user root --database comp2411_index_bench_selective100k
```

Optional flags: `--host`, `--port`, `--seed`, `--batch-size`, `--warmups`,
`--repeats`. Rows/scenario/seed/batch-size apply to build; warmups/repeats to run.
Repeat with fresh names and larger row counts if useful. Do not run concurrent
writers, WebUI fixtures, or SQL mutation tests against these databases.

## Method and evidence

The runner executes the repository Q03 unchanged. It checks its hash against
the build manifest, refreshes table statistics, and captures EXPLAIN JSON plus
EXPLAIN ANALYZE with the due-date index invisible and visible. Session use of
invisible indexes is explicitly disabled. Other indexes remain available and
the optimizer chooses its own plan; no FORCE INDEX is used.

The invisible condition represents optimizer access without this index, not
physical removal: index storage and maintenance costs remain. These are SELECT
measurements only. In a normal exit or Python exception the index is restored
VISIBLE; after a killed process or lost connection, inspect and restore it
manually in the benchmark schema before rerunning:

```sql
ALTER TABLE CorrectiveAction ALTER INDEX idx_corrective_action_due_date VISIBLE;
```

After plan capture, both conditions receive warmups. Timed condition order
alternates each repetition. Timings include connector execution and complete
result fetching, but exclude ALTER, EXPLAIN, ANALYZE TABLE and signature sorting.
This is a warm-cache client measurement, not a controlled cold-cache experiment.
No global buffer-pool settings are changed. Run the complete comparison again
to assess run-to-run stability.

Each run writes a unique directory under `evidence/index_benchmark/` containing
`run_log.json`, `timings.csv`, and before/after plan files. Logs include population
counts, selectivity, server version, source hashes, result signatures, medians,
and min/max timings. Git HEAD is recorded but may not describe uncommitted
changes; runner/generator/query hashes help identify actual inputs. Retain build
and measurement logs together. Do not overwrite `evidence/query_results/`.

Compare result signatures before interpreting timings. Inspect the plans:
visibility does not guarantee index use, and a ratio near one or below one is
not evidence of a useful speedup. Report seed results first, then these explicitly
synthetic scenarios, their sizes/distributions, and measurement limitations.
The generator uses O(rows) memory for shuffled positions and timing fetches all
Q03 matches; start at 100,000 rows rather than an unbounded size.

## Validation boundary

Offline unit tests cover repeatability, population proportions, IDs and lifecycle
fields. They do not establish MySQL compatibility or measured speedup. Execute
the build/run commands on MySQL 8.4 and review generated evidence before making
report claims. Keep generated database dumps and credentials out of Git.
