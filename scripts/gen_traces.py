#!/usr/bin/env python3
"""Generate memory-access traces for the direct-mapped cache.

Produces three access patterns that exercise locality differently:
  sequential : strides through memory  -> good spatial locality
  repeated   : hammers a small working set -> good temporal locality
  random     : addresses all over -> poor locality (worst hit rate)

Each trace is a text file of 32-bit byte addresses in hex, one per line,
which both the Verilog testbench and scripts/cache_sim.py read directly.

Usage:
  python3 scripts/gen_traces.py            # writes the three default traces
  python3 scripts/gen_traces.py -n 400     # 400 accesses each
"""
import argparse
import random

BLOCK_SIZE = 16          # bytes per block (keep in sync with cache_defs.vh)
CACHE_SIZE = 1024        # bytes
NUM_LINES  = CACHE_SIZE // BLOCK_SIZE


def write_trace(path, addrs):
    with open(path, "w") as f:
        for a in addrs:
            f.write(f"{a & 0xFFFFFFFF:08x}\n")
    print(f"wrote {len(addrs):4d} addresses -> {path}")


def sequential(n):
    # walk one word (4 bytes) at a time across a few KB
    return [i * 4 for i in range(n)]


def repeated(n, working_set_blocks=8):
    # cycle over a small set of blocks -> high temporal/spatial reuse
    span = working_set_blocks * BLOCK_SIZE
    return [(i * 4) % span for i in range(n)]


def random_trace(n, span_blocks=4 * NUM_LINES, seed=1):
    # addresses spread over 4x the cache -> heavy conflict/capacity misses
    rng = random.Random(seed)
    span = span_blocks * BLOCK_SIZE
    return [rng.randrange(0, span) & ~0x3 for _ in range(n)]  # word-aligned


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-n", "--num", type=int, default=256, help="accesses per trace")
    ap.add_argument("-o", "--outdir", default="sim/traces")
    args = ap.parse_args()

    write_trace(f"{args.outdir}/sequential.txt", sequential(args.num))
    write_trace(f"{args.outdir}/repeated.txt",   repeated(args.num))
    write_trace(f"{args.outdir}/random.txt",     random_trace(args.num))


if __name__ == "__main__":
    main()
