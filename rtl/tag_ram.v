// ============================================================================
// tag_ram.v  --  NUM_LINES x TAG_BITS tag store.
//   Synchronous write, combinational read.
// ============================================================================
`include "cache_defs.vh"

module tag_ram (
    input  wire                   clk,
    input  wire                   we,
    input  wire [`INDEX_BITS-1:0] index,
    input  wire [`TAG_BITS-1:0]   wtag,
    output wire [`TAG_BITS-1:0]   rtag
);
    reg [`TAG_BITS-1:0] mem [0:`NUM_LINES-1];

    always @(posedge clk)
        if (we) mem[index] <= wtag;

    assign rtag = mem[index];
endmodule
