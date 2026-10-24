// Minimal Luau runner: `check` compiles files (syntax), `run` executes a script with a
// Roblox-like `script`/`require` shim so pure ModuleScripts can be unit-tested.
use mlua::{Lua, Table, Value, Function};
use std::path::{Path, PathBuf};

const PRELUDE: &str = r##"
local function dirname(p) return (p:match("^(.*)/[^/]*$") or ".") end
local function basename(p) return (p:match("([^/]*)$")) end
function __makeScript(path)
  return setmetatable({ __path = path }, {
    __index = function(_, k)
      if k == "Parent" then return __makeScript(dirname(path)) end
      if k == "Name" then return basename(path) end
      if k == "WaitForChild" or k == "FindFirstChild" then
        return function(_, name) return __makeScript(path .. "/" .. name) end
      end
      return __makeScript(path .. "/" .. k)
    end,
    __tostring = function() return path end,
  })
end
local function rgb(r, g, b) return { R = r / 255, G = g / 255, B = b / 255, __type = "Color3" } end
Color3 = {
  fromRGB = rgb,
  new = function(r, g, b) return { R = r, G = g, B = b, __type = "Color3" } end,
  fromHex = function(h)
    h = h:gsub("#", "")
    return rgb(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
  end,
}
Vector3 = { new = function(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0, __type = "Vector3" } end }
Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0, __type = "Vector2" } end }
UDim2 = { new = function(a, b, c, d) return { a, b, c, d } end, fromScale = function(a, b) return { a, 0, b, 0 } end, fromOffset = function(a, b) return { 0, a, 0, b } end }
"##;

fn resolve(path: &str) -> Option<PathBuf> {
    for cand in [format!("{path}.luau"), format!("{path}.lua"), format!("{path}/init.luau"), path.to_string()] {
        let p = PathBuf::from(&cand);
        if p.is_file() { return Some(p); }
    }
    None
}

fn load_module(lua: &Lua, file: &Path, script_path: &str) -> mlua::Result<Value> {
    let src = std::fs::read_to_string(file).map_err(mlua::Error::external)?;
    let globals = lua.globals();
    let make: Function = globals.get("__makeScript")?;
    let script: Value = make.call(script_path)?;
    let env = lua.create_table()?;
    env.set("script", script)?;
    let mt = lua.create_table()?;
    mt.set("__index", globals)?;
    env.set_metatable(Some(mt));
    lua.load(src).set_name(file.to_string_lossy()).set_environment(env).call(())
}

fn main() -> mlua::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 { eprintln!("usage: luau-runner check <files..> | run <file>"); std::process::exit(2); }
    let lua = Lua::new();
    lua.load(PRELUDE).exec()?;
    let cache: Table = lua.create_table()?;
    lua.set_named_registry_value("cache", cache)?;
    let require = lua.create_function(|lua, target: Value| {
        let path: String = match &target {
            Value::Table(t) => t.raw_get("__path")?,
            Value::String(s) => s.to_str()?.to_string(),
            _ => return Err(mlua::Error::runtime("require: unsupported argument")),
        };
        let cache: Table = lua.named_registry_value("cache")?;
        if let Ok(v) = cache.get::<Value>(path.as_str()) { if !v.is_nil() { return Ok(v); } }
        let file = resolve(&path).ok_or_else(|| mlua::Error::runtime(format!("require: module not found: {path}")))?;
        let script_path = path.trim_end_matches("/init").to_string();
        let v = load_module(lua, &file, &script_path)?;
        cache.set(path.as_str(), v.clone())?;
        Ok(v)
    })?;
    lua.globals().set("require", require)?;
    let mode = args[1].as_str();
    let mut failed = 0;
    match mode {
        "check" => {
            for f in &args[2..] {
                let src = std::fs::read_to_string(f).expect("read");
                match lua.load(src).set_name(f.as_str()).into_function() {
                    Ok(_) => {}
                    Err(e) => { failed += 1; eprintln!("SYNTAX ERROR {f}:\n{e}"); }
                }
            }
            println!("checked {} files, {} failed", args.len() - 2, failed);
        }
        "run" => {
            // Extra args are prelude files executed in the global environment first.
            for pre in &args[3..] {
                let src = std::fs::read_to_string(pre).expect("read prelude");
                if let Err(e) = lua.load(src).set_name(pre.as_str()).exec() { eprintln!("{e}"); std::process::exit(1); }
            }
            let f = PathBuf::from(&args[2]);
            let sp = args[2].trim_end_matches(".luau").to_string();
            if let Err(e) = load_module(&lua, &f, &sp) { eprintln!("{e}"); failed = 1; }
        }
        _ => { eprintln!("unknown mode"); failed = 1; }
    }
    if failed > 0 { std::process::exit(1); }
    Ok(())
}
