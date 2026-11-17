"""Private owned-server bootstrap. Credentials arrive on stdin, not argv/files."""
import importlib.util
import json
import sys
from pathlib import Path


def main():
    payload = json.loads(sys.stdin.readline())
    root = Path(__file__).resolve().parents[2]
    spec = importlib.util.spec_from_file_location("regression_webui", root/"webui"/"server.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    port = payload["web_port"]
    web_config = dict(payload["config"])
    web_config.pop("connection_timeout", None)
    module.CONFIG.update(web_config)
    module.app.config["ALLOWED_HOSTS"] = {f"127.0.0.1:{port}", f"localhost:{port}"}
    module.app.run(host="127.0.0.1", port=port, debug=False, use_reloader=False)


if __name__ == "__main__":
    main()
