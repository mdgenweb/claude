#!/usr/bin/env python3
"""Static API lint for the Luau sources (complements luau-lsp, which cannot see these).

1. Instance.new("X") / Create("X", {...}): X must be a creatable class, and every key of the
   Create property table must be a property or event of X (from the Roblox definitions file).
2. Helpers whose parameter is a declared table type (Create.Text, Button.new, MapKit.Part, ...):
   every key of a table literal passed there must be a field of that type. Luau accepts unknown
   keys silently, so a typo like `Colour =` would otherwise be ignored at runtime.

usage: python3 tests/api_lint.py --defs globalTypes.d.luau src [more roots...]
Exit code 1 when anything is reported.
"""
import argparse, json, pathlib, re, sys

def skip_str(s, j):
    q = s[j]; j += 1
    while j < len(s) and s[j] != q:
        j += 2 if s[j] == '\\' else 1
    return j

def match_close(s, i):  # s[i] is an opener; returns index of its closer
    depth, j = 0, i
    while j < len(s):
        c = s[j]
        if c in '"\'': j = skip_str(s, j)
        elif s.startswith('--', j):
            while j < len(s) and s[j] != '\n': j += 1
        elif c in '{([': depth += 1
        elif c in '})]':
            depth -= 1
            if depth == 0: return j
        j += 1
    return j

def skip_block(s, j):  # s[j:] starts with `function`; returns index after its matching `end`
    level = 0
    while j < len(s):
        c = s[j]
        if c in '"\'': j = skip_str(s, j) + 1; continue
        if s.startswith('--', j):
            while j < len(s) and s[j] != '\n': j += 1
            continue
        m = re.match(r'[A-Za-z_]\w*', s[j:])
        if m and not (j and (s[j-1].isalnum() or s[j-1] in '_.:')):
            w = m.group(0)
            line_start = s.rfind('\n', 0, j) + 1
            first = s[line_start:j].strip() == ''
            if w in ('function', 'repeat') or (w in ('if', 'do') and (first or w == 'do' and re.search(r'\b(for|while)\b', s[line_start:j]))): level += 1
            elif w in ('end', 'until'):
                level -= 1
                if level == 0: return j + len(w)
            j += len(w); continue
        j += 1
    return j

def top_keys(s, i, sep='='):  # keys at depth 1 of the table starting at s[i] == '{'
    out, depth, j = [], 0, i
    while j < len(s):
        c = s[j]
        if c in '"\'': j = skip_str(s, j)
        elif s.startswith('--', j):
            while j < len(s) and s[j] != '\n': j += 1
        elif c in '{([': depth += 1
        elif c in '})]':
            depth -= 1
            if depth == 0: break
        elif depth == 1 and re.match(r'function\b', s[j:]) and not (s[j-1].isalnum() or s[j-1] in '_.'):
            j = skip_block(s, j); continue
        elif depth == 1:
            m = re.match(r'([A-Za-z_]\w*)\s*[' + sep + r'](?!=)', s[j:])
            if m and not (s[j-1].isalnum() or s[j-1] in '_.:'):
                out.append((m.group(1), s.count('\n', 0, j) + 1)); j += m.end(); continue
        j += 1
    return out

def split_args(s, i):  # s[i] == '(' -> list of (start, text)
    end = match_close(s, i); args, depth, start, j = [], 0, i + 1, i + 1
    while j < end:
        c = s[j]
        if c in '"\'': j = skip_str(s, j)
        elif c in '{([': depth += 1
        elif c in '})]': depth -= 1
        elif c == ',' and depth == 0:
            args.append((start, s[start:j])); start = j + 1
        j += 1
    args.append((start, s[start:end]))
    return args


def load_defs(path):
    text = pathlib.Path(path).read_text()
    meta = json.loads(text.splitlines()[0].split('#METADATA#', 1)[1])
    classes, parent, cur = {}, {}, None
    for line in text.splitlines():
        m = re.match(r'declare extern type (\w+)(?: extends (\w+))? with', line)
        if m:
            cur = m.group(1); parent[cur] = m.group(2); classes[cur] = set(); continue
        if line.startswith('end'):
            cur = None; continue
        if cur:
            m = re.match(r'\s+(?:function\s+)?(\w+)\s*[:(]', line)
            if m: classes[cur].add(m.group(1))
    def members(c):
        out = set()
        while c:
            out |= classes.get(c, set()); c = parent.get(c)
        return out
    return set(meta['CREATABLE_INSTANCES']), members

def line_of(s, i):
    return s.count('\n', 0, i) + 1

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--defs', required=True, help='Roblox globalTypes.d.luau used by luau-lsp')
    ap.add_argument('roots', nargs='+')
    args = ap.parse_args()
    creatable, members = load_defs(args.defs)
    files = {p: p.read_text() for root in args.roots for p in sorted(pathlib.Path(root).rglob('*.luau'))}
    issues = []

    # 1. Roblox classes and properties
    creates = 0
    for p, s in files.items():
        for m in re.finditer(r'Instance\.new\("(\w+)"', s):
            if m.group(1) not in creatable:
                issues.append(f'{p}:{line_of(s, m.start())}: Instance.new: {m.group(1)} is not creatable')
        for m in re.finditer(r'\bCreate\(\s*"(\w+)"\s*,\s*\{', s):
            creates += 1
            cls = m.group(1)
            if cls not in creatable:
                issues.append(f'{p}:{line_of(s, m.start())}: Create: {cls} is not creatable')
            known = members(cls)
            for key, ln in top_keys(s, m.end() - 1):
                if key != 'Parent' and key not in known:
                    issues.append(f'{p}:{ln}: Create("{cls}"): {cls} has no property or event {key}')

    # 2. option tables of typed helpers
    types = {}
    for p, s in files.items():
        for m in re.finditer(r'(?:export )?type (\w+)\s*=\s*\{', s):
            types[m.group(1)] = {k for k, _ in top_keys(s, m.end() - 1, ':')}
    sigs = {}
    for p, s in files.items():
        for m in re.finditer(r'function (\w+)[.:](\w+)\(', s):
            for idx, (_, a) in enumerate(split_args(s, m.end() - 1)):
                t = re.match(r'\s*\w+\s*:\s*(?:\w+\.)?(\w+)\??\s*$', a)
                if t and t.group(1) in types:
                    sigs.setdefault((m.group(1), m.group(2)), []).append((idx, t.group(1)))
    options = 0
    for p, s in files.items():
        for m in re.finditer(r'\b(\w+)\.(\w+)\(', s):
            key = (m.group(1), m.group(2))
            if key not in sigs:
                continue
            call_args = split_args(s, m.end() - 1)
            for idx, tname in sigs[key]:
                if idx >= len(call_args):
                    continue
                start, text = call_args[idx]
                if not text.lstrip().startswith('{'):
                    continue
                options += 1
                for name, ln in top_keys(s, start + len(text) - len(text.lstrip())):
                    if name not in types[tname]:
                        issues.append(f'{p}:{ln}: {key[0]}.{key[1]}: option {name} is not a field of {tname}')

    for line in issues:
        print(line)
    print(f'api_lint: {len(files)} files, {creates} Create calls, {options} option tables, {len(issues)} issues')
    return 1 if issues else 0

if __name__ == '__main__':
    sys.exit(main())
