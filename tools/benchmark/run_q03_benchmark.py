"""Build an isolated synthetic database, then compare natural Q03 execution plans."""
import argparse
import csv
import getpass
import hashlib
import json
import re
import statistics
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import mysql.connector

from q03_data import REFERENCE_DATE, SCENARIOS, action_rows


PROJECT_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_DIR / "tools"))
from build_test_database import load


INDEX = "idx_corrective_action_due_date"
INSERT_ACTION = """
INSERT INTO CorrectiveAction(
    action_id, action_description, assigned_staff_id, created_date,
    due_date, action_status, resolved_date, resolution_note,
    verified_by_manager_id, verified_date
) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
"""


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, default=str) + "\n", encoding="utf-8")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def revision():
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=PROJECT_DIR,
        capture_output=True, text=True, check=False,
    )
    return result.stdout.strip() or None


def build(connection, cursor, args, log):
    scripts = load(PROJECT_DIR)
    cursor.execute(
        "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=%s",
        (args.database,),
    )
    if cursor.fetchone():
        raise ValueError("Database exists. Choose a NEW suffix; nothing is dropped.")

    cursor.execute(f"CREATE DATABASE `{args.database}` CHARACTER SET utf8mb4")
    connection.database = args.database
    log["created"] = True

    for name, statements, sha256 in scripts:
        if name == "02_data.sql":
            continue
        log.setdefault("construction", []).append({"file": name, "sha256": sha256})
        for statement in statements:
            cursor.execute(statement)
            if cursor.with_rows:
                cursor.fetchall()

    connection.start_transaction()
    cursor.executemany(
        "INSERT INTO Staff(staff_id,staff_name,role,active_status) VALUES (%s,%s,%s,1)",
        [(number, f"Benchmark technician {number}", "TECHNICIAN") for number in range(1, 8)]
        + [(8, "Benchmark manager", "MANAGER")],
    )
    batch = []
    for row in action_rows(args.rows, args.scenario, args.seed):
        batch.append(row)
        if len(batch) == args.batch_size:
            cursor.executemany(INSERT_ACTION, batch)
            batch.clear()
    if batch:
        cursor.executemany(INSERT_ACTION, batch)
    connection.commit()

    cursor.execute("CREATE TABLE BenchmarkManifest (manifest_json JSON NOT NULL)")
    manifest = {
        "kind": "COMP2411_Q03_SYNTHETIC_V1", "scenario": args.scenario,
        "rows": args.rows, "seed": args.seed,
        "reference_date": str(REFERENCE_DATE),
        "query_sha256": digest(PROJECT_DIR / "queries/Q03.sql"),
        "generator_sha256": digest(Path(__file__).with_name("q03_data.py")),
    }
    cursor.execute("INSERT INTO BenchmarkManifest VALUES (%s)", (json.dumps(manifest),))
    log["manifest"] = manifest


def result_signature(cursor, sql):
    cursor.execute(sql)
    columns = [column[0] for column in cursor.description]
    rows = cursor.fetchall()
    encoded = sorted(json.dumps(row, default=str) for row in rows)
    signature = hashlib.sha256("\n".join(encoded).encode()).hexdigest()
    return {"columns": columns, "rows": len(rows), "sha256": signature}


def run(connection, cursor, args, log, output_dir):
    connection.database = args.database
    cursor.execute("SELECT manifest_json FROM BenchmarkManifest")
    manifests = cursor.fetchall()
    if len(manifests) != 1:
        raise ValueError("Expected one benchmark manifest.")
    manifest = json.loads(manifests[0][0])
    if manifest.get("kind") != "COMP2411_Q03_SYNTHETIC_V1":
        raise ValueError("Not a generated benchmark database.")
    sql_path = PROJECT_DIR / "queries/Q03.sql"
    if manifest["query_sha256"] != digest(sql_path):
        raise ValueError("Q03 changed since generation. Build a fresh benchmark database.")
    sql = sql_path.read_text(encoding="utf-8-sig").strip().rstrip(";")
    log["manifest"] = manifest
    cursor.execute("SELECT VERSION(),@@autocommit,@@optimizer_switch")
    log["environment"] = cursor.fetchone()
    cursor.execute("SET SESSION optimizer_switch='use_invisible_indexes=off'")
    cursor.execute(
        "SELECT INDEX_NAME,IS_VISIBLE,COLUMN_NAME FROM information_schema.STATISTICS "
        "WHERE TABLE_SCHEMA=%s AND TABLE_NAME='CorrectiveAction' ORDER BY INDEX_NAME,SEQ_IN_INDEX",
        (args.database,),
    )
    indexes = cursor.fetchall()
    log["indexes"] = indexes
    target = [row for row in indexes if row[0] == INDEX]
    if target != [(INDEX, "YES", "due_date")]:
        raise ValueError("Expected the visible single-column submitted due-date index.")
    cursor.execute(
        "SELECT COUNT(*),SUM(due_date < %s),"
        "SUM(due_date < %s AND action_status <> 'VERIFIED') FROM CorrectiveAction",
        (REFERENCE_DATE, REFERENCE_DATE),
    )
    total, date_matches, full_matches = cursor.fetchone()
    log["population"] = {
        "rows": total, "date_matches": date_matches, "q03_matches": full_matches,
        "date_match_percentage": 100 * int(date_matches) / total,
        "q03_match_percentage": 100 * int(full_matches) / total,
    }
    if total != manifest["rows"]:
        raise ValueError("Row count differs from the generated manifest.")
    cursor.execute("ANALYZE TABLE CorrectiveAction, Staff")
    log["analyze_table"] = cursor.fetchall()
    samples = []
    signatures = {}
    try:
        for condition in ("without_index", "with_index"):
            visibility = "INVISIBLE" if condition == "without_index" else "VISIBLE"
            cursor.execute(f"ALTER TABLE CorrectiveAction ALTER INDEX {INDEX} {visibility}")
            cursor.execute("EXPLAIN FORMAT=JSON " + sql)
            (output_dir / f"{condition}_explain.json").write_text(
                cursor.fetchone()[0] + "\n", encoding="utf-8",
            )
            cursor.execute("EXPLAIN ANALYZE " + sql)
            plan = "\n".join(str(row[0]) for row in cursor.fetchall())
            (output_dir / f"{condition}_analyze.txt").write_text(plan + "\n", encoding="utf-8")
            signatures[condition] = result_signature(cursor, sql)
            for _ in range(args.warmups):
                cursor.execute(sql)
                cursor.fetchall()

        for repeat in range(args.repeats):
            order = ("without_index", "with_index")
            if repeat % 2:
                order = tuple(reversed(order))
            for condition in order:
                visibility = "INVISIBLE" if condition == "without_index" else "VISIBLE"
                cursor.execute(f"ALTER TABLE CorrectiveAction ALTER INDEX {INDEX} {visibility}")
                start = time.perf_counter()
                cursor.execute(sql)
                rows = cursor.fetchall()
                seconds = time.perf_counter() - start
                if len(rows) != signatures[condition]["rows"]:
                    raise ValueError("Result row count changed during timing.")
                samples.append({"repeat": repeat + 1, "condition": condition, "seconds": seconds})
        log["final_signature"] = result_signature(cursor, sql)
    finally:
        cursor.execute(f"ALTER TABLE CorrectiveAction ALTER INDEX {INDEX} VISIBLE")
        log["index_restored_visible"] = True
        with (output_dir / "timings.csv").open("w", encoding="utf-8", newline="") as file:
            writer = csv.DictWriter(file, fieldnames=["repeat", "condition", "seconds"])
            writer.writeheader()
            writer.writerows(samples)

    log["signatures"] = signatures
    if signatures["without_index"] != signatures["with_index"] or log["final_signature"] != signatures["with_index"]:
        raise ValueError("Result signatures differ.")
    log["timings"] = {}
    for condition in signatures:
        values = [sample["seconds"] for sample in samples if sample["condition"] == condition]
        log["timings"][condition] = {
            "runs": len(values), "median_seconds": statistics.median(values),
            "min_seconds": min(values), "max_seconds": max(values),
        }
    log["median_ratio_without_over_with"] = (
        log["timings"]["without_index"]["median_seconds"]
        / log["timings"]["with_index"]["median_seconds"]
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("build", "run"))
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3306)
    parser.add_argument("--user", required=True)
    parser.add_argument("--database", required=True)
    parser.add_argument("--rows", type=int, default=100000)
    parser.add_argument("--scenario", choices=SCENARIOS, default="seed_like")
    parser.add_argument("--seed", type=int, default=2411)
    parser.add_argument("--batch-size", type=int, default=1000)
    parser.add_argument("--warmups", type=int, default=3)
    parser.add_argument("--repeats", type=int, default=10)
    args = parser.parse_args()
    if not re.fullmatch(r"comp2411_index_bench_[a-z0-9_]+", args.database) or len(args.database) > 64:
        parser.error("Use comp2411_index_bench_<lowercase_suffix>; baseline targets are forbidden.")
    if min(args.rows, args.batch_size, args.repeats) < 1 or args.warmups < 0:
        parser.error("Counts must be positive; warmups may be zero.")
    print(f"{args.mode}: {args.host}:{args.port}/{args.database}")
    print("Build creates a new synthetic DB; run changes benchmark index visibility only.")
    if input("Type exact target database name: ") != args.database:
        return 2
    password = getpass.getpass("MySQL password: ")
    output_dir = PROJECT_DIR / "evidence/index_benchmark" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output_dir.mkdir(parents=True, exist_ok=False)
    log = {
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "mode": args.mode, "database": args.database, "host": args.host,
        "port": args.port, "commit": revision(),
        "runner_sha256": digest(Path(__file__)),
        "scope": "Optional synthetic Q03 benchmark; separate from seed and SQL suite",
    }
    connection = None
    try:
        connection = mysql.connector.connect(
            host=args.host, port=args.port, user=args.user, password=password,
            charset="utf8mb4", connection_timeout=10, autocommit=True,
        )
        with connection.cursor(buffered=True) as cursor:
            if args.mode == "build":
                build(connection, cursor, args, log)
            else:
                run(connection, cursor, args, log, output_dir)
        log["status"] = "PASS"
        return 0
    except Exception as error:
        if connection is not None and connection.in_transaction:
            connection.rollback()
        log["status"] = "FAIL"
        log["error"] = str(error)
        print(f"ERROR: {error}", file=sys.stderr)
        print("No database is auto-dropped. Failed builds may leave partial DDL.", file=sys.stderr)
        return 1
    finally:
        if connection is not None:
            connection.close()
        write_json(output_dir / "run_log.json", log)
        print("Evidence:", output_dir)


if __name__ == "__main__":
    sys.exit(main())
