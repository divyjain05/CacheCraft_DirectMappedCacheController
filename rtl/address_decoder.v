// ============================================================================
// address_decoder.v  --  splits a 32-bit byte address into tag/index/offset
// ============================================================================
`include "cache_defs.vh"

module address_decoder (
    input  wire [`ADDR_WIDTH-1:0]  addr,
    output wire [`TAG_BITS-1:0]    tag,
    output wire [`INDEX_BITS-1:0]  index,
    output wire [`OFFSET_BITS-1:0] offset,
    output wire [1:0]              word_sel   // which 32-bit word inside block
);
    assign offset   = addr[`OFFSET_BITS-1:0];
    assign index    = addr[`OFFSET_BITS +: `INDEX_BITS];
    assign tag      = addr[`OFFSET_BITS+`INDEX_BITS +: `TAG_BITS];
    assign word_sel = addr[3:2];   // byte offset bits [3:2] pick the word
endmodule
