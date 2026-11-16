# AMAT — Average Memory Access Time

## Formula

```
AMAT = hit_time + miss_rate × miss_penalty
```

For this design:

- `hit_time`     = **1 cycle** (single-cycle tag compare + data read)
- `miss_penalty` = **10 cycles** (`MEM_LATENCY`, time to fetch a block)
- `miss_rate`    = misses / accesses, measured per trace

## Measured results (256 accesses each)

| Trace        | Hits | Misses | Hit ratio | Miss ratio | AMAT (cycles) |
|--------------|-----:|-------:|----------:|-----------:|--------------:|
| `sequential` | 192  | 64     | 75.00 %   | 25.00 %    | 3.500         |
| `repeated`   | 248  | 8      | 96.88 %   | 3.12 %     | 1.312         |
| `random`     | 41   | 215    | 16.02 %   | 83.98 %    | 9.398         |

Figures are produced by the Verilog testbench (`make run`).

## Reading the numbers

- **sequential** — stride of one word (4 B). Each 16-byte block holds 4 words,
  so the first access to a block misses and the next three hit → exactly
  **1 miss per 4 accesses = 25 %**. This is pure **spatial locality**.

- **repeated** — a working set of 8 blocks is cycled over. After the 8
  compulsory (cold) misses, every access hits → **~97 %**. This is
  **temporal locality** fitting inside the cache.

- **random** — addresses spread over 4× the cache size, so most accesses hit a
  different block than last time; conflict + capacity misses dominate →
  **~16 % hit rate** and AMAT close to the full miss penalty.

## Takeaway

AMAT collapses the whole hierarchy into one number: when locality is good the
cache hides almost all of the 10-cycle memory latency (AMAT ≈ 1.3), and when
locality is poor the CPU pays nearly the full penalty on every access
(AMAT ≈ 9.4). Bigger blocks help `sequential`; more capacity/associativity
would help `random` — those are the natural follow-up experiments.
