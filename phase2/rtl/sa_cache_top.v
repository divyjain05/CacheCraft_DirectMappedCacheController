// ============================================================================
// sa_cache_top.v  --  Phase 2 top-level: 2-way set-assoc cache + R/W memory
// ============================================================================
`include "cache_defs.vh"

module sa_cache_top (
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   cpu_req,
    input  wire                   cpu_we,
    input  wire [`ADDR_WIDTH-1:0] cpu_addr,
    input  wire [`WORD_WIDTH-1:0] cpu_wdata,
    output wire                   cpu_ready,
    output wire [`WORD_WIDTH-1:0] cpu_rdata,
    output wire                   read_hit,
    output wire                   read_miss,
    output wire                   write_hit,
    output wire                   write_miss,
    output wire                   writeback_strobe
);
    wire                    mem_req, mem_we, mem_ready;
    wire [`ADDR_WIDTH-1:0]  mem_addr;
    wire [`BLOCK_BITS-1:0]  mem_wdata, mem_rdata;

    sa_cache u_cache (
        .clk(clk), .rst(rst),
        .cpu_req(cpu_req), .cpu_we(cpu_we), .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata),
        .cpu_ready(cpu_ready), .cpu_rdata(cpu_rdata),
        .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_ready(mem_ready), .mem_rdata(mem_rdata),
        .read_hit(read_hit), .read_miss(read_miss),
        .write_hit(write_hit), .write_miss(write_miss),
        .writeback_strobe(writeback_strobe)
    );

    main_memory_rw u_mem (
        .clk(clk), .rst(rst),
        .req(mem_req), .we(mem_we), .addr(mem_addr), .wdata(mem_wdata),
        .ready(mem_ready), .rdata(mem_rdata)
    );
endmodule
