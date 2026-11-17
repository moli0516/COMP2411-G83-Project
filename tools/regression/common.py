"""External regression helpers; no production code is patched or mocked."""
import argparse
import contextlib
import datetime
import getpass
import hashlib
import json
import os
import re
import socket
import subprocess
import sys
import time
import traceback
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TABLES = ("Customer", "Staff", "Equipment", "ServiceRequest", "RequestItem", "Quotation",
          "ServiceJob", "Inspection", "InspectionResult", "Incident", "CorrectiveAction",
          "IncidentCorrectiveAction")


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def options(description):
    p = argparse.ArgumentParser(description=description)
    p.add_argument("--host", default="127.0.0.1", help="MySQL host")
    p.add_argument("--port", type=int, default=3306, help="MySQL port")
    p.add_argument("--user", required=True)
    p.add_argument("--database", required=True)
    p.add_argument("--web-port", type=int, default=18080)
    p.add_argument("--headed", action="store_true", help="Browser runner only")
    return p.parse_args()


class Run:
    def __init__(self, name):
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d-%H%M%S-%f")
        self.work = ROOT / "regression-results" / (name + "-" + stamp)
        self.work.mkdir(parents=True)
        self.name, self.cases, self.secret = name, [], ""
        self.started = datetime.datetime.now(datetime.timezone.utc).isoformat()
        git = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                             capture_output=True, text=True, timeout=10)
        self.commit = git.stdout.strip() if git.returncode == 0 else None

    def clean(self, text):
        return text.replace(self.secret, "[redacted]") if self.secret else text

    @contextlib.contextmanager
    def case(self, name):
        start = time.monotonic()
        try:
            yield
        except BaseException:
            self.cases.append({"name": name, "status": "FAIL",
                               "seconds": time.monotonic()-start})
            raise
        else:
            self.cases.append({"name": name, "status": "PASS",
                               "seconds": time.monotonic()-start})

    def finish(self, error=None):
        data = {"runner": self.name, "started_utc": self.started, "commit": self.commit,
                "passed": error is None, "cases": self.cases,
                "error": self.clean(error) if error else None,
                "scope": "External regression; separate from the 95-case SQL suite"}
        (self.work/"result.json").write_text(json.dumps(data, indent=2)+"\n", encoding="utf-8")
        if error:
            (self.work/"failure.txt").write_text(self.clean(error), encoding="utf-8")
        print(("FAIL" if error else "PASS") + ": " + str(self.work))
        return int(error is not None)


def credentials(args, run):
    check(
        len(args.database) <= 64
        and re.fullmatch(
            r"comp2411_test(?:_[A-Za-z0-9_]+)?",
            args.database,
        ) is not None,
        "Target must be comp2411_test or comp2411_test_<suffix>",
    )
    print("WARNING: real commits and preview AUTO_INCREMENT consumption occur; fixtures remain.")
    check(input("Type the exact disposable database name: ") == args.database, "Confirmation mismatch")
    run.secret = getpass.getpass("MySQL password: ")
    return dict(host=args.host, port=args.port, user=args.user, password=run.secret,
                database=args.database, connection_timeout=5)


@contextlib.contextmanager
def database(config):
    import mysql.connector
    cn = mysql.connector.connect(**config, autocommit=True)
    try:
        yield cn
    finally:
        cn.close()


def sql(config, statement, values=None):
    with database(config) as cn, cn.cursor(buffered=True) as cur:
        cur.execute(statement, values)
        return {"columns": [d[0] for d in cur.description],
                "rows": [[None if v is None else str(v) for v in row] for row in cur.fetchall()]}


def snapshot(config):
    with database(config) as cn:
        cn.start_transaction(readonly=True, consistent_snapshot=True)
        try:
            result = {}
            with cn.cursor(buffered=True) as cur:
                for table in TABLES:
                    cur.execute(f"SELECT * FROM `{table}`")
                    rows = sorted(json.dumps(row, default=str, ensure_ascii=True) for row in cur.fetchall())
                    result[table] = {"rows": len(rows), "sha256": hashlib.sha256(
                        "\n".join(rows).encode()).hexdigest()}
            return result
        finally:
            cn.rollback()


def same_table(a, b):
    return a["columns"] == b["columns"] and sorted(map(tuple, a["rows"])) == sorted(map(tuple, b["rows"]))


def owner(config):
    data = sql(config, "SELECT equipment_id, customer_id FROM Equipment ORDER BY equipment_id LIMIT 1")
    check(bool(data["rows"]), "Load schema, seed, views and indexes into the disposable DB first")
    equipment, customer = data["rows"][0]
    return {"equipment_id": equipment, "customer_id": customer}


def request_values(config, marker):
    return dict(owner(config), request_date="2026-10-31", fault_description=marker)


def request_id(result):
    for item in result.get("results", []):
        if "request_id" in item.get("columns", []):
            return int(item["rows"][0][item["columns"].index("request_id")])
    raise AssertionError("Committed operation did not return request_id")


class Server:
    def __init__(self, args, config, run):
        self.args, self.config, self.run = args, config, run
        self.url = f"http://127.0.0.1:{args.web_port}"
        self.proc, self.streams, self.token = None, [], None

    def call(self, path, body=None, headers=None, expected=200):
        h = {}
        if body is not None:
            h.update({"Content-Type": "application/json", "X-CSRF-Token": self.token or ""})
        h.update(headers or {})
        req = urllib.request.Request(self.url+path, data=None if body is None else json.dumps(body).encode(), headers=h)
        try:
            response = urllib.request.urlopen(req, timeout=30)
        except urllib.error.HTTPError as exc:
            response = exc
        with response:
            code, raw = response.status, response.read()
        if code != expected:
            detail = self.run.clean(
                raw.decode("utf-8", errors="replace")
            )
            raise AssertionError(
                f"{path}: expected HTTP {expected}, got {code}; "
                f"response={detail[:2000]}"
            )

        return json.loads(raw) if raw else None

    def __enter__(self):
        try:
            with socket.socket() as probe:
                probe.bind(("127.0.0.1", self.args.web_port))
            for name in ("server.stdout.txt", "server.stderr.txt"):
                self.streams.append((self.run.work/name).open("w", encoding="utf-8"))
            self.proc = subprocess.Popen([sys.executable, str(Path(__file__).with_name("serve.py"))],
                cwd=ROOT, stdin=subprocess.PIPE, stdout=self.streams[0], stderr=self.streams[1], text=True)
            self.proc.stdin.write(json.dumps({"config": self.config, "web_port": self.args.web_port})+"\n")
            self.proc.stdin.close()
            deadline = time.monotonic()+20
            while True:
                check(self.proc.poll() is None, "Owned server exited; inspect server logs")
                try:
                    cfg = self.call("/api/config")
                    check(cfg["database"] == self.args.database, "Wrong server database")
                    self.token = cfg["token"]
                    self.cfg = cfg
                    return self
                except (OSError, AssertionError):
                    if time.monotonic() > deadline:
                        raise TimeoutError("Owned server did not become ready")
                    time.sleep(0.1)
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def __exit__(self, *unused):
        if self.proc is not None and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(timeout=5)
        for stream in self.streams:
            stream.close()
