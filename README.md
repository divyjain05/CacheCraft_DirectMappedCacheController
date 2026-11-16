# Direct-Mapped Cache Controller

Modern Computer Architecture — Project 6.

A direct-mapped cache controller written in Verilog, with a trace-driven
testbench used to measure cache hit/miss behaviour and Average Memory Access
Time (AMAT).

**Prototype video:** https://drive.google.com/drive/folders/1_YVVmzS3EF0rlKR3aBxHxGnPDqahJ7lW?usp=sharing

## Configuration

- 1 KB cache, 16-byte blocks, 32-bit byte addresses, 64 lines
- Address split: `TAG[31:10]` (22 bits), `INDEX[9:4]` (6 bits), `OFFSET[3:0]` (4 bits)
- Miss penalty: 10 cycles

## Layout

```
rtl/       Verilog source (8 modules + top-level)
sim/       testbench and memory-access traces
scripts/   trace generator and Python reference model
docs/      architecture and AMAT notes
reports/   saved hit/miss + AMAT output
report/    IEEE report (LaTeX + PDF)
video/     demo video script
```

## Build and run

Requires Icarus Verilog (`iverilog`).

```bash
make run      # compile the RTL and run the testbench on all traces
make pysim    # run the Python model only (no HDL tools needed)
make traces   # regenerate the access traces
```

## Results (256 accesses)

| Trace      | Hit ratio | Miss ratio | AMAT (cycles) |
|------------|----------:|-----------:|--------------:|
| sequential | 75.00 %   | 25.00 %    | 3.500         |
| repeated   | 96.88 %   | 3.12 %     | 1.312         |
| random     | 16.02 %   | 83.98 %    | 9.398         |

See [docs/architecture.md](docs/architecture.md) for the design and
[docs/amat.md](docs/amat.md) for the AMAT analysis.

## Team

- Divy Kumar Jain - 2401010157 — architecture and address decoding
- Praveen Kumar Nitharwal - 2401020049— cache storage (data, tag, valid)
- Utkarsh Jain - 2401020072 — controller FSM and memory interface, integration and testbench
- Piyush Raj - 2401010328— traces, analysis, and report
