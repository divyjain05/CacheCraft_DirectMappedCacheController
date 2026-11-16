// ============================================================================
// valid_ram.v  --  one valid bit per cache line.
//   Cleared on reset (cold cache -> every first access misses).
//   Set when a line is refilled. Combinational read.
// ============================================================================
`include "cache_defs.vh"

module valid_ram (
    input  wire                   clk,
    input  wire                   rst,     // synchronous clear of all valid bits
    input  wire                   we,      // mark selected line valid
    input  wire [`INDEX_BITS-1:0] index,
    output wire                   valid
);
    reg [`NUM_LINES-1:0] valid_bits;

    always @(posedge clk) begin
        if (rst)      valid_bits          <= {`NUM_LINES{1'b0}};
        else if (we)  valid_bits[index]   <= 1'b1;
    end

    assign valid = valid_bits[index];
endmodule
