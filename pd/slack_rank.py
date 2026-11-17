#!/usr/bin/env python3
"""Rank the worst setup and hold paths from a timing report.

A full report_timing dump is thousands of lines, and the useful question is
usually just: which paths are worst, and do they cluster? This script parses
every path block, pulls out startpoint, endpoint, check type, and slack, and
prints the N worst setup and N worst hold paths plus a WNS/TNS summary and a
count of which endpoint groups the violations land in.

Handles two report styles:
  * Cadence Innovus (legacy UI):
        Path 1: VIOLATED Setup Check with Pin cpu/u_reg_file/registers_reg_21__1_/CK
        Endpoint:   cpu/u_reg_file/registers_reg_21__1_/D (^) checked with ...
        Beginpoint: rst_i (v) triggered by ...
        = Slack Time   -0.559
  * Synopsys PrimeTime / Design Compiler / OpenSTA (OpenLane):
        Startpoint: cpu/instr_q_reg_16_ (rising edge-triggered flip-flop ...)
        Endpoint: cpu/u_reg_file/registers_reg_31__30_ (...)
        Path Type: max
        ...
        slack (VIOLATED)   -0.344

How I generate the input in Innovus:
    report_timing -max_paths 2000 -nworst 1 > setup.rpt
    report_timing -early -max_paths 2000 -nworst 1 > hold.rpt

Usage:
    python3 slack_rank.py setup.rpt hold.rpt            # top 10 of each
    python3 slack_rank.py *.rpt -n 20 --csv worst.csv   # top 20, also write CSV
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


@dataclass
class TimingPath:
    check: str          # "setup", "hold", or "clock_gating_setup" / "clock_gating_hold"
    startpoint: str
    endpoint: str
    slack: float
    source: str         # report file it came from

    @property
    def met(self) -> bool:
        return self.slack >= 0


# --- Innovus -----------------------------------------------------------------
INNOVUS_HEADER = re.compile(r"^Path\s+\d+:\s+(MET|VIOLATED)\s+(.+?)\s+Check\b", re.M)
INNOVUS_END = re.compile(r"^\s*Endpoint:\s+(\S+)", re.M)
INNOVUS_BEGIN = re.compile(r"^\s*Beginpoint:\s+(\S+)", re.M)
INNOVUS_SLACK = re.compile(r"=\s*Slack Time\s+(-?[\d.]+)")

# --- Synopsys / OpenSTA ------------------------------------------------------
SNPS_START = re.compile(r"^\s*Startpoint:\s+(\S+)", re.M)
SNPS_END = re.compile(r"^\s*Endpoint:\s+(\S+)", re.M)
SNPS_TYPE = re.compile(r"^\s*Path Type:\s+(max|min)", re.M)
SNPS_SLACK = re.compile(r"slack\s*\((?:MET|VIOLATED)[^)]*\)\s+(-?[\d.]+)")


def _check_name(text: str) -> str:
    t = text.lower()
    gating = "clock_gating_" if "gating" in t else ""
    return gating + ("hold" if "hold" in t else "setup")


def parse_innovus(text: str, source: str) -> list[TimingPath]:
    paths = []
    headers = list(INNOVUS_HEADER.finditer(text))
    for i, h in enumerate(headers):
        block = text[h.start(): headers[i + 1].start() if i + 1 < len(headers) else len(text)]
        end, beg, slk = INNOVUS_END.search(block), INNOVUS_BEGIN.search(block), INNOVUS_SLACK.search(block)
        if not (end and slk):
            continue
        paths.append(TimingPath(_check_name(h.group(2)), beg.group(1) if beg else "?",
                                end.group(1), float(slk.group(1)), source))
    return paths


def parse_synopsys(text: str, source: str) -> list[TimingPath]:
    paths = []
    starts = list(SNPS_START.finditer(text))
    for i, s in enumerate(starts):
        block = text[s.start(): starts[i + 1].start() if i + 1 < len(starts) else len(text)]
        end, typ, slk = SNPS_END.search(block), SNPS_TYPE.search(block), SNPS_SLACK.search(block)
        if not (end and slk):
            continue
        check = "hold" if typ and typ.group(1) == "min" else "setup"
        paths.append(TimingPath(check, s.group(1), end.group(1), float(slk.group(1)), source))
    return paths


def parse_report(path: Path) -> list[TimingPath]:
    text = path.read_text(errors="replace")
    if INNOVUS_HEADER.search(text):
        return parse_innovus(text, path.name)
    return parse_synopsys(text, path.name)


def endpoint_group(endpoint: str) -> str:
    """Collapse bit/index suffixes so registers_reg_21__1_/D and registers_reg_21__7_/D
    count as the same group: cpu/u_reg_file/registers_reg_21."""
    inst = endpoint.rsplit("/", 1)[0]
    if re.search(r"__\d+_$", inst):             # 2-D register: drop the bit index only
        return re.sub(r"__\d+_$", "", inst)
    return re.sub(r"_\d+_$", "", inst)          # 1-D register: drop the bit index


def summarize(paths: list[TimingPath], check: str, n: int) -> list[TimingPath]:
    group = sorted((p for p in paths if p.check.endswith(check)), key=lambda p: p.slack)
    if not group:
        print(f"\n== {check.upper()}: no paths found ==")
        return []
    violators = [p for p in group if not p.met]
    wns = group[0].slack
    tns = sum(p.slack for p in violators)
    print(f"\n== {check.upper()} ==  WNS {wns:+.3f} ns | TNS {tns:+.3f} ns | "
          f"{len(violators)} violating of {len(group)} paths parsed")
    print(f"{'#':>3}  {'slack':>8}  {'check':<20} startpoint -> endpoint")
    worst = group[:n]
    for i, p in enumerate(worst, 1):
        flag = "" if p.met else "  VIOLATED"
        print(f"{i:>3}  {p.slack:>+8.3f}  {p.check:<20} {p.startpoint} -> {p.endpoint}{flag}")
    if violators:
        print("   where the violations cluster (endpoint groups):")
        for grp, count in Counter(endpoint_group(p.endpoint) for p in violators).most_common(5):
            print(f"     {count:>4}  {grp}")
    return worst


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("reports", nargs="+", type=Path, help="timing report file(s)")
    ap.add_argument("-n", type=int, default=10, help="paths to show per check (default 10)")
    ap.add_argument("--csv", type=Path, help="also write the ranked paths to this CSV")
    args = ap.parse_args(argv)

    paths: list[TimingPath] = []
    for rpt in args.reports:
        if not rpt.exists():
            print(f"missing report: {rpt}", file=sys.stderr)
            return 1
        found = parse_report(rpt)
        print(f"{rpt.name}: {len(found)} paths")
        paths += found

    ranked = summarize(paths, "setup", args.n) + summarize(paths, "hold", args.n)

    if args.csv:
        with args.csv.open("w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["rank", "check", "slack_ns", "startpoint", "endpoint", "source"])
            for check in ("setup", "hold"):
                for i, p in enumerate((p for p in ranked if p.check.endswith(check)), 1):
                    w.writerow([i, p.check, f"{p.slack:.3f}", p.startpoint, p.endpoint, p.source])
        print(f"\nwrote {args.csv}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
