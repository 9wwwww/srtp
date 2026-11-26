# ===== 配置 =====
BUILD        := build
SRCS         := tb_silu.v silu.v
TOP          := tb_silu
HEX          := silu_lut_q11.hex
IVERILOG_OPT := -g2012 -Wall

# ===== 目标 =====
.PHONY: all sim wave clean

all: $(BUILD)/sim.out

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/sim.out: $(SRCS) | $(BUILD)
	iverilog $(IVERILOG_OPT) -s $(TOP) -o $@ $(SRCS)

# 仿真：先把 hex 拷进 build，再 cd build 运行，产物全在 build
sim: $(BUILD)/sim.out
	cp -f $(HEX) $(BUILD)/
	cd $(BUILD) && vvp sim.out

# 看波形
wave: sim
	gtkwave $(BUILD)/wave.vcd &

# 清理
clean:
	rm -rf $(BUILD)