#!/usr/bin/env python3
"""Top-down renders of every world built by the real MapBuilder (no Roblox needed), plus checks:

  * station overlap - the footprints of two stations (pads, pedestals, eggs, portals, boards, the
                      throw zone, the spawn) intersect, so they would stand inside each other
  * underground     - a solid, visible part sits entirely below the ground plane (the river
                      channel's bed and water are meant to be there and are skipped)

usage: python3 tests/map_render.py --luau PATH [--out DIR]
Exit code 1 when anything is reported.
"""
import argparse
import json
import pathlib
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import run_tests  # noqa: E402

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
STATION_GROUPS = ("Pads", "Pedestals", "Eggs", "Portals", "Boards")


def run_dump(luau):
    out_dir = HERE / ".bundle"
    out_dir.mkdir(exist_ok=True)
    bundled = out_dir / "map_dump.bundle.luau"
    bundled.write_text(run_tests.bundle(HERE / "map_dump.luau"))
    result = subprocess.run([luau, str(bundled)], capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout[-3000:] + result.stderr[-3000:])
        raise SystemExit("map_dump.luau failed")
    worlds, parts = {}, []
    for line in result.stdout.splitlines():
        if line.startswith("WORLD\t"):
            w = json.loads(line[6:])
            worlds[w["id"]] = w["name"]
        elif line.startswith("PART\t"):
            parts.append(json.loads(line[5:]))
    return worlds, parts


def footprint(p):
    """Axis-aligned XZ bounds of an oriented box."""
    (px, _, pz), (sx, sy, sz) = p["p"], p["s"]
    rx, rz = p["x"], p["z"]
    # y axis = z cross x (only its XZ projection matters for the extent)
    ux = (rz[1] * rx[2] - rz[2] * rx[1], rz[2] * rx[0] - rz[0] * rx[2], rz[0] * rx[1] - rz[1] * rx[0])
    hx = abs(rx[0]) * sx / 2 + abs(ux[0]) * sy / 2 + abs(rz[0]) * sz / 2
    hz = abs(rx[2]) * sx / 2 + abs(ux[2]) * sy / 2 + abs(rz[2]) * sz / 2
    return px - hx, pz - hz, px + hx, pz + hz


def corners(p):
    (px, _, pz), (sx, sy, sz) = p["p"], p["s"]
    rx, rz = p["x"], p["z"]
    pts = []
    for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        pts.append((px + rx[0] * sx / 2 * a + rz[0] * sz / 2 * b, pz + rx[2] * sx / 2 * a + rz[2] * sz / 2 * b))
    return pts


def station_of(path):
    parts = path.split("/")
    if len(parts) >= 2 and parts[0] in STATION_GROUPS:
        return parts[0] + "/" + parts[1]
    if parts and parts[0] in ("ThrowZone", "Spawn", "SpawnLocation"):
        return parts[0]
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--luau", default="luau")
    ap.add_argument("--out", default=str(HERE / ".ui"))
    args = ap.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    worlds, parts = run_dump(args.luau)
    issues = []
    for wid, name in sorted(worlds.items()):
        wp = [p for p in parts if p["w"] == wid]
        ox = (wid - 1) * 3200.0
        # stations: union footprint of their parts
        stations = {}
        for p in wp:
            st = station_of(p["path"])
            if st and p["t"] < 1:
                x0, z0, x1, z1 = footprint(p)
                b = stations.get(st)
                stations[st] = (x0, z0, x1, z1) if b is None else (min(b[0], x0), min(b[1], z0), max(b[2], x1), max(b[3], z1))
            in_river = p["path"].startswith("Channel") or p["name"] in ("Bed", "Water", "Riverbed")
            if not in_river and p["collide"] and p["t"] < 0.9 and p["p"][1] + p["s"][1] / 2 < -6 and p["s"][1] < 200:
                issues.append(f"{name}: underground: {p['path']}/{p['name']} at y={p['p'][1]:.1f}")
        keys = sorted(stations)
        for i in range(len(keys)):
            for j in range(i + 1, len(keys)):
                a, b = stations[keys[i]], stations[keys[j]]
                ix = min(a[2], b[2]) - max(a[0], b[0])
                iz = min(a[3], b[3]) - max(a[1], b[1])
                if ix > 0.5 and iz > 0.5:
                    issues.append(f"{name}: station overlap: {keys[i]} <> {keys[j]} ({ix:.1f} x {iz:.1f} studs)")
        # render the hub area (x within 300, z from -260 to 340) and the whole world
        for label, (xmin, xmax, zmin, zmax), scale in (("hub", (-300, 300, -120, 330), 3.0), ("world", (-700, 700, -8200, 400), 0.11)):
            W, H = int((xmax - xmin) * scale), int((zmax - zmin) * scale)
            img = Image.new("RGB", (W, H), (70, 120, 170))
            d = ImageDraw.Draw(img)
            for p in sorted(wp, key=lambda q: q["p"][1] + q["s"][1] / 2):
                if p["t"] >= 0.95:
                    continue
                pts = [((x - ox - xmin) * scale, (z - zmin) * scale) for x, z in corners(p)]
                c = p["c"].lstrip("#")
                rgb = tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))
                if p["t"] > 0.3:
                    rgb = tuple(int(v * (1 - p["t"]) + 120 * p["t"]) for v in rgb)
                d.polygon(pts, fill=rgb)
            if label == "hub":
                f = ImageFont.truetype(FONT, 13)
                for st, (x0, z0, x1, z1) in stations.items():
                    box = ((x0 - ox - xmin) * scale, (z0 - zmin) * scale, (x1 - ox - xmin) * scale, (z1 - zmin) * scale)
                    d.rectangle(box, outline=(255, 255, 255))
                    d.text((box[0] + 2, box[1] + 2), st.split("/")[-1][:18], fill=(255, 255, 255), font=f, stroke_width=2, stroke_fill=(0, 0, 0))
            img.save(out / f"map_{wid}_{label}.png")
    for line in issues:
        print(line)
    print(f"map_render: {len(worlds)} worlds, {len(parts)} parts, {len(issues)} issues, images in {out}")
    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
