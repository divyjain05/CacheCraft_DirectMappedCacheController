# Architecture — Direct-Mapped Cache Controller

## 1. Configuration

| Parameter      | Value      | Notes                              |
|----------------|------------|------------------------------------|
| Address width  | 32 bits    | byte addressed                     |
| Cache size     | 1 KB       | 1024 bytes of data                 |
| Block size     | 16 bytes   | 4 words × 32 bits                  |
| Lines          | 64         | `1024 / 16`                        |
| Mapping        | direct     | line = `index` (no associativity)  |
| Miss penalty   | 10 cycles  | `MEM_LATENCY` in `cache_defs.vh`   |

## 2. Address breakdown

```
 31                                10 9        4 3     0
+-------------------------------------+----------+------+
|                TAG (22)             | INDEX(6) |OFF(4)|
+-------------------------------------+----------+------+
```

- **OFFSET (4 bits)** — byte within the 16-byte block. Bits `[3:2]` select which
  of the 4 words is returned to the CPU.
- **INDEX (6 bits)** — selects one of 64 cache lines.
- **TAG (22 bits)** — stored alongside the line and compared on every lookup.

Derivation: `offset = log2(16) = 4`, `index = log2(64) = 6`,
`tag = 32 − 6 − 4 = 22`.

## 3. Block diagram

```
          cpu_addr
             │
             ▼
     ┌───────────────┐   tag    ┌──────────────┐
     │ address_decoder├────────►│tag_comparator│───► hit
     └──┬────┬────┬───┘  index  └──────▲───┬───┘
        │    │    │ offset              │   │valid
   index│    │    └──────────┐    rtag  │   │
        ▼    ▼               ▼          │   │
   ┌────────┐ ┌────────┐ ┌─────────┐    │   │
   │tag_ram │ │valid_ram│ │data_ram │───┼───┼──► word_sel ─► cpu_rdata
   └────────┘ └────────┘ └────▲────┘    │   │
        ▲         ▲           │ wdata   │   │
        │ we      │ we        │         │   │
        └─────────┴───────────┴─────────┘   │
                     cache_we               │
             ┌───────────────────┐  hit     │
   cpu_req──►│ cache_controller  │◄─────────┘
             │       FSM         │  mem_ready
             └───┬───────────┬───┘◄──────────┐
          cpu_ready      mem_req              │
                             ▼                │
                      ┌─────────────┐  rdata  │
                      │ main_memory │─────────┘
                      └─────────────┘
```

## 4. Controller FSM

| State      | Meaning                               | Exit condition → next     |
|------------|---------------------------------------|---------------------------|
| `IDLE`     | wait for `cpu_req`; `hit` is combinational | hit → `IDLE` (strobe ready); miss → `ALLOCATE` |
| `ALLOCATE` | hold `mem_req`, wait for the block     | `mem_ready` → latch block (`cache_we`), `DONE` |
| `DONE`     | block now cached; answer the CPU       | always → `IDLE`           |

- A **hit** completes in **1 cycle** (`cpu_ready` in the same cycle as the request).
- A **miss** costs **1 + MEM_LATENCY** cycles (lookup + refill).
- `hit_strobe` / `miss_strobe` are 1-cycle pulses the testbench counts.

## 5. Why direct-mapped

Each memory block maps to exactly one line (`index = (block) mod 64`). This
makes lookup trivial (one tag compare, no replacement policy) but causes
**conflict misses**: two blocks whose addresses differ by a multiple of the
cache size (1 KB) collide on the same line and evict each other repeatedly.
The `random` trace and the FSM's conflict behavior make this visible in the
hit/miss report.
