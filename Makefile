# ============================================================================
# Direct-Mapped Cache Controller -- build & simulation
# ----------------------------------------------------------------------------
#   make traces     regenerate the memory-access traces
#   make sim        compile the Verilog (needs Icarus Verilog: `iverilog`)
#   make run        run the RTL testbench on all three traces
#   make pysim      run the Python reference model (no tools needed)
#   make check      run the reference-model self-test
#   make clean      remove build artefacts
# ============================================================================
RTL      := rtl/address_decoder.v rtl/tag_comparator.v rtl/cache_data_ram.v \
            rtl/tag_ram.v rtl/valid_ram.v rtl/main_memory.v \
            rtl/cache_controller.v rtl/cache_top.v
TB       := sim/tb_cache_top.v
OUT      := sim/cache.out
TRACES   := sim/traces/sequential.txt sim/traces/repeated.txt sim/traces/random.txt

.PHONY: all traces sim run pysim check clean

all: sim run

traces:
	python3 scripts/gen_traces.py -n 256

sim: $(OUT)

$(OUT): $(RTL) $(TB)
	iverilog -g2012 -I rtl -o $(OUT) $(RTL) $(TB)

run: sim
	@for t in $(TRACES); do \
		echo "### RTL simulation: $$t"; \
		vvp $(OUT) +TRACE=$$t; \
	done

pysim:
	python3 scripts/cache_sim.py $(TRACES)

check:
	python3 scripts/cache_sim.py --self-test

clean:
	rm -f $(OUT) sim/cache.vcd
