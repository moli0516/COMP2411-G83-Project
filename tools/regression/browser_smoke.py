"""Playwright smoke regression against the actual UI, owned Flask server and MySQL."""
import csv
import io
import json
import traceback
import uuid
from common import Run, Server, check, credentials, options, request_id, request_values, snapshot, sql


def main():
    args = options(__doc__)
    run = Run("browser")
    error = None
    try:
        from playwright.sync_api import sync_playwright, expect
        config = credentials(args, run)
        with Server(args, config, run) as server, sync_playwright() as pw:
            browser = pw.chromium.launch(headless=not args.headed)
            context = browser.new_context(accept_downloads=True)
            context.tracing.start(screenshots=True, snapshots=True, sources=True)
            page = context.new_page()
            page.set_default_timeout(15000)
            js_errors = []
            page.on("pageerror", lambda exc: js_errors.append(str(exc)))
            try:
                with run.case("page_boot_and_labels"):
                    page.goto(server.url)
                    expect(page.locator("#dbBadge")).to_have_text(args.database)
                    expect(page.locator("#queryId option")).to_have_count(8)
                    expect(page.locator("#operationId option")).to_have_count(12)
                    for option in page.locator("#queryId option").all():
                        check(len(option.inner_text()) > 5, "Missing descriptive query label")
                    expect(page.locator("#queryDescription")).to_contain_text("2026-03-01")
                    expect(page.locator("#exportCsv")).to_be_disabled()
                before = snapshot(config)
                for i in range(1, 9):
                    qid = f"Q{i:02d}"
                    with run.case(qid+"_render_download_and_stale_export"):
                        page.locator("#queryId").select_option(qid)
                        # A select_option on the existing value may not dispatch change.
                        page.locator("#queryId").dispatch_event("change")
                        expect(page.locator("#exportCsv")).to_be_disabled()
                        with page.expect_response(lambda r: r.url.endswith("/api/query/"+qid) and r.request.method == "POST") as pending:
                            page.locator("#runQuery").click()
                        check(pending.value.status == 200, qid+" HTTP failure")
                        data = pending.value.json()
                        expect(page.locator("#exportCsv")).to_be_enabled()
                        expect(page.locator("#queryResults tbody tr")).to_have_count(len(data["rows"]))
                        check(page.locator("#queryResults th").all_text_contents() == data["columns"], "Rendered columns differ")
                        for tr, values in zip(page.locator("#queryResults tbody tr").all(), data["rows"]):
                            check(tr.locator("td").all_text_contents() == ["NULL" if v is None else v for v in values], "Rendered values differ")
                        with page.expect_download() as download:
                            page.locator("#exportCsv").click()
                        check(download.value.suggested_filename == qid+".csv", "Download filename mismatch")
                        target = run.work/(qid+".csv")
                        download.value.save_as(str(target))
                        with target.open(encoding="utf-8", newline="") as f:
                            actual = list(csv.reader(f))
                        expected = [data["columns"]] + [[r"\N" if v is None else v for v in row] for row in data["rows"]]
                        check(actual == expected, "Downloaded CSV differs from API, including NULL/empty handling")
                        if qid == "Q06":
                            check(not data["rows"], "Expected a clean seed Q06 baseline; use a fresh regression DB")
                            expect(page.locator("#notice")).to_contain_text("Zero rows is expected")
                with run.case("connection_and_readonly_safety"):
                    page.locator('nav button[data-pane="connection"]').click()
                    with page.expect_response(lambda r: r.url.endswith("/api/connection")) as pending:
                        page.locator("#testConnection").click()
                    check(pending.value.status == 200, "Connection check failed")
                    expect(page.locator("#connectionResults")).to_contain_text(args.database)
                    check(snapshot(config) == before, "Read-only UI workflow changed table data")
                with run.case("operation_controls"):
                    page.locator('nav button[data-pane="operations"]').click()
                    page.locator("#operationId").select_option("07_issue_quotation")
                    amount = page.locator('[name="quoted_amount"]')
                    expect(amount).to_have_attribute("min", "0.01")
                    amount.fill("0.01")
                    check(amount.evaluate("el => el.checkValidity()"), "0.01 rejected by amount control")
                    amount.fill("0")
                    check(not amount.evaluate("el => el.checkValidity()"), "Zero accepted by amount control")
                    page.locator("#operationId").select_option("04_inspection")
                    check(page.locator('select[name="result"] option').all_text_contents() == ["PASS", "FAIL"], "Result options differ")
                    check(len(page.locator('select[name="criterion_name"] option').all()) == 6, "Criterion options differ")
                    page.locator("#operationId").select_option("05_incident_corrective_action")
                    check(page.locator('select[name="severity"] option').all_text_contents() == ["LOW", "MEDIUM", "HIGH"], "Severity options differ")
                marker = "regression-browser-"+uuid.uuid4().hex
                values = request_values(config, marker)
                path = "/api/operation/01_request_registration"
                with run.case("preview_error_rollback_and_edit_invalidation"):
                    page.locator("#operationId").select_option("01_request_registration")
                    for key, value in dict(values, fault_description=" ").items():
                        page.locator('[name="'+key+'"]').fill(value)
                    with page.expect_response(lambda r: r.url.endswith(path+"/preview")) as pending:
                        page.locator("#previewButton").click()
                    check(pending.value.status == 400, "Blank description must fail")
                    expect(page.locator("#notice")).to_have_class("error")
                    expect(page.locator("#commitButton")).to_be_disabled()
                    page.locator('[name="fault_description"]').fill(marker)
                    with page.expect_response(lambda r: r.url.endswith(path+"/preview")) as pending:
                        page.locator("#previewButton").click()
                    check(pending.value.status == 200, "Preview failed")
                    expect(page.locator("#commitButton")).to_be_enabled()
                    expect(page.locator("#operationResults")).to_contain_text("PREVIEW ROLLED BACK")
                    check(snapshot(config) == before, "Invalid operation or preview saved rows")
                    page.locator('[name="fault_description"]').fill(marker+"-edited")
                    expect(page.locator("#commitButton")).to_be_disabled()
                    page.locator('[name="fault_description"]').fill(marker)
                    with page.expect_response(lambda r: r.url.endswith(path+"/preview")):
                        page.locator("#previewButton").click()
                    expect(page.locator("#commitButton")).to_be_enabled()
                with run.case("cancel_commit_then_commit_and_invalidate_export"):
                    # Populate an export while retaining the valid operation preview.
                    page.locator('nav button[data-pane="queries"]').click()
                    with page.expect_response(lambda r: "/api/query/" in r.url):
                        page.locator("#runQuery").click()
                    expect(page.locator("#exportCsv")).to_be_enabled()
                    page.locator('nav button[data-pane="operations"]').click()
                    page.once("dialog", lambda d: d.dismiss())
                    page.locator("#commitButton").click()
                    expect(page.locator("body")).not_to_have_attribute("aria-busy", "true")
                    expect(page.locator("#commitButton")).to_be_enabled()
                    check(snapshot(config) == before, "Cancelling confirmation changed data")
                    page.once("dialog", lambda d: d.accept())
                    with page.expect_response(lambda r: r.url.endswith(path+"/commit")) as pending:
                        page.locator("#commitButton").click()
                    check(pending.value.status == 200, "Commit HTTP failure")
                    result = pending.value.json()
                    rid = request_id(result)
                    expect(page.locator("#operationResults")).to_contain_text("COMMITTED")
                    expect(page.locator("#commitButton")).to_be_disabled()
                    expect(page.locator("#exportCsv")).to_be_disabled()
                    check(sql(config, "SELECT request_id FROM ServiceRequest WHERE fault_description=%s", (marker,))["rows"] == [[str(rid)]], "Committed data/ID mismatch")
                    (run.work/"committed-fixture.json").write_text(json.dumps({"request_id": rid, "marker": marker}), encoding="utf-8")
                with run.case("no_uncaught_javascript_errors"):
                    check(not js_errors, repr(js_errors))
                page.screenshot(path=str(run.work/"final.png"), full_page=True)
            except BaseException:
                error = traceback.format_exc()
                try:
                    page.screenshot(path=str(run.work/"failure.png"), full_page=True)
                    (run.work/"failure.html").write_text(page.content(), encoding="utf-8")
                except Exception:
                    pass
            finally:
                (run.work/"page-errors.txt").write_text("\n".join(js_errors), encoding="utf-8")
                try:
                    context.tracing.stop(path=str(run.work/"trace.zip"))
                finally:
                    browser.close()
    except BaseException:
        error = traceback.format_exc()
    return run.finish(error)


if __name__ == "__main__":
    raise SystemExit(main())
