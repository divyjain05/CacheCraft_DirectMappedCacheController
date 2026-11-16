// ============================================================================
// cache_data_ram.v  --  NUM_LINES x BLOCK_BITS data store (one block per line)
//   Synchronous write, combinational read (single-cycle lookup).
// ============================================================================
`include "cache_defs.vh"

module cache_data_ram (
    input  wire                    clk,
    input  wire                    we,       // write whole block on refill
    input  wire [`INDEX_BITS-1:0]  index,
    input  wire [`BLOCK_BITS-1:0]  wdata,    // block fetched from main memory
    output wire [`BLOCK_BITS-1:0]  rdata
);
    reg [`BLOCK_BITS-1:0] mem [0:`NUM_LINES-1];

    always @(posedge clk)
        if (we) mem[index] <= wdata;

    assign rdata = mem[index];
endmodule
