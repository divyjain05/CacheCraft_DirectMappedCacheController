# Phase 2 Design - Set-Associative Cache, Write Policy, Synthesis & Sweep

Phase 2 completes the project by extending the Phase 1 direct-mapped read-only
cache into a **2-way set-associative, write-back cache**, and by exploring the
design space with a parameter sweep and a synthesis pass.

## 1. What changed from Phase 1

| Aspect | Phase 1 | Phase 2 |
|--------|---------|---------|
| Mapping | direct-mapped (1 way) | 2-way set-associative + LRU |
| Accesses | read-only | read **and** write |
| Write policy | - | write-back + write-allocate (dirty bit) |
| Sets / lines | 64 lines | 32 sets x 2 ways |
| Address split | tag 22 / index 6 / offset 4 | tag 23 / index 5 / offset 4 |
| Analysis | fixed config | parameter sweep + synthesis |

## 2. Set-associative mapping

With 2 ways, a block may live in either way of its set, so two blocks that
collide in a direct-mapped cache can now coexist:

```
 31                      9 8    4 3    0
+--------------------------+------+------+
|         TAG (23)         |IDX 5 |OFF 4 |
+--------------------------+------+------+
```

`index` selects one of 32 sets; the tag is compared against **both** ways in
parallel. A hit in either way returns data in one cycle.

## 3. LRU replacement

For 2 ways, LRU needs a single bit per set. `lru[set]` names the way to evict.
On every hit or fill of way *w*, the **other** way becomes the LRU victim
(`lru[set] <= ~w`). On a miss the victim is `lru[set]`.

## 4. Write-back policy

- **Write hit:** update the word in the cache, set the line's **dirty** bit. No
  memory traffic.
- **Write miss (write-allocate):** fetch the block, merge the store word, mark
  the line dirty.
- **Eviction of a dirty line:** the old block is written back to memory first
  (the `WB` state), then the new block is fetched.

This trades a dirty bit and writeback logic for far less write traffic than
write-through - visible in the sweep (`mem_writes` column of the CSV).

## 5. Controller FSM

```
IDLE  --hit-------------------------------> IDLE   (1-cycle read/write hit)
IDLE  --miss, victim clean---------------> ALLOC
IDLE  --miss, victim dirty---------------> WB --> ALLOC
ALLOC --block fetched--------------------> FIN  --> IDLE
```

- Hit: 1 cycle. Clean miss: `1 + MEM_LATENCY`. Dirty miss: `1 + 2*MEM_LATENCY`
  (writeback + fetch).

## 6. Results

### RTL simulation (`make run`) vs reference model (`make sweep`)

Hit ratios and writeback counts from the Verilog (`reports/rtl_sa_report.txt`)
match the Python model exactly:

| Trace | Hit ratio | Writebacks | AMAT (model) |
|-------|----------:|-----------:|-------------:|
| conflict | 99.22 % | 0 | 1.078 |
| repeated | 96.88 % | 0 | 1.312 |
| sequential | 75.00 % | 0 | 3.500 |
| random | 17.97 % | 40 | 9.203 |

For `random`, the RTL also reports an **effective** AMAT of 10.766 cycles once
writeback stalls are counted - the real cost the analytic formula omits.

### Parameter sweep (`reports/sweep_results.csv`)

Observations from the sweep:

- Associativity removes conflict misses. On the `conflict` trace a
  direct-mapped cache gets 0 % hits (two blocks thrash one line) while the
  2-way cache gets 99.22 %.
- Larger blocks improve spatial locality. `sequential` rises from 75 % (16 B
  blocks) to 87.5 % (32 B blocks).
- More capacity reduces capacity misses. `random` rises from 14.5 % (1 KB) to
  28.1 % (2 KB).
- Write-through has zero writebacks but, with no-write-allocate, gives lower
  hit ratios on write-heavy traces than write-back.

## 7. Synthesis

`synth/synth.ys` synthesizes `sa_cache` with Yosys and prints a cell/area
report (`make synth`, saved to `reports/synth_report.txt`). Mapped to generic
gates:

| Resource | Count |
|----------|------:|
| Total cells | 25,233 |
| Flip-flops | 9,828 |
| Multiplexers | 8,786 |
| Wires | 14,660 |

The ~9,800 flip-flops are the storage: 2 ways x 32 lines x (128-bit data +
23-bit tag + valid + dirty) ~ 9,792 bits, plus the per-set LRU bits and FSM
state. The mux count reflects way-select, word-select, and writeback logic.
