// ============================================================================
// sa_cache.v  --  2-way set-associative, write-back cache with LRU (Phase 2)
// ----------------------------------------------------------------------------
// Specialised to ASSOC = 2 (one LRU bit per set). Supports CPU reads and
// writes. Policy: write-back + write-allocate. A dirty victim is written back
// to memory before the new block is fetched.
//
//   Controller FSM:
//     IDLE  : hit  -> answer in 1 cycle (read returns word; write updates word,
//                     sets dirty); update LRU.
//             miss -> if victim is valid+dirty go WB, else go ALLOC.
//     WB    : write the dirty victim block back to memory, then ALLOC.
//     ALLOC : fetch the requested block from memory, fill the victim way
//             (merging the store word on a write miss), update LRU, then FIN.
//     FIN   : answer the CPU (read returns the fetched word), back to IDLE.
//
//   Stat strobes (1-cycle): read_hit, read_miss, write_hit, write_miss,
//   writeback_strobe.
// ============================================================================
`include "cache_defs.vh"

module sa_cache (
    input  wire                    clk,
    input  wire                    rst,
    // CPU interface
    input  wire                    cpu_req,
    input  wire                    cpu_we,       // 1 = write, 0 = read
    input  wire [`ADDR_WIDTH-1:0]  cpu_addr,
    input  wire [`WORD_WIDTH-1:0]  cpu_wdata,
    output reg                     cpu_ready,
    output reg  [`WORD_WIDTH-1:0]  cpu_rdata,
    // memory interface
    output reg                     mem_req,
    output reg                     mem_we,
    output reg  [`ADDR_WIDTH-1:0]  mem_addr,
    output reg  [`BLOCK_BITS-1:0]  mem_wdata,
    input  wire                    mem_ready,
    input  wire [`BLOCK_BITS-1:0]  mem_rdata,
    // statistics
    output reg                     read_hit,
    output reg                     read_miss,
    output reg                     write_hit,
    output reg                     write_miss,
    output reg                     writeback_strobe
);
    // ---- address split -------------------------------------------------------
    wire [`INDEX_BITS-1:0] index    = cpu_addr[`OFFSET_BITS +: `INDEX_BITS];
    wire [`TAG_BITS-1:0]   tag       = cpu_addr[`OFFSET_BITS+`INDEX_BITS +: `TAG_BITS];
    wire [1:0]             word_sel  = cpu_addr[3:2];

    // ---- storage: two ways ---------------------------------------------------
    reg [`TAG_BITS-1:0]   tag0  [0:`NUM_SETS-1];
    reg [`TAG_BITS-1:0]   tag1  [0:`NUM_SETS-1];
    reg [`BLOCK_BITS-1:0] data0 [0:`NUM_SETS-1];
    reg [`BLOCK_BITS-1:0] data1 [0:`NUM_SETS-1];
    reg [`NUM_SETS-1:0]   valid0, valid1;
    reg [`NUM_SETS-1:0]   dirty0, dirty1;
    reg [`NUM_SETS-1:0]   lru;    // lru[s]=0 -> way0 is LRU (evict way0); =1 -> way1

    // ---- hit detection -------------------------------------------------------
    wire hit0 = valid0[index] & (tag0[index] == tag);
    wire hit1 = valid1[index] & (tag1[index] == tag);
    wire hit  = hit0 | hit1;
    wire hit_way = hit1;                 // 0 => way0, 1 => way1

    // ---- victim selection ----------------------------------------------------
    wire victim      = lru[index];       // way to evict on a miss
    wire victim_valid= victim ? valid1[index] : valid0[index];
    wire victim_dirty= victim ? dirty1[index] : dirty0[index];
    wire [`TAG_BITS-1:0]   victim_tag  = victim ? tag1[index]  : tag0[index];
    wire [`BLOCK_BITS-1:0] victim_block= victim ? data1[index] : data0[index];
    wire need_wb = victim_valid & victim_dirty;

    // ---- word select out of a block -----------------------------------------
    wire [`BLOCK_BITS-1:0] hit_block = hit_way ? data1[index] : data0[index];
    wire [`BLOCK_BITS-1:0] vic_block = victim  ? data1[index] : data0[index];

    // ---- block to fill on a miss (merge store word on a write miss) ----------
    function [`BLOCK_BITS-1:0] merge_word(
        input [`BLOCK_BITS-1:0] blk, input [31:0] w, input [1:0] sel);
        begin
            merge_word = blk;
            merge_word[sel*32 +: 32] = w;
        end
    endfunction
    wire [`BLOCK_BITS-1:0] fill_block =
        cpu_we ? merge_word(mem_rdata, cpu_wdata, word_sel) : mem_rdata;

    // ---- FSM -----------------------------------------------------------------
    localparam IDLE = 2'd0, WB = 2'd1, ALLOC = 2'd2, FIN = 2'd3;
    reg [1:0] state;

    integer k;
    always @(posedge clk) begin
        if (rst) begin
            state  <= IDLE;
            valid0 <= 0; valid1 <= 0;
            dirty0 <= 0; dirty1 <= 0;
            lru    <= 0;
        end else begin
            case (state)
                IDLE: if (cpu_req) begin
                    if (hit) begin
                        lru[index] <= ~hit_way;             // other way becomes LRU
                        if (cpu_we) begin                   // write hit
                            if (hit_way == 1'b0) begin
                                data0[index][word_sel*32 +: 32] <= cpu_wdata;
                                dirty0[index] <= 1'b1;
                            end else begin
                                data1[index][word_sel*32 +: 32] <= cpu_wdata;
                                dirty1[index] <= 1'b1;
                            end
                        end
                    end else begin                          // miss
                        state <= need_wb ? WB : ALLOC;
                    end
                end

                WB: if (mem_ready) state <= ALLOC;           // victim written back

                ALLOC: if (mem_ready) begin                  // block fetched
                    if (victim == 1'b0) begin
                        tag0[index]   <= tag;
                        data0[index]  <= fill_block;
                        valid0[index] <= 1'b1;
                        dirty0[index] <= cpu_we;             // dirty if write-allocate
                    end else begin
                        tag1[index]   <= tag;
                        data1[index]  <= fill_block;
                        valid1[index] <= 1'b1;
                        dirty1[index] <= cpu_we;
                    end
                    lru[index] <= ~victim;                   // filled way is MRU
                    state <= FIN;
                end

                FIN: state <= IDLE;
            endcase
        end
    end

    // ---- outputs (combinational) --------------------------------------------
    always @(*) begin
        cpu_ready        = 1'b0;
        mem_req          = 1'b0;
        mem_we           = 1'b0;
        mem_addr         = {`ADDR_WIDTH{1'b0}};
        mem_wdata        = {`BLOCK_BITS{1'b0}};
        read_hit         = 1'b0;
        read_miss        = 1'b0;
        write_hit        = 1'b0;
        write_miss       = 1'b0;
        writeback_strobe = 1'b0;
        cpu_rdata        = hit_block[word_sel*32 +: 32];

        case (state)
            IDLE: if (cpu_req && hit) begin
                cpu_ready = 1'b1;
                if (cpu_we) write_hit = 1'b1; else read_hit = 1'b1;
            end

            WB: begin
                mem_req   = ~mem_ready;                       // drop req once served
                mem_we    = 1'b1;
                mem_addr  = {victim_tag, index, {`OFFSET_BITS{1'b0}}};
                mem_wdata = vic_block;
                if (mem_ready) writeback_strobe = 1'b1;
            end

            ALLOC: begin
                mem_req  = ~mem_ready;
                mem_we   = 1'b0;
                mem_addr = {cpu_addr[`ADDR_WIDTH-1:`OFFSET_BITS], {`OFFSET_BITS{1'b0}}};
            end

            FIN: begin
                cpu_ready = 1'b1;
                cpu_rdata = vic_block[word_sel*32 +: 32];     // filled word
                if (cpu_we) write_miss = 1'b1; else read_miss = 1'b1;
            end
        endcase
    end
endmodule
