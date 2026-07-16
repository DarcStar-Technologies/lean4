#!/usr/bin/env python3
"""Aggregate .measurements.jsonl files produced by tests/measure.py.

Usage:
  aggregate_measurements.py summarize FILE...   # markdown table to stdout
  aggregate_measurements.py compare DIR_A DIR_B # per-metric delta A->B + tripwire

`compare` exits nonzero if any wall-clock/task-clock metric differs by more
than --wall-tolerance (default 3%) or any instructions metric by more than
--instr-tolerance (default 1%) — the FK-10 reproducibility acceptance check.
Zero-valued measurements (perf-shim placeholders) are dropped.
"""
import argparse
import json
import statistics
import sys
from collections import defaultdict
from pathlib import Path


def load(paths):
    metrics = defaultdict(list)
    for path in paths:
        with open(path) as f:
            for line in f:
                data = json.loads(line)
                if data["value"] != 0:
                    metrics[data["metric"]].append((data["value"], data.get("unit")))
    return metrics


def summarize(metrics):
    rows = []
    for metric in sorted(metrics):
        values = [v for v, _ in metrics[metric]]
        unit = metrics[metric][0][1] or ""
        med = statistics.median(values)
        spread = (max(values) - min(values)) / med * 100 if med else 0.0
        rows.append((metric, med, unit, spread, len(values)))
    return rows


def cmd_summarize(args):
    rows = summarize(load(args.files))
    print("| metric | median | unit | spread % | n |")
    print("|---|---|---|---|---|")
    for metric, med, unit, spread, n in rows:
        print(f"| {metric} | {med:.4g} | {unit} | {spread:.1f} | {n} |")


def cmd_compare(args):
    a = summarize(load(sorted(Path(args.dir_a).glob("**/*.measurements.jsonl"))))
    b = summarize(load(sorted(Path(args.dir_b).glob("**/*.measurements.jsonl"))))
    b_by_metric = {row[0]: row for row in b}
    failures = []
    print("| metric | A median | B median | delta % | tolerance % | ok |")
    print("|---|---|---|---|---|---|")
    for metric, med_a, unit, _, _ in a:
        if metric not in b_by_metric:
            continue
        med_b = b_by_metric[metric][1]
        delta = (med_b - med_a) / med_a * 100 if med_a else 0.0
        if "instructions" in metric:
            tol = args.instr_tolerance
        elif "wall-clock" in metric or "task-clock" in metric:
            tol = args.wall_tolerance
        else:
            tol = None
        ok = tol is None or abs(delta) <= tol
        if not ok:
            failures.append(metric)
        tol_str = f"{tol:.1f}" if tol is not None else "-"
        print(f"| {metric} | {med_a:.4g} | {med_b:.4g} | {delta:+.2f} | {tol_str} | {'yes' if ok else 'NO'} |")
    if failures:
        print(f"\nFAIL: {len(failures)} metric(s) outside tolerance", file=sys.stderr)
        return 1
    print("\nOK: all compared metrics within tolerance", file=sys.stderr)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("summarize")
    p.add_argument("files", nargs="+")
    p.set_defaults(func=cmd_summarize)
    p = sub.add_parser("compare")
    p.add_argument("dir_a")
    p.add_argument("dir_b")
    p.add_argument("--wall-tolerance", type=float, default=3.0)
    p.add_argument("--instr-tolerance", type=float, default=1.0)
    p.set_defaults(func=cmd_compare)
    args = parser.parse_args()
    sys.exit(args.func(args) or 0)


if __name__ == "__main__":
    main()
