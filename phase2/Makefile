# ============================================================================
# Phase 2 -- 2-way set-associative write-back cache
#   make model    reference-model self-test (no tools needed)
#   make sweep    parameter sweep -> reports/sweep_results.csv
#   make traces   regenerate read/write traces
#   make run      compile RTL + run testbench on all traces (needs iverilog)
#   make synth    synthesize the cache (needs yosys)
#   make clean    remove build artefacts
# ============================================================================
RTL    := rtl/main_memory_rw.v rtl/sa_cache.v rtl/sa_cache_top.v
TB     := sim/tb_sa_cache.v
OUT    := sim/sa.out
TRACES := conflict repeated sequential random

.PHONY: model sweep traces run synth clean

model:
	cd scripts && python3 cache_model.py --self-test

sweep:
	python3 scripts/sweep.py

traces:
	python3 scripts/gen_rw_traces.py -n 256

$(OUT): $(RTL) $(TB)
	iverilog -g2012 -I rtl -o $(OUT) $(RTL) $(TB)

run: $(OUT)
	@for t in $(TRACES); do vvp $(OUT) +TRACE=sim/traces/$$t.txt; echo; done

synth:
	yosys -s synth/synth.ys | tee reports/synth_report.txt

clean:
	rm -f $(OUT) sim/*.vcd
