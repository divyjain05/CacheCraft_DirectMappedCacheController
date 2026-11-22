# Phase 2 - Set-Associative Write-Back Cache

Modern Computer Architecture - Project 6, Phase 2 (completes the project).

Extends the Phase 1 direct-mapped read-only cache into a **2-way
set-associative, write-back cache** with LRU replacement, and adds design-space
analysis (parameter sweep) and logic synthesis.

See [understanding.txt](understanding.txt) for the per-member file/commit split.

## Configuration

- 1 KB cache, 16-byte blocks, **2-way set-associative**, 32 sets
- Address split: `TAG[31:9]` (23), `INDEX[8:4]` (5), `OFFSET[3:0]` (4)
- Write policy: write-back + write-allocate, dirty bit, LRU replacement

## Layout

```
rtl/       sa_cache (core), main_memory_rw, top-level
sim/       read/write testbench and traces
scripts/   cache_model.py (reference), sweep.py, gen_rw_traces.py
synth/     Yosys synthesis script
docs/      Phase 2 design notes
reports/   sweep results, RTL report
report/    Phase 2 IEEE report (LaTeX)
```

## Build and run

```bash
make model    # Python reference-model self-test (no tools needed)
make sweep    # parameter sweep -> reports/sweep_results.csv
make run      # compile RTL + run testbench on all traces (needs iverilog)
make synth    # synthesize the cache (needs yosys)
```

## Key results (256 accesses)

RTL and the reference model agree exactly on hit ratio and writebacks.

| Trace      | Hit ratio | Writebacks | AMAT  |
|------------|----------:|-----------:|------:|
| conflict   | 99.22 %   | 0          | 1.078 |
| repeated   | 96.88 %   | 0          | 1.312 |
| sequential | 75.00 %   | 0          | 3.500 |
| random     | 17.97 %   | 40         | 9.203 |

Effect of associativity: on the `conflict` trace a direct-mapped cache gets
0 % hits (two blocks thrash one line), while the 2-way cache gets 99.22 %. Full
comparison in [docs/phase2_design.md](docs/phase2_design.md) and
`reports/sweep_results.csv`.
