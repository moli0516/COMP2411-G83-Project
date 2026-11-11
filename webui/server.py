import argparse
import csv
import getpass
import io
import json
import os
import re
import secrets
import threading
import time
from pathlib import Path

import mysql.connector
import sqlparse
from flask import Flask, jsonify, request, send_from_directory

ROOT = Path(__file__).resolve().parents[1]
STATIC = Path(__file__).resolve().parent / "static"
app = Flask(__name__, static_folder=str(STATIC), static_url_path="/static")
app.config["MAX_CONTENT_LENGTH"] = 65536
TOKEN = secrets.token_urlsafe(32)
CONFIG = {}
PREVIEWS = {}
LOCK = threading.Lock()
QUERIES = {f"Q{i:02d}": ROOT / "queries" / f"Q{i:02d}.sql" for i in range(1, 9)}
OPERATIONS = {
    "01_request_registration", "02_quotation_acceptance", "03_receive_item",
    "04_inspection", "05_incident_corrective_action", "06_return_and_closure",
    "07_issue_quotation", "08_add_request_item", "09_submit_repair",
    "10_start_action", "11_resolve_action", "12_verify_action"
}
TABLES = {"Customer", "Equipment", "Staff", "ServiceRequest", "RequestItem", "Quotation",
          "ServiceJob", "Inspection", "InspectionResult", "Incident", "CorrectiveAction",
          "IncidentCorrectiveAction"}


def statements(text):
    return [x for s in sqlparse.split(text)
            if (x := sqlparse.format(s, strip_comments=True).strip().rstrip(";").strip())]


def operation(name):
    if name not in OPERATIONS:
        raise ValueError("Unknown operation")
    path = ROOT / "operations" / f"{name}.sql"
    text = path.read_text(encoding="utf-8-sig")
    parts = statements(text)
    fields = sorted(set(re.findall(r"%\((\w+)\)s", text)))
    if not fields or not parts or not re.match(r"SELECT\b", parts[0], re.I) or not re.search(r"\bAS\s+ok\s*$", parts[0], re.I):
        raise ValueError("Needs validated parameterized template: first SELECT must return AS ok")
    allowed = {"SELECT", "INSERT", "UPDATE", "SET"}
    if any(p.split()[0].upper() not in allowed for p in parts):
        raise ValueError("Operation contains an unsupported statement")
    return parts, fields, text


def connect():
    return mysql.connector.connect(**CONFIG, autocommit=False, connection_timeout=5)


def pack(cur):
    return {"columns": [c[0] for c in cur.description],
            "rows": [[None if v is None else str(v) for v in row] for row in cur.fetchall()]}


def read_query(sql):
    parts = statements(sql)
    if len(parts) != 1 or sqlparse.parse(parts[0])[0].get_type() != "SELECT":
        raise ValueError("Query file must contain exactly one SELECT")
    cn = connect()
    try:
        cn.start_transaction(readonly=True)
        with cn.cursor(buffered=True) as cur:
            cur.execute(parts[0])
            result = pack(cur)
        cn.rollback()
        return result
    finally:
        cn.close()


def run_operation(name, values, commit=False):
    parts, fields, _ = operation(name)
    if not isinstance(values, dict) or set(values) != set(fields):
        raise ValueError("Input keys must exactly match the operation fields")
    cn = connect()
    try:
        cn.start_transaction()
        results = []
        with cn.cursor(buffered=True) as cur:
            for i, sql in enumerate(parts):
                cur.execute(sql, values if re.search(r"%\(\w+\)s", sql) else None)
                if i == 0:
                    if cur.description is None:
                        raise ValueError("Validation query returned no result")
                    columns = [c[0] for c in cur.description]
                    rows = cur.fetchall()
                    if columns != ["ok"] or len(rows) != 1 or rows[0][0] != 1:
                        raise ValueError("Business-rule validation failed; no changes saved")
                elif cur.description:
                    results.append(pack(cur))
                else:
                    results.append({"affected_rows": cur.rowcount})
        if commit:
            cn.commit()
        else:
            cn.rollback()
        return {"outcome": "COMMITTED" if commit else "PREVIEW ROLLED BACK", "results": results}
    except BaseException:
        cn.rollback()
        raise
    finally:
        cn.close()


@app.before_request
def local_guard():
    if request.host not in app.config.get("ALLOWED_HOSTS", set()):
        return jsonify(error="Unapproved Host header"), 403
    if request.method == "POST":
        expected = f"http://{request.host}"
        if request.headers.get("Origin") not in (None, expected):
            return jsonify(error="Cross-origin requests are blocked"), 403
        if not secrets.compare_digest(request.headers.get("X-CSRF-Token", ""), TOKEN):
            return jsonify(error="Missing/invalid local session token"), 403


@app.after_request
def security_headers(response):
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'"
    return response


@app.errorhandler(Exception)
def handle_error(error):
    from werkzeug.exceptions import HTTPException
    if isinstance(error, HTTPException):
        return jsonify(error=error.description), error.code
    if isinstance(error, mysql.connector.Error):
        message = f"MySQL error {error.errno}: {error.msg}"
    else:
        message = str(error)
    if CONFIG.get("password"):
        message = message.replace(CONFIG["password"], "[redacted]")
    return jsonify(error=message), 400


@app.get("/")
def index():
    return send_from_directory(STATIC, "index.html")


@app.get("/api/config")
def config():
    ops = []
    for name in sorted(OPERATIONS):
        path = ROOT / "operations" / f"{name}.sql"
        if not path.exists():
            continue
        try:
            _, fields, _ = operation(name)
            ops.append({"id": name, "fields": fields, "enabled": True})
        except ValueError as e:
            ops.append({"id": name, "fields": [], "enabled": False, "reason": str(e)})
    return jsonify(token=TOKEN, database=CONFIG.get("database"),
                   endpoint=f"{CONFIG.get('host')}:{CONFIG.get('port')}",
                   queries=[q for q, p in QUERIES.items() if p.exists()],
                   operations=ops, tables=sorted(TABLES))


@app.post("/api/connection")
def connection_test():
    return jsonify(read_query("SELECT USER() AS login_identity, CURRENT_USER() AS matched_account, @@hostname AS server_hostname, @@port AS server_port, @@version AS server_version, DATABASE() AS current_database"))


@app.post("/api/query/<qid>")
def query(qid):
    if qid not in QUERIES:
        raise ValueError("Unknown query ID")
    return jsonify(read_query(QUERIES[qid].read_text(encoding="utf-8-sig")))


@app.post("/api/table/<name>")
def table(name):
    if name not in TABLES:
        raise ValueError("Unknown table")
    return jsonify(read_query(f"SELECT * FROM `{name}` ORDER BY 1 LIMIT 100"))


@app.post("/api/operation/<name>/preview")
def preview(name):
    values = request.get_json()["values"]
    with LOCK:
        result = run_operation(name, values)
        now = time.time()
        for key in list(PREVIEWS):
            if PREVIEWS[key]["expires"] < now:
                del PREVIEWS[key]
        if len(PREVIEWS) >= 50:
            PREVIEWS.pop(next(iter(PREVIEWS)))
        ticket = secrets.token_urlsafe(32)
        PREVIEWS[ticket] = {"name": name, "values": values, "expires": now + 300,
                            "sql": operation(name)[2]}
    return jsonify(**result, ticket=ticket)


@app.post("/api/operation/<name>/commit")
def commit(name):
    with LOCK:
        item = PREVIEWS.pop(request.get_json().get("ticket", ""), None)
        if not item or item["name"] != name or item["expires"] < time.time():
            raise ValueError("Preview expired or already used; preview again")
        if operation(name)[2] != item["sql"]:
            raise ValueError("Operation SQL changed; preview again")
        return jsonify(run_operation(name, item["values"], commit=True))


def main():
    p = argparse.ArgumentParser(description="Local-only repair-centre Web UI")
    p.add_argument("--user", required=True)
    p.add_argument("--database", required=True)
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=3306, help="MySQL port")
    p.add_argument("--web-port", type=int, default=8080)
    a = p.parse_args()
    CONFIG.update(host=a.host, port=a.port, user=a.user, database=a.database,
                  password=getpass.getpass("MySQL password: "))
    app.config["ALLOWED_HOSTS"] = {f"127.0.0.1:{a.web_port}", f"localhost:{a.web_port}"}
    print(f"Open http://127.0.0.1:{a.web_port} — local development only; no debug/reloader")
    app.run(host="127.0.0.1", port=a.web_port, debug=False, use_reloader=False)


if __name__ == "__main__":
    main()
