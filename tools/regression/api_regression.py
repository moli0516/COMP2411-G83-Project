"""Real HTTP + MySQL regression; commits remain in a disposable database."""
import json
import subprocess
import sys
import traceback
import uuid
from common import ROOT, Run, Server, check, credentials, options, request_id, request_values, same_table, snapshot, sql


def main():
    args = options(__doc__)
    run = Run("api")
    error = None
    try:
        with run.case("existing_webui_unit_tests"):
            p = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "webui", "-p", "test_webui.py", "-v"],
                               cwd=ROOT, capture_output=True, text=True, timeout=120)
            (run.work/"unit.stdout.txt").write_text(p.stdout, encoding="utf-8")
            (run.work/"unit.stderr.txt").write_text(p.stderr, encoding="utf-8")
            check(p.returncode == 0, "Existing WebUI tests failed")
        config = credentials(args, run)
        with Server(args, config, run) as server:
            with run.case("config_connection_and_security"):
                check(server.cfg["queries"] == [f"Q{i:02d}" for i in range(1, 9)], "Expected Q01-Q08")
                check(len(server.cfg["operations"]) == 12 and all(o["enabled"] for o in server.cfg["operations"]), "Expected 12 enabled operations")
                data = server.call("/api/connection", {})
                check(data["rows"][0][data["columns"].index("current_database")] == args.database, "Connection identity mismatch")
                server.call("/api/connection", {}, {"X-CSRF-Token": ""}, expected=403)
                server.call("/api/connection", {}, {"Origin": "http://evil.example"}, expected=403)
                server.call("/api/config", headers={"Host": "evil.example"}, expected=403)
                server.call("/api/query/Q99", {}, expected=400)
                server.call("/api/table/not_a_table", {}, expected=400)
                server.call("/api/operation/01_request_registration/commit", {"ticket": "invalid"}, expected=400)
            before = snapshot(config)
            for qid in server.cfg["queries"]:
                with run.case(qid+"_http_matches_direct_sql"):
                    actual = server.call("/api/query/"+qid, {})
                    expected = sql(config, (ROOT/"queries"/(qid+".sql")).read_text(encoding="utf-8-sig"))
                    check(same_table(actual, expected), qid+" API/direct SQL mismatch")
                    (run.work/(qid+".json")).write_text(json.dumps(actual, indent=2), encoding="utf-8")
            with run.case("all_table_browsers_and_read_only_snapshot"):
                for table in server.cfg["tables"]:
                    data = server.call("/api/table/"+table, {})
                    check(len(data["rows"]) <= 100 and bool(data["columns"]), "Table response shape")
                check(snapshot(config) == before, "Read-only requests changed table data")
            marker = "regression-api-"+uuid.uuid4().hex
            values = request_values(config, marker)
            path = "/api/operation/01_request_registration"
            with run.case("preview_rollback_and_validation_failure_safety"):
                server.call(path+"/preview", {"values": dict(values, fault_description=" ")}, expected=400)
                preview = server.call(path+"/preview", {"values": values})
                check(preview["outcome"] == "PREVIEW ROLLED BACK", "Wrong preview outcome")
                check(snapshot(config) == before, "Preview/invalid operation changed rows")
            with run.case("commit_dynamic_ids_and_single_use_ticket"):
                committed = server.call(path+"/commit", {"ticket": preview["ticket"]})
                check(committed["outcome"] == "COMMITTED", "Wrong commit outcome")
                rid = request_id(committed)
                row = sql(config, "SELECT request_id FROM ServiceRequest WHERE fault_description=%s", (marker,))
                check(row["rows"] == [[str(rid)]], "Committed ID/data mismatch")
                server.call(path+"/commit", {"ticket": preview["ticket"]}, expected=400)
                check(sql(config, "SELECT COUNT(*) FROM RequestItem WHERE request_id=%s", (rid,))["rows"] == [["1"]], "Duplicate/missing item")
                (run.work/"committed-fixture.json").write_text(json.dumps({"request_id": rid, "marker": marker}), encoding="utf-8")
            with run.case("quotation_001_preview_and_zero_rejected"):
                path = "/api/operation/07_issue_quotation/preview"
                values = {"request_id": str(rid), "quotation_date": "2026-10-31", "quoted_amount": "0.01"}
                before = snapshot(config)
                server.call(path, {"values": dict(values, quoted_amount="0")}, expected=400)
                result = server.call(path, {"values": values})
                check(result["outcome"] == "PREVIEW ROLLED BACK", "0.01 preview failed")
                check(snapshot(config) == before, "Quotation preview changed data")
    except BaseException:
        error = traceback.format_exc()
    return run.finish(error)


if __name__ == "__main__":
    raise SystemExit(main())
