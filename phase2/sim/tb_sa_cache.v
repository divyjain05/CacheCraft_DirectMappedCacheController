// ============================================================================
// tb_sa_cache.v  --  trace-driven testbench for the 2-way write-back cache
// ----------------------------------------------------------------------------
// Trace lines: "R <hex>" or "W <hex>". Writes use a deterministic data value
// (address itself) so write/read-back can be spot-checked. Counts read/write
// hits and misses and writebacks, then prints the report and AMAT.
//
//   iverilog -g2012 -I rtl -o sim/sa.out rtl/*.v sim/tb_sa_cache.v
//   vvp sim/sa.out +TRACE=sim/traces/conflict.txt
// ============================================================================
`include "cache_defs.vh"
`timescale 1ns/1ps

module tb_sa_cache;
    reg                    clk = 0, rst;
    reg                    cpu_req, cpu_we;
    reg  [`ADDR_WIDTH-1:0] cpu_addr;
    reg  [`WORD_WIDTH-1:0] cpu_wdata;
    wire                   cpu_ready;
    wire [`WORD_WIDTH-1:0] cpu_rdata;
    wire read_hit, read_miss, write_hit, write_miss, writeback_strobe;

    integer rh=0, rm=0, wh=0, wm=0, wb=0, accesses=0, total_cycles=0;

    integer fd, code;
    reg [`ADDR_WIDTH-1:0] addr;
    reg [7:0] opc;
    reg [1023:0] trace_path;

    always #5 clk = ~clk;

    sa_cache_top dut (
        .clk(clk), .rst(rst),
        .cpu_req(cpu_req), .cpu_we(cpu_we), .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata),
        .cpu_ready(cpu_ready), .cpu_rdata(cpu_rdata),
        .read_hit(read_hit), .read_miss(read_miss),
        .write_hit(write_hit), .write_miss(write_miss),
        .writeback_strobe(writeback_strobe)
    );

    always @(posedge clk) begin
        if (read_hit)         begin rh = rh + 1; total_cycles = total_cycles + 1; end
        if (write_hit)        begin wh = wh + 1; total_cycles = total_cycles + 1; end
        if (read_miss)        begin rm = rm + 1; total_cycles = total_cycles + 1 + `MEM_LATENCY; end
        if (write_miss)       begin wm = wm + 1; total_cycles = total_cycles + 1 + `MEM_LATENCY; end
        if (writeback_strobe) begin wb = wb + 1; total_cycles = total_cycles + `MEM_LATENCY; end
    end

    task do_access(input is_write, input [`ADDR_WIDTH-1:0] a);
        begin
            @(negedge clk);
            cpu_addr  = a;
            cpu_we    = is_write;
            cpu_wdata = a;              // deterministic write payload
            cpu_req   = 1'b1;
            while (cpu_ready !== 1'b1) @(posedge clk);
            @(negedge clk);
            cpu_req = 1'b0;
            accesses = accesses + 1;
        end
    endtask

    real hit_rate, amat_eff, amat_model, miss_rate;

    initial begin
        cpu_req=0; cpu_we=0; cpu_addr=0; cpu_wdata=0;
        rst=1; repeat(3) @(posedge clk); rst=0; @(negedge clk);

        if (!$value$plusargs("TRACE=%s", trace_path)) begin
            $display("ERROR: supply +TRACE=<file>"); $finish;
        end
        fd = $fopen(trace_path, "r");
        if (fd == 0) begin $display("ERROR: cannot open %0s", trace_path); $finish; end

        code = $fscanf(fd, "%c %h\n", opc, addr);
        while (code == 2) begin
            do_access((opc == "W" || opc == "w"), addr);
            code = $fscanf(fd, "%c %h\n", opc, addr);
        end
        $fclose(fd);

        hit_rate   = (accesses==0) ? 0.0 : 100.0*(rh+wh)/accesses;
        miss_rate  = (accesses==0) ? 0.0 : (rm+wm)*1.0/accesses;
        amat_model = 1.0 + miss_rate*`MEM_LATENCY;              // matches cache_model.py
        amat_eff   = (accesses==0) ? 0.0 : (total_cycles*1.0)/accesses; // incl. writeback stalls

        $display("=====================================================");
        $display(" 2-Way Set-Associative Write-Back Cache  --  Report");
        $display("   trace     : %0s", trace_path);
        $display("   config    : %0dB, %0dB blocks, %0d-way, %0d sets",
                 `CACHE_SIZE, `BLOCK_SIZE, `ASSOC, `NUM_SETS);
        $display("-----------------------------------------------------");
        $display("   accesses  : %0d", accesses);
        $display("   read  h/m : %0d / %0d", rh, rm);
        $display("   write h/m : %0d / %0d", wh, wm);
        $display("   writebacks: %0d", wb);
        $display("   hit ratio : %0.2f %%", hit_rate);
        $display("   AMAT model: %0.3f cycles  [1 + miss_rate*%0d]", amat_model, `MEM_LATENCY);
        $display("   AMAT eff. : %0.3f cycles  [incl. writeback stalls]", amat_eff);
        $display("=====================================================");
        $finish;
    end

    initial begin #5000000; $display("ERROR: timeout"); $finish; end
endmodule
