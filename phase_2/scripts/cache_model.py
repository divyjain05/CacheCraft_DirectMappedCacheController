#!/usr/bin/env python3
"""Parameterized cache model - Phase 2 analysis engine.

Extends the Phase 1 direct-mapped model with:
  - configurable associativity (1 = direct-mapped, 2/4/... = set-associative)
  - configurable cache size and block size
  - LRU replacement within a set
  - write policy: write-back (write-allocate) or write-through (no-allocate)

It is the reference for the Phase 2 RTL and the engine behind the parameter
sweep (scripts/sweep.py). Traces are lists of (op, addr) with op in {'R','W'}.

AMAT = hit_time + miss_rate * miss_penalty     (hit_time = 1 cycle)

Usage:
  python3 scripts/cache_model.py --self-test
  python3 scripts/cache_model.py sim/traces/mixed.txt --assoc 2 --write-back
"""
import argparse


class Cache:
    def __init__(self, cache_size=1024, block_size=16, assoc=1,
                 write_back=True, mem_latency=10):
        assert cache_size % (block_size * assoc) == 0, "size not divisible by block*assoc"
        self.block_size = block_size
        self.assoc = assoc
        self.num_sets = cache_size // (block_size * assoc)
        self.write_back = write_back
        self.mem_latency = mem_latency
        self.cache_size = cache_size
        # each set: list of ways; a way is a dict {tag, dirty} or None (empty)
        self.sets = [[None] * assoc for _ in range(self.num_sets)]
        # LRU order per set: list of way-indices, most-recent last
        self.lru = [list(range(assoc)) for _ in range(self.num_sets)]
        self.reset_stats()

    def reset_stats(self):
        self.read_hits = self.read_misses = 0
        self.write_hits = self.write_misses = 0
        self.writebacks = 0          # dirty evictions (write-back only)
        self.mem_block_reads = 0     # blocks fetched from memory
        self.mem_block_writes = 0    # blocks written to memory (writeback or write-through line fills aside)

    # --- address split ------------------------------------------------------
    def _split(self, addr):
        offset_bits = (self.block_size - 1).bit_length()
        index_bits = (self.num_sets - 1).bit_length() if self.num_sets > 1 else 0
        index = (addr >> offset_bits) & (self.num_sets - 1) if self.num_sets > 1 else 0
        tag = addr >> (offset_bits + index_bits)
        return tag, index

    def _touch(self, index, way):
        """Mark `way` as most-recently used in its set."""
        order = self.lru[index]
        order.remove(way)
        order.append(way)

    def _find(self, index, tag):
        for way, line in enumerate(self.sets[index]):
            if line is not None and line["tag"] == tag:
                return way
        return None

    def _victim(self, index):
        """Return the LRU way index (least-recently used = front of order)."""
        return self.lru[index][0]

    # --- one access ---------------------------------------------------------
    def access(self, op, addr):
        tag, index = self._split(addr)
        way = self._find(index, tag)

        if way is not None:                       # ---- HIT ----
            self._touch(index, way)
            if op == "W":
                self.write_hits += 1
                if self.write_back:
                    self.sets[index][way]["dirty"] = True
                else:                             # write-through: update memory
                    self.mem_block_writes += 1
            else:
                self.read_hits += 1
            return

        # ---- MISS ----
        if op == "W":
            self.write_misses += 1
        else:
            self.read_misses += 1

        allocate = self.write_back or op == "R"   # write-through = no-write-allocate
        if not allocate:
            # write-through write miss: write straight to memory, no line fill
            self.mem_block_writes += 1
            return

        victim = self._victim(index)
        old = self.sets[index][victim]
        if old is not None and old.get("dirty"):  # evict dirty line
            self.writebacks += 1
            self.mem_block_writes += 1
        self.mem_block_reads += 1                  # fetch the new block
        self.sets[index][victim] = {
            "tag": tag,
            "dirty": (op == "W" and self.write_back),
        }
        if op == "W" and not self.write_back:
            self.mem_block_writes += 1
        self._touch(index, victim)

    # --- run + stats --------------------------------------------------------
    def run(self, trace):
        for op, addr in trace:
            self.access(op, addr)
        return self.stats()

    def stats(self):
        hits = self.read_hits + self.write_hits
        misses = self.read_misses + self.write_misses
        n = hits + misses
        miss_rate = misses / n if n else 0.0
        return {
            "accesses": n, "hits": hits, "misses": misses,
            "hit_rate": hits / n if n else 0.0,
            "miss_rate": miss_rate,
            "read_hits": self.read_hits, "read_misses": self.read_misses,
            "write_hits": self.write_hits, "write_misses": self.write_misses,
            "writebacks": self.writebacks,
            "mem_block_reads": self.mem_block_reads,
            "mem_block_writes": self.mem_block_writes,
            "amat": 1.0 + miss_rate * self.mem_latency,
        }


def load_trace(path):
    """Read a trace file. Lines: 'R <hexaddr>' / 'W <hexaddr>', or bare hex (=read)."""
    trace = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) == 1:
                trace.append(("R", int(parts[0], 16)))
            else:
                trace.append((parts[0].upper(), int(parts[1], 16)))
    return trace


def self_test():
    # direct-mapped, same block -> 1 miss then hits
    c = Cache(assoc=1)
    s = c.run([("R", a) for a in [0, 4, 8, 12] * 5])
    assert s["misses"] == 1 and s["hits"] == 19, s

    # conflict case: addresses a cache-size apart thrash a direct-mapped line,
    # but a 2-way cache holds both -> fewer misses.
    size = 1024
    stride = [("R", (i % 2) * size) for i in range(20)]   # two blocks, same set
    dm = Cache(cache_size=size, assoc=1).run(stride)
    sa = Cache(cache_size=size, assoc=2).run(stride)
    assert dm["misses"] == 20, dm          # direct-mapped: every access conflicts
    assert sa["misses"] == 2,  sa          # 2-way: 2 compulsory, rest hit
    assert sa["hits"] > dm["hits"], (dm, sa)

    # write-back dirty eviction produces a writeback
    c = Cache(cache_size=size, block_size=16, assoc=1, write_back=True)
    c.run([("W", 0), ("R", size)])         # write line 0, then evict it
    assert c.writebacks == 1, c.stats()

    # write-through never writes back dirty lines
    c = Cache(cache_size=size, assoc=1, write_back=False)
    c.run([("W", 0), ("R", size)])
    assert c.writebacks == 0, c.stats()

    print("self-test: OK")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("trace", nargs="?")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--cache-size", type=int, default=1024)
    ap.add_argument("--block-size", type=int, default=16)
    ap.add_argument("--assoc", type=int, default=1)
    ap.add_argument("--write-back", action="store_true", default=True)
    ap.add_argument("--write-through", dest="write_back", action="store_false")
    args = ap.parse_args()

    if args.self_test or not args.trace:
        self_test()
        return

    c = Cache(args.cache_size, args.block_size, args.assoc, args.write_back)
    s = c.run(load_trace(args.trace))
    policy = "write-back" if args.write_back else "write-through"
    print(f"trace={args.trace}  {args.cache_size}B  {args.block_size}B blk  "
          f"{args.assoc}-way  {policy}")
    print(f"  hit rate   : {100*s['hit_rate']:.2f}%   miss rate: {100*s['miss_rate']:.2f}%")
    print(f"  reads  h/m : {s['read_hits']}/{s['read_misses']}")
    print(f"  writes h/m : {s['write_hits']}/{s['write_misses']}")
    print(f"  writebacks : {s['writebacks']}")
    print(f"  AMAT       : {s['amat']:.3f} cycles")


if __name__ == "__main__":
    main()
