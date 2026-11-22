// ============================================================================
// cache_defs.vh  --  Phase 2: 2-way set-associative, write-back cache
// ----------------------------------------------------------------------------
//   Cache size   = 1 KB
//   Block size   = 16 bytes (4 words)
//   Associativity= 2 ways
//   => Sets       = 1024 / (16 * 2) = 32 sets
//
//   Address split (32-bit byte address):
//     | TAG (23) | INDEX (5) | OFFSET (4) |
//        31..9      8..4        3..0
//     OFFSET = log2(16) = 4,  INDEX = log2(32) = 5,  TAG = 32-5-4 = 23
//
//   Policies: write-back + write-allocate, LRU replacement (1 bit/set).
// ============================================================================
`ifndef CACHE_DEFS_VH
`define CACHE_DEFS_VH

`define ADDR_WIDTH    32
`define WORD_WIDTH    32

`define CACHE_SIZE    1024
`define BLOCK_SIZE    16
`define ASSOC         2
`define NUM_SETS      (`CACHE_SIZE/(`BLOCK_SIZE*`ASSOC))   // 32

`define OFFSET_BITS   4
`define INDEX_BITS    5
`define TAG_BITS      23

`define BLOCK_BITS    (`BLOCK_SIZE*8)     // 128
`define WORDS_PER_BLK (`BLOCK_SIZE/4)     // 4

`define MEM_LATENCY   10

`endif
