// ============================================================================
// tb_cache_top.v  --  trace-driven testbench for the direct-mapped cache
// ----------------------------------------------------------------------------
// Reads a text file of hex byte-addresses (one per line), issues each as a
// CPU read, waits for cpu_ready, counts hits/misses and cycles, then prints a
// hit/miss report and the measured + analytic AMAT.
//
// Run (with Icarus Verilog):
//   iverilog -g2012 -I rtl -o sim/cache.out rtl/*.v sim/tb_cache_top.v
//   vvp sim/cache.out +TRACE=sim/traces/sequential.txt
//
// AMAT = hit_time + miss_rate * miss_penalty
//        hit_time     = 1 cycle
//        miss_penalty = MEM_LATENCY cycles
// ============================================================================
`include "cache_defs.vh"
`timescale 1ns/1ps

module tb_cache_top;
    reg                    clk = 0;
    reg                    rst;
    reg                    cpu_req;
    reg  [`ADDR_WIDTH-1:0] cpu_addr;
    wire                   cpu_ready;
    wire [`WORD_WIDTH-1:0] cpu_rdata;
    wire                   hit_strobe, miss_strobe;

    // statistics
    integer hits   = 0;
    integer misses = 0;
    integer accesses = 0;
    integer total_cycles = 0;  // hit=1 cycle, miss=1+MEM_LATENCY cycles

    // trace file handling
    integer fd, code;
    reg [`ADDR_WIDTH-1:0] addr;
    reg [1023:0] trace_path;

    // 100 MHz clock
    always #5 clk = ~clk;

    cache_top dut (
        .clk(clk), .rst(rst), .cpu_req(cpu_req), .cpu_addr(cpu_addr),
        .cpu_ready(cpu_ready), .cpu_rdata(cpu_rdata),
        .hit_strobe(hit_strobe), .miss_strobe(miss_strobe)
    );

    // live classification count (strobes are 1-cycle)
    always @(posedge clk) begin
        if (hit_strobe)  begin hits   = hits   + 1; total_cycles = total_cycles + 1; end
        if (miss_strobe) begin misses = misses + 1; total_cycles = total_cycles + 1 + `MEM_LATENCY; end
    end

    // ---- issue one read and wait for completion, counting cycles ------------
    task do_read(input [`ADDR_WIDTH-1:0] a);
        begin
            @(negedge clk);
            cpu_addr = a;
            cpu_req  = 1'b1;
            // wait for the response strobe (hit = same cycle, miss after refill)
            while (cpu_ready !== 1'b1) @(posedge clk);
            @(negedge clk);
            cpu_req = 1'b0;     // drop request so the FSM returns to IDLE
            accesses = accesses + 1;
        end
    endtask

    real hit_rate, miss_rate, amat_analytic, amat_measured;

    initial begin
        // optional VCD dump: vvp sim/cache.out +TRACE=... +DUMP
        if ($test$plusargs("DUMP")) begin
            $dumpfile("sim/cache.vcd");
            $dumpvars(0, tb_cache_top);
        end

        cpu_req  = 0;
        cpu_addr = 0;
        rst      = 1;
        repeat (3) @(posedge clk);
        rst = 0;
        @(negedge clk);

        if (!$value$plusargs("TRACE=%s", trace_path)) begin
            $display("ERROR: supply +TRACE=<file>");
            $finish;
        end
        fd = $fopen(trace_path, "r");
        if (fd == 0) begin
            $display("ERROR: cannot open trace %0s", trace_path);
            $finish;
        end

        // consume address lines until EOF
        code = $fscanf(fd, "%h\n", addr);
        while (code == 1) begin
            do_read(addr);
            code = $fscanf(fd, "%h\n", addr);
        end
        $fclose(fd);

        // ---- report ---------------------------------------------------------
        hit_rate      = (accesses == 0) ? 0.0 : (100.0 * hits)   / accesses;
        miss_rate     = (accesses == 0) ? 0.0 : (100.0 * misses) / accesses;
        amat_analytic = 1.0 + (misses * 1.0 / (accesses==0?1:accesses)) * `MEM_LATENCY;
        amat_measured = (accesses == 0) ? 0.0 : (total_cycles * 1.0) / accesses;

        $display("=====================================================");
        $display(" Direct-Mapped Cache  --  Hit/Miss Report");
        $display("   trace        : %0s", trace_path);
        $display("   config       : %0d B cache, %0d B blocks, %0d lines",
                 `CACHE_SIZE, `BLOCK_SIZE, `NUM_LINES);
        $display("   miss penalty : %0d cycles", `MEM_LATENCY);
        $display("-----------------------------------------------------");
        $display("   accesses     : %0d", accesses);
        $display("   hits         : %0d", hits);
        $display("   misses       : %0d", misses);
        $display("   hit  ratio   : %0.2f %%", hit_rate);
        $display("   miss ratio   : %0.2f %%", miss_rate);
        $display("-----------------------------------------------------");
        $display("   AMAT (model) : %0.3f cycles  [1 + miss_rate*%0d]", amat_analytic, `MEM_LATENCY);
        $display("   AMAT (meas.) : %0.3f cycles  [total_cycles/accesses]", amat_measured);
        $display("=====================================================");

        $finish;
    end

    // safety timeout
    initial begin
        #2000000;
        $display("ERROR: simulation timeout");
        $finish;
    end
endmodule
