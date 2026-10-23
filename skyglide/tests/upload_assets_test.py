#!/usr/bin/env python3
"""Tests scripts/upload_assets.py against a local stand-in for the Roblox Open Cloud Assets API.

The mock follows the documented flow (cloud/guides/usage-assets.md in Roblox/creator-docs):
POST /assets/v1/assets takes multipart form data ("request" JSON + "fileContent") with an
x-api-key header and returns an operation; GET /assets/v1/operations/{id} reports
done/response.assetId. It also throws in a rate limit (429 + Retry-After), a slow operation and a
rejected upload. The script runs on a copy of the project, so the real manifest is untouched.
It cannot prove the live API behaves the same; it checks the request shape, retries, polling,
error handling and the files the script writes.

usage: python3 tests/upload_assets_test.py
"""
import email.parser
import email.policy
import http.server
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import threading

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
SCRIPT = ROOT / "scripts" / "upload_assets.py"
API_KEY = "test-key"

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
        print("FAILED: " + msg)


class Mock(http.server.BaseHTTPRequestHandler):
    state = {"posts": 0, "ops": {}, "rate_limited": False, "reject": set(), "bad": []}

    def log_message(self, *args):
        pass

    def reply(self, code, body, headers=None):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        st = self.state
        if self.headers.get("x-api-key") != API_KEY:
            return self.reply(401, {"error": "bad key"})
        if self.path != "/assets/v1/assets":
            return self.reply(404, {})
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if not st["rate_limited"]:
            st["rate_limited"] = True
            return self.reply(429, {"error": "slow down"}, {"Retry-After": "0"})
        raw = b"Content-Type: " + self.headers.get("Content-Type").encode() + b"\r\n\r\n" + body
        msg = email.parser.BytesParser(policy=email.policy.HTTP).parsebytes(raw)
        parts = {p.get_param("name", header="content-disposition"): p for p in msg.iter_parts()}
        try:
            meta = json.loads(parts["request"].get_content())
            png = parts["fileContent"].get_payload(decode=True)
            ok = (meta["assetType"] == "Decal" and meta["creationContext"]["creator"] == {"userId": "42"}
                  and parts["fileContent"].get_content_type() == "image/png" and png[:8] == b"\x89PNG\r\n\x1a\n"
                  and meta["displayName"].startswith("SkyGlide "))
        except Exception as e:  # malformed request
            ok, meta = False, {"displayName": repr(e)}
        if not ok:
            st["bad"].append(meta.get("displayName"))
            return self.reply(400, {"error": "bad request"})
        st["posts"] += 1
        op = f"op{st['posts']}"
        st["ops"][op] = {"polls": 0, "name": meta["displayName"], "id": str(9000 + st["posts"])}
        self.reply(200, {"path": f"operations/{op}", "done": False})

    def do_GET(self):
        st = self.state
        if self.headers.get("x-api-key") != API_KEY:
            return self.reply(401, {})
        prefix = "/assets/v1/operations/"
        op = st["ops"].get(self.path[len(prefix):]) if self.path.startswith(prefix) else None
        if op is None:
            return self.reply(404, {})
        op["polls"] += 1
        path = self.path[len("/assets/v1/"):]
        if op["polls"] < 2:
            return self.reply(200, {"path": path, "done": False})
        if any(r in op["name"] for r in st["reject"]):
            return self.reply(200, {"path": path, "done": True, "error": {"code": "INVALID_ARGUMENT", "message": "rejected"}})
        self.reply(200, {"path": path, "done": True, "response": {"assetId": op["id"], "assetType": "ASSET_TYPE_DECAL"}})


def run(root, port, *extra):
    cmd = [sys.executable, str(SCRIPT), "--root", str(root), "--base-url", f"http://127.0.0.1:{port}",
           "--api-key", API_KEY, "--user-id", "42", "--poll", "0.01", *extra]
    return subprocess.run(cmd, capture_output=True, text=True, timeout=120)


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Mock)
    port = server.server_address[1]
    threading.Thread(target=server.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        shutil.copytree(ROOT / "assets", root / "assets")
        (root / "src" / "shared" / "Config").mkdir(parents=True)
        manifest = json.loads((root / "assets" / "manifest.json").read_text())
        keys = sorted(manifest["icons"])

        # 1. three icons, one rejected by "moderation"
        Mock.state["reject"] = {"Crown"}
        res = run(root, port, "--only", "Wins,Skill,Crown")
        print(res.stdout.strip())
        check(res.returncode == 1, "a rejected icon makes the run fail (exit 1)")
        check(Mock.state["rate_limited"], "the 429 was served and retried")
        check(not Mock.state["bad"], f"every upload request is well formed (bad: {Mock.state['bad']})")
        m = json.loads((root / "assets" / "manifest.json").read_text())
        check(m["icons"]["Wins"]["assetId"] and m["icons"]["Skill"]["assetId"], "uploaded ids are stored in the manifest")
        check(m["icons"]["Crown"]["assetId"] == "", "the rejected icon has no id")
        lua = (root / "src" / "shared" / "Config" / "AssetIds.luau").read_text()
        wins_id = m["icons"]["Wins"]["assetId"]
        check(f'Wins = "rbxthumb://type=Asset&id={wins_id}&w=420&h=420",' in lua, "AssetIds.luau gets an rbxthumb content string")
        check('Crown = "",' in lua, "icons without an id stay empty (emoji fallback)")
        check(all(f"\t\t{k} = " in lua for k in keys), "AssetIds.luau lists every icon in the manifest")

        # 2. a re-run skips what is done and retries the failure
        Mock.state["reject"] = set()
        before = Mock.state["posts"]
        res = run(root, port, "--only", "Wins,Skill,Crown")
        check(res.returncode == 0, "the retry succeeds")
        check(Mock.state["posts"] == before + 1, "only the missing icon is uploaded again")

        # 3. a hand-uploaded image id in "content" wins and is never uploaded
        m = json.loads((root / "assets" / "manifest.json").read_text())
        m["icons"]["Gifts"]["content"] = "rbxassetid://123456"
        (root / "assets" / "manifest.json").write_text(json.dumps(m))
        before = Mock.state["posts"]
        res = run(root, port, "--only", "Gifts")
        lua = (root / "src" / "shared" / "Config" / "AssetIds.luau").read_text()
        check(res.returncode == 0 and Mock.state["posts"] == before, "an icon with a hand-set content string is not uploaded")
        check('Gifts = "rbxassetid://123456",' in lua, "the hand-set content string is written as is")

        # 4. without a key the script refuses before touching anything
        res = subprocess.run([sys.executable, str(SCRIPT), "--root", str(root), "--user-id", "42"], capture_output=True, text=True,
                             env={"PATH": "/usr/bin:/bin"})
        check(res.returncode != 0 and "api-key" in res.stderr, "a missing API key is reported")
    server.shutdown()
    print(f"upload_assets_test: {len(failures)} failures")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
