# Cache Controller - Design and Analysis

Modern Computer Architecture - Project 6.

A Verilog cache controller with a trace-driven testbench used to measure cache
hit/miss behaviour and Average Memory Access Time (AMAT). The project is built
in two phases:

- **Phase 1** (repo root) - a direct-mapped, read-only cache.
- **Phase 2** (`phase2/`) - a 2-way set-associative, write-back cache that adds
  write support, LRU replacement, a parameter sweep, and logic synthesis.

**Prototype video:** https://drive.google.com/drive/folders/1_YVVmzS3EF0rlKR3aBxHxGnPDqahJ7lW?usp=sharing

## Phase 1 - Direct-Mapped Cache

Configuration:

- 1 KB cache, 16-byte blocks, 32-bit byte addresses, 64 lines
- Address split: `TAG[31:10]` (22 bits), `INDEX[9:4]` (6 bits), `OFFSET[3:0]` (4 bits)
- Miss penalty: 10 cycles

Build and run (requires Icarus Verilog):

```bash
make run      # compile the RTL and run the testbench on all traces
make pysim    # run the Python model only (no HDL tools needed)
make traces   # regenerate the access traces
```

Results (256 accesses):

| Trace      | Hit ratio | Miss ratio | AMAT (cycles) |
|------------|----------:|-----------:|--------------:|
| sequential | 75.00 %   | 25.00 %    | 3.500         |
| repeated   | 96.88 %   | 3.12 %     | 1.312         |
| random     | 16.02 %   | 83.98 %    | 9.398         |

See [docs/architecture.md](docs/architecture.md) for the design and
[docs/amat.md](docs/amat.md) for the AMAT analysis.

## Phase 2 - Set-Associative Write-Back Cache (`phase2/`)

Configuration:

- 1 KB cache, 16-byte blocks, 2-way set-associative, 32 sets
- Address split: `TAG[31:9]` (23 bits), `INDEX[8:4]` (5 bits), `OFFSET[3:0]` (4 bits)
- Write-back + write-allocate, dirty bit, LRU replacement

Build and run (from inside `phase2/`):

```bash
cd phase2
make run      # compile RTL + run the read/write testbench
make sweep    # parameter sweep -> reports/sweep_results.csv
make synth    # synthesize the cache (requires yosys)
```

Results (256 accesses):

| Trace      | Hit ratio | Writebacks | AMAT (cycles) |
|------------|----------:|-----------:|--------------:|
| conflict   | 99.22 %   | 0          | 1.078         |
| repeated   | 96.88 %   | 0          | 1.312         |
| sequential | 75.00 %   | 0          | 3.500         |
| random     | 17.97 %   | 40         | 9.203         |

On the `conflict` trace a direct-mapped cache gets 0 % hits (two blocks thrash
one line), while the 2-way cache gets 99.22 % - the effect of associativity on
conflict misses. See [phase2/docs/phase2_design.md](phase2/docs/phase2_design.md).

## Layout

```
rtl/       Phase 1 Verilog source (8 modules + top-level)
sim/       Phase 1 testbench and memory-access traces
scripts/   Phase 1 trace generator and Python reference model
docs/      Phase 1 architecture and AMAT notes
reports/   Phase 1 hit/miss + AMAT output
report/    Phase 1 IEEE report (LaTeX + PDF)
Video/     demo video link
phase2/    Phase 2 - set-associative write-back cache (self-contained)
```

## Team

- Divy Kumar Jain - 2401010157 - architecture and address decoding
- Praveen Kumar Nitharwal - 2401020049 - cache storage (data, tag, valid)
- Utkarsh Jain - 2401020072 - controller FSM and memory interface, integration and testbench
- Piyush Raj - 2401010328 - traces, analysis, and report
