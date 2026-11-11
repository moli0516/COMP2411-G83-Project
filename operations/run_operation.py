import argparse
import getpass
import json
import re
from pathlib import Path
import mysql.connector
import sqlparse


def main():
    p = argparse.ArgumentParser(description="Execute one controlled operation atomically.")
    p.add_argument("operation", help="SQL filename inside operations/")
    p.add_argument("inputs", type=Path, help="JSON input file")
    p.add_argument("--user", required=True)
    p.add_argument("--database", required=True)
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=3306)
    p.add_argument("--commit", action="store_true", help="Persist changes; default rolls back")
    a = p.parse_args()
    base = Path(__file__).resolve().parent
    if Path(a.operation).name != a.operation or not a.operation.endswith(".sql"):
        p.error("Supply only an operation SQL filename")
    text = (base / a.operation).read_text(encoding="utf-8")
    params = json.loads(a.inputs.read_text(encoding="utf-8"))
    statements = [sqlparse.format(s, strip_comments=True).strip()
                  for s in sqlparse.split(text)]
    statements = [s for s in statements if s and s != ";"]
    required = set(re.findall(r"%\((\w+)\)s", text))
    if not isinstance(params, dict) or required - params.keys():
        p.error("Input JSON must contain all required keys: " + ", ".join(sorted(required)))
    cn = mysql.connector.connect(host=a.host, port=a.port, user=a.user,
        password=getpass.getpass("MySQL password: "), database=a.database,
        autocommit=False)
    outputs = []
    try:
        cn.start_transaction()
        with cn.cursor(buffered=True) as cur:
            for index, statement in enumerate(statements):
                cur.execute(statement, params if re.search(r"%\(\w+\)s", statement) else None)
                if cur.description:
                    headers = [c[0] for c in cur.description]
                    rows = cur.fetchall()
                    if index == 0:
                        if headers != ["ok"] or len(rows) != 1 or rows[0][0] != 1:
                            raise ValueError("Validation failed; operation cancelled")
                    else:
                        outputs.append({"columns": headers, "rows": rows})
                elif index == 0:
                    raise ValueError("First statement must be a validation SELECT")
        if a.commit:
            cn.commit()
            outcome = "COMMITTED"
        else:
            cn.rollback()
            outcome = "ROLLED BACK (preview only; generated IDs are not saved)"
        print(json.dumps({"outcome": outcome, "results": outputs}, default=str, indent=2))
    except BaseException:
        cn.rollback()
        raise
    finally:
        cn.close()


if __name__ == "__main__":
    main()
