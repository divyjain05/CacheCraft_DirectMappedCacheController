#!/usr/bin/env python3
"""Cycle-accurate-ish reference model of the direct-mapped cache.

Mirrors the RTL exactly (same tag/index/offset split, same valid-bit cold
start, same miss penalty) so its hit/miss numbers and AMAT can be used to
CROSS-CHECK the Verilog testbench output. It also runs standalone when
Icarus Verilog is not installed, so the project is demonstrable either way.

AMAT = hit_time + miss_rate * miss_penalty   (hit_time = 1 cycle)

Usage:
  python3 scripts/cache_sim.py sim/traces/sequential.txt
  python3 scripts/cache_sim.py sim/traces/*.txt            # report all
  python3 scripts/cache_sim.py --self-test                 # built-in checks
"""
import sys
import glob

# --- configuration (keep in sync with rtl/cache_defs.vh) --------------------
CACHE_SIZE  = 1024
BLOCK_SIZE  = 16
ADDR_BITS   = 32
MEM_LATENCY = 10          # miss penalty in cycles

NUM_LINES   = CACHE_SIZE // BLOCK_SIZE
OFFSET_BITS = (BLOCK_SIZE - 1).bit_length()
INDEX_BITS  = (NUM_LINES - 1).bit_length()
TAG_BITS    = ADDR_BITS - INDEX_BITS - OFFSET_BITS


def split(addr):
    """Return (tag, index, offset) for a byte address."""
    offset = addr & (BLOCK_SIZE - 1)
    index  = (addr >> OFFSET_BITS) & (NUM_LINES - 1)
    tag    = addr >> (OFFSET_BITS + INDEX_BITS)
    return tag, index, offset


def simulate(addresses):
    """Run the trace through a cold direct-mapped cache; return a stats dict."""
    tags  = [0] * NUM_LINES
    valid = [False] * NUM_LINES
    hits = misses = 0

    for a in addresses:
        tag, index, _ = split(a)
        if valid[index] and tags[index] == tag:
            hits += 1
        else:
            misses += 1
            valid[index] = True      # refill
            tags[index] = tag

    n = hits + misses
    hit_rate  = hits / n if n else 0.0
    miss_rate = misses / n if n else 0.0
    amat = 1.0 + miss_rate * MEM_LATENCY          # cycles
    # measured cycles: hit = 1, miss = 1 + penalty
    total_cycles = hits * 1 + misses * (1 + MEM_LATENCY)
    return {
        "accesses": n, "hits": hits, "misses": misses,
        "hit_rate": hit_rate, "miss_rate": miss_rate,
        "amat": amat, "amat_measured": total_cycles / n if n else 0.0,
    }


def load_trace(path):
    with open(path) as f:
        return [int(line.strip(), 16) for line in f if line.strip()]


def report(path, s):
    print(f"=====================================================")
    print(f" Direct-Mapped Cache  --  Hit/Miss Report  (reference model)")
    print(f"   trace        : {path}")
    print(f"   config       : {CACHE_SIZE} B cache, {BLOCK_SIZE} B blocks, {NUM_LINES} lines")
    print(f"   fields       : tag={TAG_BITS}  index={INDEX_BITS}  offset={OFFSET_BITS} bits")
    print(f"   miss penalty : {MEM_LATENCY} cycles")
    print(f"-----------------------------------------------------")
    print(f"   accesses     : {s['accesses']}")
    print(f"   hits         : {s['hits']}")
    print(f"   misses       : {s['misses']}")
    print(f"   hit  ratio   : {100*s['hit_rate']:.2f} %")
    print(f"   miss ratio   : {100*s['miss_rate']:.2f} %")
    print(f"-----------------------------------------------------")
    print(f"   AMAT (model) : {s['amat']:.3f} cycles  [1 + miss_rate*{MEM_LATENCY}]")
    print(f"   AMAT (meas.) : {s['amat_measured']:.3f} cycles  [total_cycles/accesses]")
    print(f"=====================================================")


def self_test():
    # field split sanity
    assert (TAG_BITS, INDEX_BITS, OFFSET_BITS) == (22, 6, 4), (TAG_BITS, INDEX_BITS, OFFSET_BITS)
    # 0x0000_0010 -> offset 0, index 1, tag 0
    assert split(0x10) == (0, 1, 0)
    # all-same block -> 1 miss then all hits (spatial locality within a block)
    s = simulate([0, 4, 8, 12] * 5)          # 20 accesses, same block
    assert s["misses"] == 1 and s["hits"] == 19, s
    # stride of exactly one cache size -> every access conflicts on same line
    conflict = [i * CACHE_SIZE for i in range(10)]   # all map to index 0, new tags
    s = simulate(conflict)
    assert s["hits"] == 0 and s["misses"] == 10, s
    # cold compulsory misses: NUM_LINES distinct blocks, one each -> all miss once
    s = simulate([i * BLOCK_SIZE for i in range(NUM_LINES)])
    assert s["misses"] == NUM_LINES and s["hits"] == 0, s
    print("self-test: OK")


def main(argv):
    if "--self-test" in argv:
        self_test()
        return
    paths = []
    for a in argv[1:]:
        paths.extend(glob.glob(a))
    if not paths:
        print(__doc__)
        return
    for p in sorted(paths):
        report(p, simulate(load_trace(p)))


if __name__ == "__main__":
    main(sys.argv)
