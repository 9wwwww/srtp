#!/usr/bin/env bash
# ============================================================================
# run_dataset.sh -- 用真实数据集一键复跑 SiLU 仿真
#
#   4 个用例：L00 / L07 / L12（Q4.11，q11 LUT）  +  L21（Q6.9，q9 LUT）
#   每个用例 4864 个真实激活值（该层 gate_proj 的输出）
#
#   注意：必须在 silu/ 目录下运行，因为 $readmemh 用的是相对路径。
#         脚本自己会 cd 到所在目录，直接 bash run_dataset.sh 就行。
# ============================================================================
set -e
cd "$(dirname "$0")"

mkdir -p build log

run_case() {
    local L=$1 F=$2 Q=$3
    echo "--- ${L}  (FRAC=${F}, ${Q} LUT) ---"
    iverilog -g2012 -DFRAC=${F} -DNVEC=4864 \
        -DSTIMFILE="\"stimulus/stim_${L}_in.hex\"" \
        -DGOLDFILE="\"stimulus/stim_${L}_out.hex\"" \
        -DLUTFILE="\"silu_lut_${Q}.hex\"" \
        -DLOGFILE="\"log/${L}.log\"" \
        -DHWOUT="\"log/${L}_hw.hex\"" \
        -s tb_silu_dataset -o "build/tb_${L}.out" \
        tb_silu_dataset.v silu.v
    vvp "build/tb_${L}.out" | grep -E "total=|PASS|FAIL"
}

run_case L00 11 q11
run_case L07 11 q11
run_case L12 11 q11
run_case L21 9  q9

echo ""
echo "--- 生成分析报告 ---"
CONDA_PY="C:/Users/Lenovo/.conda/envs/qwen_export/python.exe"
if [ -x "$CONDA_PY" ]; then
    "$CONDA_PY" analyze_dataset.py > /dev/null
elif python -c "import numpy" >/dev/null 2>&1; then
    python analyze_dataset.py > /dev/null
else
    echo "当前 python 没有 numpy，跳过分析。"
    echo "手动跑：C:/Users/Lenovo/.conda/envs/qwen_export/python.exe analyze_dataset.py"
    exit 0
fi
echo "报告已更新：log/仿真报告.txt"
