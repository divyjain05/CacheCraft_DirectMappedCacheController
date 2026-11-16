// ============================================================================
// cache_defs.vh  --  Direct-Mapped Cache configuration
// ----------------------------------------------------------------------------
// Default student configuration:
//   Cache size      = 1 KB  (1024 bytes)
//   Block size      = 16 bytes  (4 words of 32 bits)
//   Address width   = 32 bits, byte addressed
//
// Address field split (32-bit address):
//   | TAG (22) | INDEX (6) | OFFSET (4) |
//      31..10     9..4        3..0
//
//   OFFSET = log2(16)              = 4 bits
//   INDEX  = log2(1024/16 = 64)    = 6 bits
//   TAG    = 32 - 6 - 4            = 22 bits
//
// Change CACHE_SIZE / BLOCK_SIZE below to experiment; derived widths update
// automatically through the $clog2-style constants kept in sync here.
// ============================================================================
`ifndef CACHE_DEFS_VH
`define CACHE_DEFS_VH

`define ADDR_WIDTH    32
`define WORD_WIDTH    32

`define CACHE_SIZE    1024                       // bytes
`define BLOCK_SIZE    16                         // bytes per block/line
`define NUM_LINES     (`CACHE_SIZE/`BLOCK_SIZE)  // 64 cache lines

`define OFFSET_BITS   4                          // log2(BLOCK_SIZE)
`define INDEX_BITS    6                          // log2(NUM_LINES)
`define TAG_BITS      22                         // ADDR_WIDTH-INDEX-OFFSET

`define BLOCK_BITS    (`BLOCK_SIZE*8)            // 128 bits per line
`define WORDS_PER_BLK (`BLOCK_SIZE/4)            // 4 words per line

// Main-memory block fetch latency, in cycles. This is the miss penalty used
// for the AMAT calculation (hardware knob: tune to model real DRAM timing).
`define MEM_LATENCY   10

`endif
