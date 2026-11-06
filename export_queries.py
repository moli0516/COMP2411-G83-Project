import argparse
import csv
import getpass
import sys
from pathlib import Path

import mysql.connector


QUERY_IDS = ("Q02", "Q03", "Q05", "Q08")
PROJECT_DIR = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(
        description="Run Q02, Q03, Q05 and Q08; export results as CSV."
    )
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3306)
    parser.add_argument("--user", required=True)
    parser.add_argument("--database", required=True)
    args = parser.parse_args()

    # Check all input files before connecting.
    queries = {}
    for query_id in QUERY_IDS:
        sql_file = PROJECT_DIR / "queries" / f"{query_id}.sql"

        if not sql_file.is_file():
            raise FileNotFoundError(f"Missing SQL file: {sql_file}")

        sql = sql_file.read_text(encoding="utf-8-sig").strip()
        if not sql:
            raise ValueError(f"{sql_file.name} is empty.")

        queries[query_id] = sql

    password = getpass.getpass("MySQL password: ")

    connection = mysql.connector.connect(
        host=args.host,
        port=args.port,
        user=args.user,
        password=password,
        database=args.database,
        charset="utf8mb4",
        connection_timeout=10,
        autocommit=False,
    )

    results = {}

    try:
        connection.start_transaction(
            isolation_level="REPEATABLE READ",
            consistent_snapshot=True,
            readonly=True,
        )

        with connection.cursor(buffered=True) as cursor:
            for query_id, sql in queries.items():
                print(f"Running {query_id}...")

                cursor.execute(sql)

                if cursor.description is None:
                    raise ValueError(
                        f"{query_id} did not return a result set."
                    )

                headers = [column[0] for column in cursor.description]
                rows = cursor.fetchall()

                extra_results = False

                while cursor.nextset():
                    extra_results = True

                    if cursor.description is not None:
                        cursor.fetchall()

                if extra_results:
                    raise ValueError(
                        f"{query_id} contains multiple statements/results. "
                        "Keep only one business SELECT per file."
                    )

                results[query_id] = (headers, rows)

        # End the read-only transaction; no database changes are saved.
        connection.rollback()

    finally:
        try:
            if connection.in_transaction:
                connection.rollback()
        finally:
            connection.close()

    # Export only after all four queries have executed successfully.
    output_dir = PROJECT_DIR / "evidence" / "query_results"
    output_dir.mkdir(parents=True, exist_ok=True)

    for query_id, (headers, rows) in results.items():
        csv_file = output_dir / f"{query_id}.csv"

        with csv_file.open("w", encoding="utf-8", newline="") as file:
            writer = csv.writer(file)
            writer.writerow(headers)

            for row in rows:
                writer.writerow(
                    r"\N" if value is None else value
                    for value in row
                )

        print(f"{query_id}: {len(rows)} rows exported to {csv_file}")

    print("Finished. Existing result CSVs have been replaced.")


if __name__ == "__main__":
    try:
        main()
    except (mysql.connector.Error, OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)