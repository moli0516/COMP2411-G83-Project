import importlib.util
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("repair_webui_server", Path(__file__).with_name("server.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class WebUITest(unittest.TestCase):
    def setUp(self):
        m.app.config.update(TESTING=True, ALLOWED_HOSTS={"localhost"})
        self.client = m.app.test_client()
        self.headers = {"X-CSRF-Token": m.TOKEN}

    def test_config(self):
        self.assertEqual(self.client.get("/api/config").status_code, 200)

    def test_host(self):
        self.assertEqual(self.client.get("/", headers={"Host":"evil.example"}).status_code, 403)

    def test_csrf(self):
        self.assertEqual(self.client.post("/api/connection").status_code, 403)

    def test_origin(self):
        h = dict(self.headers, Origin="http://evil.example")
        self.assertEqual(self.client.post("/api/connection", headers=h).status_code, 403)

    def test_invalid_table(self):
        with patch.object(m, "connect") as cn:
            r = self.client.post("/api/table/not_a_table", headers=self.headers)
            self.assertEqual(r.status_code, 400)
            cn.assert_not_called()

    def test_no_commit_without_preview(self):
        with patch.object(m, "connect") as cn:
            r = self.client.post("/api/operation/03_receive_item/commit", json={"ticket":"bad"},headers=self.headers)
            self.assertEqual(r.status_code, 400)
            cn.assert_not_called()

    def test_reject_multiple_queries(self):
        with patch.object(m, "connect") as cn:
            with self.assertRaises(ValueError): m.read_query("SELECT 1; SELECT 2;")
            cn.assert_not_called()

    def test_reject_update_query(self):
        with patch.object(m, "connect") as cn:
            with self.assertRaises(ValueError): m.read_query("UPDATE Staff SET active_status=0")
            cn.assert_not_called()

    def test_split(self):
        self.assertEqual(m.statements("-- comment\nSELECT ';' AS x;"), ["SELECT ';' AS x"])

if __name__ == "__main__":
    unittest.main()
