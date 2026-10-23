#!/usr/bin/env python3
"""Performance budget for Sky Glide, measured headlessly (see tests/perf.luau).

Prints the per-frame CPU cost of every RunService callback by module, the frame-time
distribution, and the server -> client traffic per player. These are Luau-interpreter numbers
in the mock environment, so treat them as a relative budget, not as device benchmarks.

usage: python3 tests/perf.py --luau PATH [--budget-ms 6] [--budget-kbps 20]
Exit code 1 when the 95th-percentile frame or the traffic exceeds the budget.
"""
import argparse
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import run_tests  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--luau", default="luau")
    ap.add_argument("--budget-ms", type=float, default=6.0)
    ap.add_argument("--budget-kbps", type=float, default=20.0)
    args = ap.parse_args()
    out = HERE / ".bundle"
    out.mkdir(exist_ok=True)
    bundled = out / "perf.bundle.luau"
    bundled.write_text(run_tests.bundle(HERE / "perf.luau"))
    result = subprocess.run([args.luau, str(bundled)], capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout[-3000:] + result.stderr[-3000:])
        return 1
    frame = net = None
    costs, nets, errors = [], [], []
    inst = pets = 0
    heavy = None
    for line in result.stdout.splitlines():
        parts = line.split("\t")
        if parts[0] == "FRAME":
            frame = tuple(float(x) for x in parts[1:4]) + (int(parts[4]),)
        elif parts[0] == "COST":
            costs.append((parts[1], float(parts[2]), float(parts[3]), int(parts[4])))
        elif parts[0] == "NET":
            net = (float(parts[1]), float(parts[2]))
        elif parts[0] == "NETBY":
            nets.append((parts[1], float(parts[2])))
        elif parts[0] == "INST":
            inst = int(parts[1])
        elif parts[0] == "PETS":
            pets = int(parts[1])
        elif parts[0] == "HEAVY":
            heavy = (float(parts[1]), float(parts[2]), int(parts[3]))
        elif "ERROR" in line:
            errors.append(line)
    if frame is None or net is None:
        sys.stderr.write(result.stdout[-3000:])
        return 1
    avg, p95, worst, flights = frame
    print(f"scenario: 10 players, {pets} pet followers, up to {flights} flights at once, 30 s at 60 fps")
    print(f"frame cost (all scripts, client + server): avg {avg:.2f} ms, p95 {p95:.2f} ms, worst {worst:.2f} ms")
    print("per module (avg ms/frame, worst ms):")
    for source, per_frame, worst_call, calls in sorted(costs, key=lambda c: -c[1])[:15]:
        print(f"  {per_frame:7.3f}  {worst_call:7.2f}  {source}")
    print(f"server -> one client: {net[0]:.1f} KB/s, {net[1]:.0f} messages/s")
    for name, kbps in sorted(nets, key=lambda n: -n[1])[:8]:
        print(f"  {kbps:6.2f} KB/s  {name}")
    print(f"instances created in this run: {inst}")
    if heavy:
        print(f"full 60-pet profile on Auto Throw: PlayerData {heavy[0]:.1f} KB/s ({heavy[1]:.1f} syncs/s, {heavy[2]} bytes each)")
    for e in errors:
        print(e)
    ok = p95 <= args.budget_ms and net[0] <= args.budget_kbps and (heavy is None or heavy[0] <= args.budget_kbps) and not errors
    print("perf: " + ("within budget" if ok else "OVER BUDGET") + f" (p95 <= {args.budget_ms} ms, traffic <= {args.budget_kbps} KB/s)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
