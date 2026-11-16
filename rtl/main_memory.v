// ============================================================================
// main_memory.v  --  behavioural main-memory model behind the cache.
//   On a block request it waits MEM_LATENCY cycles, then pulses `ready` for
//   one cycle with the 128-bit block on `rdata`. Block contents are generated
//   deterministically from the block address so results are reproducible
//   without preloading a memory image.
// ============================================================================
`include "cache_defs.vh"

module main_memory (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    req,      // request a block (level, held during wait)
    input  wire [`ADDR_WIDTH-1:0]  addr,     // any address inside the block
    output reg                     ready,    // 1-cycle pulse when block is delivered
    output reg  [`BLOCK_BITS-1:0]  rdata
);
    // Block-aligned base address (offset bits forced to 0).
    wire [`ADDR_WIDTH-1:0] blk_base =
        {addr[`ADDR_WIDTH-1:`OFFSET_BITS], {`OFFSET_BITS{1'b0}}};

    localparam IDLE = 1'b0, BUSY = 1'b1;
    reg        state;
    reg [31:0] cnt;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            ready <= 1'b0;
            cnt   <= 32'd0;
            rdata <= {`BLOCK_BITS{1'b0}};
        end else begin
            ready <= 1'b0;                 // default: no pulse
            case (state)
                IDLE: if (req) begin
                    cnt   <= `MEM_LATENCY;
                    state <= BUSY;
                end
                BUSY: begin
                    if (cnt <= 32'd1) begin
                        // Deliver the block: 4 words = base+0, base+1, base+2, base+3
                        rdata <= { (blk_base + 32'd3),
                                   (blk_base + 32'd2),
                                   (blk_base + 32'd1),
                                   (blk_base + 32'd0) };
                        ready <= 1'b1;
                        state <= IDLE;
                    end else begin
                        cnt <= cnt - 32'd1;
                    end
                end
            endcase
        end
    end
endmodule
