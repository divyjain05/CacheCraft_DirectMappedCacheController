// ============================================================================
// cache_controller.v  --  Direct-Mapped Cache controller FSM
// ----------------------------------------------------------------------------
// Pure control: it watches the combinational `hit` signal and the memory
// handshake, and drives the write-enables / response strobes for the datapath.
//
//   States:
//     IDLE     : wait for cpu_req. hit is combinational, so decide here.
//                 - hit  -> strobe cpu_ready + hit_strobe, stay IDLE
//                 - miss -> assert mem_req, go ALLOCATE
//     ALLOCATE : hold mem_req until main memory pulses mem_ready. When it does,
//                raise cache_we so Data/Tag/Valid RAMs latch the block, go DONE.
//     DONE     : block is now in the cache -> strobe cpu_ready + miss_strobe,
//                return to IDLE.
//
//   hit_strobe / miss_strobe are 1-cycle pulses used by the testbench to count
//   hits and misses.
// ============================================================================
`include "cache_defs.vh"

module cache_controller (
    input  wire clk,
    input  wire rst,
    input  wire cpu_req,      // CPU wants to read `addr`
    input  wire hit,          // combinational hit from tag comparator
    input  wire mem_ready,    // main memory delivered the block

    output reg  mem_req,      // request a block refill from main memory
    output reg  cache_we,     // write Data/Tag/Valid RAMs this cycle
    output reg  cpu_ready,    // response strobe to CPU (1 cycle)
    output reg  hit_strobe,   // 1-cycle pulse: this access was a hit
    output reg  miss_strobe   // 1-cycle pulse: this access was a miss
);
    localparam IDLE     = 2'd0,
               ALLOCATE = 2'd1,
               DONE     = 2'd2;

    reg [1:0] state, next;

    // ---- next-state + output logic (Mealy on cpu_req/hit/mem_ready) ----------
    always @(*) begin
        // defaults
        next       = state;
        mem_req    = 1'b0;
        cache_we   = 1'b0;
        cpu_ready  = 1'b0;
        hit_strobe = 1'b0;
        miss_strobe= 1'b0;

        case (state)
            IDLE: begin
                if (cpu_req) begin
                    if (hit) begin
                        cpu_ready  = 1'b1;
                        hit_strobe = 1'b1;
                        next       = IDLE;
                    end else begin
                        mem_req = 1'b1;
                        next    = ALLOCATE;
                    end
                end
            end

            ALLOCATE: begin
                mem_req = 1'b1;                 // hold request until served
                if (mem_ready) begin
                    cache_we = 1'b1;            // latch block into the RAMs
                    next     = DONE;
                end
            end

            DONE: begin
                cpu_ready   = 1'b1;
                miss_strobe = 1'b1;
                next        = IDLE;
            end

            default: next = IDLE;
        endcase
    end

    // ---- state register ------------------------------------------------------
    always @(posedge clk) begin
        if (rst) state <= IDLE;
        else     state <= next;
    end
endmodule
