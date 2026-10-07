#!/usr/bin/env python3
"""Headless test runner for the battle simulation.

Bundles the real modules from src/ into one Luau script with a tiny fake DataModel
(`script`, `script.Parent`, `game:GetService`, `require(instance)`), then runs the spec
files in tests/ with the Luau CLI. Roblox-only APIs are not available, so only pure
modules (simulation, definitions, codecs, config) can be tested this way.

Usage: python3 tests/run_tests.py [--luau PATH] [spec ...]
"""
import argparse
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MOUNTS = {
    # DataModel path -> source dir
    "ReplicatedStorage/Shared": ROOT / "src" / "shared",
    "ServerScriptService/Server": ROOT / "src" / "server",
}


def collect_modules():
    modules = {}
    for mount, directory in MOUNTS.items():
        for path in sorted(directory.rglob("*.luau")):
            rel = path.relative_to(directory)
            parts = list(rel.parts)
            name = parts[-1]
            if name.endswith(".server.luau") or name.endswith(".client.luau"):
                continue
            parts[-1] = name[: -len(".luau")]
            if parts[-1] == "init":
                parts = parts[:-1]
            key = "/".join([mount] + parts)
            modules[key] = path.read_text()
    return modules


def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + text + "]" + eq + "]"


HARNESS = r'''
local SOURCES = __SOURCES__

-- Fake instance tree -------------------------------------------------------------------
local Node = {}
Node.__index = function(self, key)
    local method = rawget(Node, key)
    if method then return method end
    local children = rawget(self, "_children")
    local child = children[key]
    if child then return child end
    error("fake instance '" .. rawget(self, "_path") .. "' has no child '" .. tostring(key) .. "'", 2)
end

local function newNode(name, parent, path)
    local node = setmetatable({ _children = {}, _name = name, _path = path }, Node)
    rawset(node, "Name", name)
    rawset(node, "Parent", parent)
    if parent then rawget(parent, "_children")[name] = node end
    return node
end

function Node.WaitForChild(self, name) return self[name] end
function Node.FindFirstChild(self, name) return rawget(self, "_children")[name] end
function Node.GetChildren(self)
    local out = {}
    for _, c in rawget(self, "_children") do table.insert(out, c) end
    table.sort(out, function(a, b) return rawget(a, "_name") < rawget(b, "_name") end)
    return out
end
function Node.IsA(self, class) return class == "ModuleScript" and SOURCES[rawget(self, "_path")] ~= nil end

local ROOT = newNode("game", nil, "")
local function ensure(path)
    local node = ROOT
    local acc = ""
    for part in string.gmatch(path, "[^/]+") do
        acc = (acc == "" and part) or (acc .. "/" .. part)
        local children = rawget(node, "_children")
        node = children[part] or newNode(part, node, acc)
    end
    return node
end
for path in SOURCES do ensure(path) end

local fakeGame = setmetatable({}, { __index = function(_, key)
    if key == "GetService" then
        return function(_, name)
            return rawget(ROOT, "_children")[name] or newNode(name, ROOT, name)
        end
    end
    error("fake game has no member " .. tostring(key))
end })

local cache = {}
local loading = {}
local function fakeRequire(node)
    local path = rawget(node, "_path")
    if cache[path] ~= nil then return cache[path] end
    assert(not loading[path], "cyclic require: " .. path)
    local source = SOURCES[path]
    assert(source, "no module at " .. tostring(path))
    loading[path] = true
    local chunk, err = loadstring(source, "=" .. path)
    assert(chunk, err)
    local env = setmetatable({ script = node, require = fakeRequire, game = fakeGame,
        warn = function(...) print("WARN", ...) end }, { __index = getfenv(1) })
    setfenv(chunk, env)
    local result = chunk()
    loading[path] = nil
    cache[path] = result
    return result
end

function MODULE(path) return fakeRequire(ensure(path)) end
FAKE_GAME = fakeGame
'''


def bundle(spec_path):
    modules = collect_modules()
    entries = ",\n".join(
        '  ["%s"] = %s' % (key, long_string(src)) for key, src in modules.items()
    )
    harness = HARNESS.replace("__SOURCES__", "{\n" + entries + "\n}")
    return harness + "\n-- spec ---------------------------------------------------\n" + spec_path.read_text()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", default=os.environ.get("LUAU", "luau"))
    parser.add_argument("specs", nargs="*")
    args = parser.parse_args()

    specs = [pathlib.Path(s) for s in args.specs] or sorted((ROOT / "tests").glob("*.spec.luau"))
    out_dir = ROOT / "tests" / ".bundle"
    out_dir.mkdir(exist_ok=True)
    failed = 0
    for spec in specs:
        bundled = out_dir / (spec.stem + ".bundle.luau")
        bundled.write_text(bundle(spec))
        print(f"== {spec.name}")
        result = subprocess.run([args.luau, str(bundled)], capture_output=True, text=True)
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        if result.returncode != 0 or "FAILED" in result.stdout:
            failed += 1
            print(f"!! {spec.name} failed (exit {result.returncode})")
    if failed:
        print(f"{failed} spec file(s) failed")
        sys.exit(1)
    print("all specs passed")


if __name__ == "__main__":
    main()
