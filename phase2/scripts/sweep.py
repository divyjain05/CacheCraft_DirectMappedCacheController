#!/usr/bin/env python3
"""Phase 2 parameter sweep - design-space exploration.

Runs every trace through a range of cache configurations and reports hit rate
and AMAT, so the effect of associativity, block size, cache size, and write
policy can be compared. Writes reports/sweep_results.csv and prints a summary.

Usage:
  python3 scripts/sweep.py
"""
import csv
import glob
import os

from cache_model import Cache, load_trace

TRACES = sorted(glob.glob("sim/traces/*.txt"))

# (label, cache_size, block_size, assoc, write_back)
CONFIGS = [
    ("DM 1KB/16B wb",     1024, 16, 1, True),
    ("2-way 1KB/16B wb",  1024, 16, 2, True),
    ("4-way 1KB/16B wb",  1024, 16, 4, True),
    ("DM 1KB/32B wb",     1024, 32, 1, True),
    ("DM 2KB/16B wb",     2048, 16, 1, True),
    ("2-way 1KB/16B wt",  1024, 16, 2, False),
]


def main():
    os.makedirs("reports", exist_ok=True)
    rows = []
    for tpath in TRACES:
        trace = load_trace(tpath)
        tname = os.path.basename(tpath).replace(".txt", "")
        for label, size, blk, assoc, wb in CONFIGS:
            s = Cache(size, blk, assoc, wb).run(trace)
            rows.append({
                "trace": tname, "config": label,
                "cache_B": size, "block_B": blk, "assoc": assoc,
                "policy": "wb" if wb else "wt",
                "hit_rate_%": round(100 * s["hit_rate"], 2),
                "miss_rate_%": round(100 * s["miss_rate"], 2),
                "writebacks": s["writebacks"],
                "mem_reads": s["mem_block_reads"],
                "mem_writes": s["mem_block_writes"],
                "AMAT": round(s["amat"], 3),
            })

    with open("reports/sweep_results.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    # pretty summary grouped by trace
    print(f"{'trace':11} {'config':18} {'hit%':>6} {'AMAT':>7} {'WB':>5}")
    print("-" * 52)
    last = None
    for r in rows:
        if r["trace"] != last:
            print("-" * 52)
            last = r["trace"]
        print(f"{r['trace']:11} {r['config']:18} {r['hit_rate_%']:6.2f} "
              f"{r['AMAT']:7.3f} {r['writebacks']:5d}")
    print("\nfull table -> reports/sweep_results.csv")


if __name__ == "__main__":
    main()
