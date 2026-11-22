// ============================================================================
// main_memory_rw.v  --  read/write main-memory model (Phase 2)
// ----------------------------------------------------------------------------
// Block-granular memory behind the cache. Supports both block reads (refill)
// and block writes (write-back). One operation at a time via a req/ready
// handshake with MEM_LATENCY cycles of delay.
//
//   req=1, we=0 : read  block at addr -> rdata after latency, ready pulse
//   req=1, we=1 : write wdata to block at addr          -> ready pulse
//
// Backed by a 1024-entry block array indexed by the block address (ample for
// the bounded test traces). Initialised with a deterministic pattern so reads
// before any write return known data.
// ============================================================================
`include "cache_defs.vh"

module main_memory_rw (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    req,
    input  wire                    we,
    input  wire [`ADDR_WIDTH-1:0]  addr,
    input  wire [`BLOCK_BITS-1:0]  wdata,
    output reg                     ready,
    output reg  [`BLOCK_BITS-1:0]  rdata
);
    localparam MEM_BLOCKS = 1024;
    reg [`BLOCK_BITS-1:0] mem [0:MEM_BLOCKS-1];

    integer i;
    initial begin
        for (i = 0; i < MEM_BLOCKS; i = i + 1) begin
            // 4 words: base+0, base+4, base+8, base+12  (base = block*BLOCK_SIZE)
            mem[i][31:0]    = i*`BLOCK_SIZE + 0;
            mem[i][63:32]   = i*`BLOCK_SIZE + 4;
            mem[i][95:64]   = i*`BLOCK_SIZE + 8;
            mem[i][127:96]  = i*`BLOCK_SIZE + 12;
        end
    end

    function [31:0] blk_index(input [`ADDR_WIDTH-1:0] a);
        blk_index = (a >> `OFFSET_BITS) & (MEM_BLOCKS-1);
    endfunction

    localparam IDLE = 1'b0, BUSY = 1'b1;
    reg        state;
    reg [31:0] cnt;
    reg        we_l;
    reg [31:0] blk_l;
    reg [`BLOCK_BITS-1:0] wdata_l;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; ready <= 1'b0; cnt <= 0;
        end else begin
            ready <= 1'b0;
            case (state)
                IDLE: if (req) begin
                    we_l    <= we;
                    blk_l   <= blk_index(addr);
                    wdata_l <= wdata;
                    cnt     <= `MEM_LATENCY;
                    state   <= BUSY;
                end
                BUSY: begin
                    if (cnt <= 32'd1) begin
                        if (we_l) mem[blk_l] <= wdata_l;
                        rdata <= we_l ? wdata_l : mem[blk_l];
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
