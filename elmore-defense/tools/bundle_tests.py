#!/usr/bin/env python3
"""
Bundles src/shared (as a virtual Roblox instance tree) + Roblox API shims + tests/*.spec.luau
into one Luau file that the stock `luau` CLI can execute.

    python3 tools/bundle_tests.py && luau build/test_bundle.luau

Modules keep their real `require(script.Parent.X)` style; the shim resolves those against the tree.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, "src", "shared")
TESTS = os.path.join(ROOT, "tests")
OUT_DIR = os.path.join(ROOT, "build")


def luau_long_string(text: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return "[" + eq + "[" + text + "]" + eq + "]"


def collect_modules(base: str, prefix: str):
    modules = []
    for dirpath, _dirnames, filenames in os.walk(base):
        for filename in sorted(filenames):
            if not filename.endswith(".luau"):
                continue
            full = os.path.join(dirpath, filename)
            rel = os.path.relpath(full, base).replace(os.sep, "/")
            name = rel[: -len(".luau")]
            modules.append((prefix + "/" + name, full))
    return modules


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    parts = []
    with open(os.path.join(TESTS, "harness", "Shims.luau"), encoding="utf-8") as handle:
        parts.append(handle.read())

    for path, full in collect_modules(SHARED, "Shared"):
        with open(full, encoding="utf-8") as handle:
            source = handle.read()
        # `export type` is only legal at module top level; modules are wrapped in functions here.
        source = re.sub(r"(?m)^export type", "type", source)
        parts.append(
            "__registerModule(%s, function(script, require)\n%s\nend)\n"
            % (luau_long_string(path), source)
        )

    with open(os.path.join(TESTS, "harness", "TestKit.luau"), encoding="utf-8") as handle:
        parts.append(handle.read())

    specs = sorted(f for f in os.listdir(TESTS) if f.endswith(".spec.luau"))
    for spec in specs:
        with open(os.path.join(TESTS, spec), encoding="utf-8") as handle:
            source = handle.read()
        parts.append(
            "__runSpec(%s, function(Shared, require)\n%s\nend)\n" % (luau_long_string(spec), source)
        )
    parts.append("__finish()\n")

    out = os.path.join(OUT_DIR, "test_bundle.luau")
    with open(out, "w", encoding="utf-8") as handle:
        handle.write("\n".join(parts))
    print(f"bundled {len(specs)} spec file(s) -> {os.path.relpath(out, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
