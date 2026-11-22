#!/usr/bin/env python3
"""Generate read/write memory-access traces for Phase 2.

Phase 1 traces were read-only; Phase 2 adds writes so the write-back /
write-through policies and dirty-eviction behaviour can be exercised.

Line format: 'R <hex>' or 'W <hex>' (one access per line). Both the Verilog
testbench and scripts/cache_model.py read this format.

Patterns:
  sequential : stride one word, ~20% writes      (spatial locality)
  repeated   : small working set, ~30% writes     (temporal locality, reuse)
  conflict   : two blocks that map to the same set (shows set-associative win)
  random     : spread over 4x the cache, ~30% writes (poor locality)
"""
import argparse
import random

BLOCK = 16
CACHE = 1024
LINES = CACHE // BLOCK


def emit(path, trace):
    with open(path, "w") as f:
        for op, a in trace:
            f.write(f"{op} {a & 0xFFFFFFFF:08x}\n")
    print(f"wrote {len(trace):4d} accesses -> {path}")


def sequential(n, rng):
    return [("W" if rng.random() < 0.2 else "R", i * 4) for i in range(n)]


def repeated(n, rng, blocks=8):
    span = blocks * BLOCK
    return [("W" if rng.random() < 0.3 else "R", (i * 4) % span) for i in range(n)]


def conflict(n, rng):
    # two blocks exactly one cache-size apart -> same set; thrashes a
    # direct-mapped cache, fits in a 2-way cache.
    return [("W" if rng.random() < 0.3 else "R", (i % 2) * CACHE) for i in range(n)]


def random_trace(n, rng, span_blocks=4 * LINES):
    span = span_blocks * BLOCK
    return [("W" if rng.random() < 0.3 else "R", rng.randrange(0, span) & ~0x3)
            for _ in range(n)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-n", "--num", type=int, default=256)
    ap.add_argument("-o", "--outdir", default="sim/traces")
    args = ap.parse_args()
    rng = random.Random(1)
    emit(f"{args.outdir}/sequential.txt", sequential(args.num, rng))
    emit(f"{args.outdir}/repeated.txt",   repeated(args.num, rng))
    emit(f"{args.outdir}/conflict.txt",   conflict(args.num, rng))
    emit(f"{args.outdir}/random.txt",     random_trace(args.num, rng))


if __name__ == "__main__":
    main()
