#!/usr/bin/env python3
"""Bundle and run the pure-logic Luau tests with the standalone `luau` CLI.

The Luau CLI runs each required module in its own sandboxed environment, so Roblox globals
stubbed in the test file (Color3, Enum) would not reach the data modules. This script inlines
every `require("../src/...")` as a local function inside one chunk so the stubs are shared.

Usage:  python3 tests/run_tests.py [path/to/luau]
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "tests" / "data.spec.luau"
REQUIRE = re.compile(r'require\("\.\./(src/[A-Za-z0-9_/]+)"\)')


def bundle(source: str) -> str:
    modules: dict[str, str] = {}

    def collect(text: str) -> None:
        for path in REQUIRE.findall(text):
            if path not in modules:
                body = (ROOT / f"{path}.luau").read_text()
                # Strip a leading --!strict / --!nonstrict directive; it is only valid on line 1.
                body = re.sub(r"^--!\w+\s*\n", "", body)
                modules[path] = body
                collect(body)

    collect(source)
    header = ["local __modules = {}", "local __cache = {}"]
    for path, body in modules.items():
        header.append(f'__modules["{path}"] = function()\n{body}\nend')
    header.append(
        "local function __require(path)\n"
        "\tif __cache[path] == nil then __cache[path] = __modules[path]() end\n"
        "\treturn __cache[path]\nend"
    )
    stubs_end = source.find("local Recipes")
    stubs, rest = source[:stubs_end], source[stubs_end:]
    rest = REQUIRE.sub(lambda m: f'__require("{m.group(1)}")', rest)
    # Stubs must come first so module bodies (executed lazily) see them as globals.
    return stubs + "\n" + "\n".join(header) + "\n" + rest


def main() -> int:
    luau = sys.argv[1] if len(sys.argv) > 1 else shutil.which("luau")
    if not luau:
        print("luau CLI not found; install it from https://github.com/luau-lang/luau/releases")
        return 1
    code = bundle(SPEC.read_text())
    with tempfile.TemporaryDirectory() as tmp:
        out = pathlib.Path(tmp) / "bundle.luau"
        out.write_text(code)
        result = subprocess.run([luau, str(out)], capture_output=True, text=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
