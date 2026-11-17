"""Scan all tests/**/*.sql; metadata must match every file.

No operation-core dependency.
"""

import argparse
import csv
import getpass
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

import mysql.connector
import sqlparse


HEADERS = [
    "test_id",
    "requirement",
    "script",
    "initial_state",
    "expected_result",
    "expected_error",
    "actual_result",
    "status",
]

TABLES = [
    "Customer",
    "Equipment",
    "ServiceRequest",
    "RequestItem",
    "Quotation",
    "Staff",
    "ServiceJob",
    "Inspection",
    "InspectionResult",
    "Incident",
    "CorrectiveAction",
    "IncidentCorrectiveAction",
]


def encode(value):
    return json.dumps(value, default=str, ensure_ascii=False)


def read_sql(path, ddl=False):
    text = path.read_text(encoding="utf-8-sig")

    if "/*!" in text or re.search(
        r"^\s*(DELIMITER|SOURCE)\b",
        text,
        re.I | re.M,
    ):
        raise ValueError(f"{path}: unsupported client SQL")

    batch = [
        sqlparse.format(statement, strip_comments=True).strip()
        for statement in sqlparse.split(text)
    ]
    batch = [
        statement
        for statement in batch
        if statement.strip(";").strip()
    ]

    if not batch:
        raise ValueError(f"{path}: empty/comment-only SQL")

    if not ddl and any(
        re.match(
            r"^(CREATE|ALTER|DROP|TRUNCATE|USE|GRANT|REVOKE)\b",
            statement,
            re.I,
        )
        for statement in batch
    ):
        raise ValueError(f"{path}: DDL/admin forbidden")

    return batch


def workflow_steps(spec):
    return spec["steps"] if "steps" in spec else [spec]


def op_path(project, name):
    operations_dir = (project / "operations").resolve()
    path = (operations_dir / name).resolve()

    if path.parent != operations_dir:
        raise ValueError("Invalid operation path")

    return path


def discover(root, data):
    if not isinstance(data, dict) or data.get("version") != 1:
        raise ValueError("Invalid tests metadata")

    found = {
        path.resolve()
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() == ".sql"
    }

    if not found:
        raise ValueError("No SQL tests found")

    registered = {}
    ids = set()

    for spec in data["scripts"]:
        path = (root / spec["path"]).resolve()

        if (
            not path.is_relative_to(root)
            or path.suffix.lower() != ".sql"
            or path in registered
        ):
            raise ValueError("Invalid/duplicate metadata path")

        mode = spec.get("mode", "sql")

        if mode not in ("sql", "negative", "workflow"):
            raise ValueError("Unknown mode")

        if not spec.get("cases"):
            raise ValueError("Missing cases")

        for case in spec["cases"]:
            if any(
                not case.get(key)
                for key in (
                    "test_id",
                    "requirement",
                    "initial_state",
                    "expected_result",
                )
            ):
                raise ValueError("Missing case description")

            if case["test_id"] in ids:
                raise ValueError("Duplicate Test ID")

            ids.add(case["test_id"])

        for rule in spec.get("expected_errors", []):
            re.compile(rule["statement_regex"], re.I)

            if (
                rule["occurrence"] < 1
                or not isinstance(rule["errno"], int)
                or not rule["sqlstate"]
            ):
                raise ValueError("Invalid error rule")

        if mode == "negative":
            if (
                len(spec["cases"]) != 1
                or len(spec.get("expected_errors", [])) != 1
                or not data.get("negative_setup_sql")
            ):
                raise ValueError("Invalid negative metadata")

        if mode == "workflow":
            if len(spec["cases"]) != 1 or not workflow_steps(spec):
                raise ValueError("Invalid workflow cases")

            for step in workflow_steps(spec):
                if (
                    step.get("expected_outcome")
                    not in ("success", "reject", "error")
                    or not step.get("parameters_sql")
                ):
                    raise ValueError("Invalid workflow step")

                if (
                    step["expected_outcome"] == "success"
                    and not step.get("verification_sql")
                ):
                    raise ValueError("Missing workflow postcondition")

                if step["expected_outcome"] == "error":
                    if (
                        not step.get("expected_error")
                        or not step.get("failure_verification_sql")
                    ):
                        raise ValueError(
                            "Expected DB error needs "
                            "error/post-failure verification"
                        )

                read_sql(op_path(root.parent, step["operation"]))

        registered[path] = spec

    missing = found - set(registered)
    absent = set(registered) - found

    if missing or absent:
        missing_paths = [
            str(path.relative_to(root))
            for path in sorted(missing)
        ]
        absent_paths = [
            str(path.relative_to(root))
            for path in sorted(absent)
        ]

        raise ValueError(
            "SQL missing metadata: "
            + str(missing_paths)
            + "; metadata missing SQL: "
            + str(absent_paths)
        )

    def order(path):
        relative_path = path.relative_to(root).as_posix()

        first = {
            "positive.sql": 0,
            "transaction_commit.sql": 1,
            "transaction_rollback.sql": 2,
        }

        if relative_path.startswith("negative/"):
            default_priority = 3
        elif relative_path.startswith("workflow/"):
            default_priority = 4
        else:
            default_priority = 5

        return (
            first.get(relative_path, default_priority),
            relative_path,
        )

    plan = []

    for path in sorted(found, key=order):
        if not path.is_relative_to(root):
            raise ValueError("External SQL symlink forbidden")

        spec = dict(
            registered[path],
            path=path.relative_to(root).as_posix(),
        )
        batch = read_sql(path)

        if spec.get("mode") == "negative":
            if (
                len(batch) != 1
                or not re.match(r"^INSERT\s+INTO\b", batch[0], re.I)
            ):
                raise ValueError("Negative mode requires one INSERT")

        if spec.get("mode") == "workflow":
            if any(
                re.match(
                    r"^(START|BEGIN|COMMIT|ROLLBACK)\b",
                    statement,
                    re.I,
                )
                for statement in batch
            ):
                raise ValueError(
                    "Workflow fixture cannot control transaction"
                )

        plan.append((path, spec))

    return plan


def snapshot(connection):
    result = {}

    with connection.cursor(buffered=True) as cursor:
        for table in TABLES:
            cursor.execute(f"SELECT * FROM `{table}`")
            rows = sorted(
                encode(row)
                for row in cursor.fetchall()
            )

            result[table] = {
                "rows": len(rows),
                "sha256": hashlib.sha256(
                    encode(rows).encode()
                ).hexdigest(),
            }

    return result


def execute(connection, batch):
    with connection.cursor(buffered=True) as cursor:
        for sql in batch:
            cursor.execute(sql)

            if cursor.with_rows:
                cursor.fetchall()


class ValidationRejected(ValueError):
    pass


def operation(connection, path, params, trace=None):
    batch = read_sql(path)

    if any(
        re.match(
            r"^(START|BEGIN|COMMIT|ROLLBACK)\b",
            statement,
            re.I,
        )
        for statement in batch
    ):
        raise ValueError("Operation cannot control transaction")

    required = set(
        re.findall(
            r"%\((\w+)\)s",
            path.read_text(encoding="utf-8"),
        )
    )

    if required - set(params):
        raise ValueError("Missing operation parameters")

    outputs = []

    with connection.cursor(buffered=True) as cursor:
        for index, sql in enumerate(batch):
            parameters = (
                params
                if re.search(r"%\(\w+\)s", sql)
                else None
            )
            cursor.execute(sql, parameters)

            if trace is not None:
                trace.append(
                    {
                        "statement": index + 1,
                        "sql": sql,
                        "rowcount": cursor.rowcount,
                    }
                )

            if cursor.description:
                columns = [
                    column[0]
                    for column in cursor.description
                ]
                rows = cursor.fetchall()

                if index == 0:
                    if columns != ["ok"] or len(rows) != 1:
                        raise ValueError(
                            "Malformed validation SELECT"
                        )

                    if trace is not None:
                        trace[-1]["validation_ok"] = rows[0][0]

                    if rows[0][0] != 1:
                        raise ValidationRejected(
                            "Validation failed; operation cancelled"
                        )
                else:
                    outputs.append(
                        {
                            "columns": columns,
                            "rows": rows,
                        }
                    )

            elif index == 0:
                raise ValueError(
                    "First operation statement must be "
                    "validation SELECT"
                )

    return outputs


def run_sql(connection, path, spec):
    details = {
        "events": [],
        "results": {},
        "problems": [],
    }
    rules = spec.get("expected_errors", [])
    counts = [0] * len(rules)
    hits = [0] * len(rules)

    try:
        with connection.cursor(
            dictionary=True,
            buffered=True,
        ) as cursor:
            for number, sql in enumerate(read_sql(path), 1):
                eligible = []

                for index, rule in enumerate(rules):
                    if re.search(
                        rule["statement_regex"],
                        sql,
                        re.I,
                    ):
                        counts[index] += 1

                        if counts[index] == rule["occurrence"]:
                            eligible.append(index)

                if len(eligible) > 1:
                    raise ValueError("Overlapping error rules")

                event = {
                    "statement": number,
                    "sql": sql,
                }
                details["events"].append(event)

                try:
                    cursor.execute(sql)

                    if cursor.with_rows:
                        rows = cursor.fetchall()
                        event["rows"] = rows

                        for row in rows:
                            if "test_id" in row:
                                test_id = str(row["test_id"])
                                details["results"].setdefault(
                                    test_id,
                                    [],
                                ).append(row)
                    else:
                        event["rowcount"] = cursor.rowcount

                    if eligible:
                        raise ValueError(
                            "Expected error not raised"
                        )

                except mysql.connector.Error as exc:
                    event["error"] = {
                        "errno": exc.errno,
                        "sqlstate": exc.sqlstate,
                        "message": str(exc),
                    }

                    if not eligible:
                        raise

                    index = eligible[0]
                    rule = rules[index]

                    if (
                        exc.errno,
                        exc.sqlstate,
                    ) != (
                        rule["errno"],
                        rule["sqlstate"],
                    ):
                        raise

                    hits[index] += 1
                    event["expected"] = True

        if any(hit != 1 for hit in hits):
            raise ValueError(
                "Expected error rule not satisfied"
            )

        if connection.in_transaction:
            raise ValueError("SQL left active transaction")

    except Exception as exc:
        details["problems"].append(str(exc))

    finally:
        if connection.in_transaction:
            connection.rollback()

    checks = {}

    for case in spec["cases"]:
        rows = details["results"].get(
            case["test_id"],
            [],
        )
        checks[case["test_id"]] = (
            len(rows) == 1
            and rows[0].get("result") == "PASS"
        )

    return details, checks


def query_one(connection, sql):
    with connection.cursor(
        dictionary=True,
        buffered=True,
    ) as cursor:
        cursor.execute(sql)
        rows = cursor.fetchall()

    if len(rows) != 1:
        raise ValueError(
            "Expected exactly one SELECT row"
        )

    return rows[0]


def verify(connection, sql):
    row = query_one(connection, sql)

    if row.get("result") != "PASS":
        raise ValueError(
            "Business postcondition failed: " + encode(row)
        )

    return row


def run_isolated(connection, path, spec, data, project):
    details = {"problems": []}
    mode = spec["mode"]

    try:
        details["baseline"] = snapshot(connection)
        connection.start_transaction()

        setup_sql = (
            data["negative_setup_sql"]
            if mode == "negative"
            else read_sql(path)
        )
        execute(connection, setup_sql)
        details["before"] = snapshot(connection)

        if mode == "negative":
            error = None

            try:
                execute(connection, read_sql(path))

            except mysql.connector.Error as exc:
                error = {
                    "errno": exc.errno,
                    "sqlstate": exc.sqlstate,
                    "message": str(exc),
                }

            details["error"] = error
            rule = spec["expected_errors"][0]

            if error is None or (
                error["errno"],
                error["sqlstate"],
            ) != (
                rule["errno"],
                rule["sqlstate"],
            ):
                raise ValueError(
                    "Missing/wrong database error"
                )

            details["after"] = snapshot(connection)

            if details["before"] != details["after"]:
                raise ValueError(
                    "Rejected INSERT changed data"
                )

        else:
            details["steps"] = []

            for number, step in enumerate(
                workflow_steps(spec),
                1,
            ):
                params = query_one(
                    connection,
                    step["parameters_sql"],
                )
                operation_path = op_path(
                    project,
                    step["operation"],
                )

                event = {
                    "step": number,
                    "operation": step["operation"],
                    "operation_sha256": hashlib.sha256(
                        operation_path.read_bytes()
                    ).hexdigest(),
                    "parameters": params,
                    "trace": [],
                }
                details["steps"].append(event)

                before = snapshot(connection)
                execute(
                    connection,
                    ["SAVEPOINT ia_operation_step"],
                )
                outcome = "success"

                try:
                    event["outputs"] = operation(
                        connection,
                        operation_path,
                        params,
                        event["trace"],
                    )

                except ValidationRejected as exc:
                    outcome = "reject"
                    event["rejection"] = str(exc)

                except mysql.connector.Error as exc:
                    outcome = "error"
                    event["error"] = {
                        "errno": exc.errno,
                        "sqlstate": exc.sqlstate,
                        "message": str(exc),
                    }

                    if step["expected_outcome"] != "error":
                        raise

                    rule = step["expected_error"]

                    if (
                        (
                            exc.errno,
                            exc.sqlstate,
                        )
                        != (
                            rule["errno"],
                            rule["sqlstate"],
                        )
                        or rule.get("message_contains", "")
                        not in str(exc)
                    ):
                        raise

                event["outcome"] = outcome

                if outcome != step["expected_outcome"]:
                    raise ValueError(
                        f"Step {number}: expected "
                        f"{step['expected_outcome']}, "
                        f"got {outcome}"
                    )

                if outcome == "error":
                    event["partial_state"] = snapshot(
                        connection
                    )
                    event["failure_verification"] = verify(
                        connection,
                        step["failure_verification_sql"],
                    )

                    execute(
                        connection,
                        [
                            "ROLLBACK TO SAVEPOINT "
                            "ia_operation_step"
                        ],
                    )
                    event["after_step_rollback"] = snapshot(
                        connection
                    )

                    if before != event["after_step_rollback"]:
                        raise ValueError(
                            "Partial operation rollback "
                            "changed state"
                        )

                elif outcome == "reject":
                    if before != snapshot(connection):
                        raise ValueError(
                            "Rejected operation changed data"
                        )

                else:
                    event["verification"] = verify(
                        connection,
                        step["verification_sql"],
                    )

                execute(
                    connection,
                    ["RELEASE SAVEPOINT ia_operation_step"],
                )

            details["after"] = snapshot(connection)

    except Exception as exc:
        details["problems"].append(str(exc))

    finally:
        if connection.in_transaction:
            connection.rollback()

    try:
        details["restored"] = snapshot(connection)

        if details.get("baseline") != details["restored"]:
            details["problems"].append(
                "Fixture rollback changed baseline"
            )

    except Exception as exc:
        details["problems"].append(str(exc))

    checks = {
        spec["cases"][0]["test_id"]: not details["problems"]
    }
    return details, checks


def main():
    parser = argparse.ArgumentParser(
        description=__doc__
    )
    parser.add_argument(
        "--tests-dir",
        default=str(
            Path(__file__).resolve().parents[1] / "tests"
        ),
    )
    parser.add_argument(
        "--host",
        default="127.0.0.1",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=3306,
    )
    parser.add_argument(
        "--user",
        default="root",
    )
    parser.add_argument("--database")
    parser.add_argument(
        "--list",
        action="store_true",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Always strict; compatibility flag",
    )

    args = parser.parse_args()
    root = Path(args.tests_dir).resolve()
    project = root.parent

    try:
        data = json.loads(
            (root / "metadata.json").read_text(
                encoding="utf-8-sig"
            )
        )
        plan = discover(root, data)

    except Exception as exc:
        parser.error(str(exc))

    for _, spec in plan:
        case_ids = ", ".join(
            case["test_id"]
            for case in spec["cases"]
        )
        print(
            f"RUN {spec['path']} "
            f"[{spec.get('mode', 'sql')}]: "
            f"{case_ids}"
        )

    total = sum(
        len(spec["cases"])
        for _, spec in plan
    )
    print(
        f"Discovered {len(plan)} SQL files, "
        f"{total} cases; none skipped."
    )

    if args.list:
        return 0

    if not args.database:
        parser.error("--database required")

    print(
        f"Target {args.host}:{args.port}/{args.database}. "
        "Writes/COMMITs occur; isolated disposable DB only."
    )

    confirmation = input(
        "Type exact disposable database name: "
    )

    if confirmation != args.database:
        return 2

    password = getpass.getpass("MySQL password: ")

    timestamp = datetime.now(timezone.utc).strftime(
        "%Y%m%dT%H%M%S%fZ"
    )
    destination = (
        project
        / "evidence"
        / "automated_runs"
        / timestamp
    )
    destination.mkdir(parents=True)

    report = []
    logs = []

    try:
        for path, spec in plan:
            connection = None

            try:
                connection = mysql.connector.connect(
                    host=args.host,
                    port=args.port,
                    user=args.user,
                    password=password,
                    database=args.database,
                    autocommit=True,
                )

                if spec.get("mode") in (
                    "negative",
                    "workflow",
                ):
                    detail, checks = run_isolated(
                        connection,
                        path,
                        spec,
                        data,
                        project,
                    )
                else:
                    detail, checks = run_sql(
                        connection,
                        path,
                        spec,
                    )

            except Exception as exc:
                detail = {"problems": [str(exc)]}
                checks = {}

            finally:
                if connection is not None:
                    connection.close()

            logs.append(
                {
                    "script": spec["path"],
                    "sha256": hashlib.sha256(
                        path.read_bytes()
                    ).hexdigest(),
                    "details": detail,
                }
            )

            expected = "; ".join(
                f"{rule['errno']} / "
                f"SQLSTATE {rule['sqlstate']}"
                for rule in spec.get(
                    "expected_errors",
                    [],
                )
            ) or (
                "ValidationRejected (template protocol)"
                if spec.get("expected_outcome") == "reject"
                else "NONE"
            )

            failed = False

            for case in spec["cases"]:
                passed = (
                    checks.get(case["test_id"], False)
                    and not detail.get("problems")
                )

                row = dict(
                    case,
                    script="tests/" + spec["path"],
                    expected_error=expected,
                    actual_result=encode(detail),
                    status="PASS" if passed else "FAIL",
                )

                report.append(
                    {
                        key: row[key]
                        for key in HEADERS
                    }
                )

                print(
                    case["test_id"],
                    row["status"],
                )
                failed |= not passed

            if failed:
                print(
                    "Failure recorded. "
                    "Continuing to the next SQL file."
                )

    finally:
        ran = {
            entry["script"]
            for entry in logs
        }

        with (
            destination / "test_cases.csv"
        ).open(
            "w",
            newline="",
            encoding="utf-8",
        ) as file:
            writer = csv.DictWriter(
                file,
                fieldnames=HEADERS,
            )
            writer.writeheader()
            writer.writerows(report)

        run_log = {
            "target": {
                "host": args.host,
                "port": args.port,
                "database": args.database,
            },
            "metadata_sha256": hashlib.sha256(
                (root / "metadata.json").read_bytes()
            ).hexdigest(),
            "planned": [
                spec["path"]
                for _, spec in plan
            ],
            "not_run": [
                spec["path"]
                for _, spec in plan
                if spec["path"] not in ran
            ],
            "scripts": logs,
        }

        (
            destination / "run_log.json"
        ).write_text(
            json.dumps(
                run_log,
                indent=2,
                default=str,
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )

        print("Results:", destination)

    return (
        0
        if len(report) == total
        and all(
            row["status"] == "PASS"
            for row in report
        )
        else 1
    )


if __name__ == "__main__":
    sys.exit(main())