// ============================================================================
// tag_comparator.v  --  hit = line is valid AND stored tag matches request tag
// ============================================================================
`include "cache_defs.vh"

module tag_comparator (
    input  wire [`TAG_BITS-1:0] tag_in,      // tag from the incoming address
    input  wire [`TAG_BITS-1:0] tag_stored,  // tag read out of the Tag RAM
    input  wire                 valid,       // valid bit of the selected line
    output wire                 hit
);
    assign hit = valid & (tag_in == tag_stored);
endmodule
