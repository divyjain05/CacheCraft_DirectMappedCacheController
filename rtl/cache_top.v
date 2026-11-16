// ============================================================================
// cache_top.v  --  Direct-Mapped Cache: datapath + controller + main memory
// ----------------------------------------------------------------------------
// CPU interface (read-only):
//   cpu_req  : pulse/hold high to request a read of `cpu_addr`
//   cpu_addr : 32-bit byte address
//   cpu_ready: 1-cycle strobe when `cpu_rdata` is valid
//   cpu_rdata: the requested 32-bit word
//   hit_strobe / miss_strobe : 1-cycle classification pulses (for statistics)
// ============================================================================
`include "cache_defs.vh"

module cache_top (
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   cpu_req,
    input  wire [`ADDR_WIDTH-1:0] cpu_addr,
    output wire                   cpu_ready,
    output wire [`WORD_WIDTH-1:0] cpu_rdata,
    output wire                   hit_strobe,
    output wire                   miss_strobe
);
    // ---- address split -------------------------------------------------------
    wire [`TAG_BITS-1:0]    tag;
    wire [`INDEX_BITS-1:0]  index;
    wire [`OFFSET_BITS-1:0] offset;
    wire [1:0]              word_sel;

    address_decoder u_decode (
        .addr(cpu_addr), .tag(tag), .index(index),
        .offset(offset), .word_sel(word_sel)
    );

    // ---- storage arrays ------------------------------------------------------
    wire                  cache_we;
    wire [`TAG_BITS-1:0]  rtag;
    wire                  valid;
    wire [`BLOCK_BITS-1:0] block_rdata;
    wire [`BLOCK_BITS-1:0] mem_block;

    cache_data_ram u_data (
        .clk(clk), .we(cache_we), .index(index),
        .wdata(mem_block), .rdata(block_rdata)
    );
    tag_ram u_tag (
        .clk(clk), .we(cache_we), .index(index),
        .wtag(tag), .rtag(rtag)
    );
    valid_ram u_valid (
        .clk(clk), .rst(rst), .we(cache_we), .index(index), .valid(valid)
    );

    // ---- hit detection -------------------------------------------------------
    wire hit;
    tag_comparator u_cmp (
        .tag_in(tag), .tag_stored(rtag), .valid(valid), .hit(hit)
    );

    // ---- main memory ---------------------------------------------------------
    wire mem_req, mem_ready;
    main_memory u_mem (
        .clk(clk), .rst(rst), .req(mem_req), .addr(cpu_addr),
        .ready(mem_ready), .rdata(mem_block)
    );

    // ---- controller FSM ------------------------------------------------------
    cache_controller u_ctrl (
        .clk(clk), .rst(rst), .cpu_req(cpu_req),
        .hit(hit), .mem_ready(mem_ready),
        .mem_req(mem_req), .cache_we(cache_we),
        .cpu_ready(cpu_ready),
        .hit_strobe(hit_strobe), .miss_strobe(miss_strobe)
    );

    // ---- word select out of the 128-bit block --------------------------------
    assign cpu_rdata = block_rdata[word_sel*`WORD_WIDTH +: `WORD_WIDTH];
endmodule
