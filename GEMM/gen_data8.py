# gen_data8.py
# 生成 8 链对拍数据: act_data.txt / wt_data.txt / golden.txt
# 数据流约定(与 RTL/TB 严格一致):
#   - K = 128: 每条链累加 128 拍
#   - 每拍 1 个 act 广播, 与 8 个权重(wt[i][0..7])分别配对相乘
#   - wt_data.txt 按拍拍扁: 第 i 拍的 8 个权重连续 8 行, 即 wt_mem[i*8 + g]
#   - lane g 的点积 = sum(act[i] * wt[i][g]) for i in 0..127
#   - 文件格式: 16bit 用 4 位十六进制补码, 32bit 用 8 位十六进制补码 (readmemh 可直接读)

import random

K     = 128    # 累加长度(tile 深度)
LANES = 8      # 链数 = 权重矩阵列数
SEED  = 0      # 换种子即换一组数据

def s16(v):    # 有符号 16bit -> 4 位 hex 补码
    return format(v & 0xFFFF, '04x')

def s32(v):    # 有符号 32bit -> 8 位 hex 补码
    return format(v & 0xFFFFFFFF, '08x')

random.seed(SEED)

# ---------- 生成 ----------
act = [random.randint(-32768, 32767) for _ in range(K)]          # act[i]
wt  = [[random.randint(-32768, 32767) for _ in range(LANES)]     # wt[i][g]
       for _ in range(K)]

# golden: lane g 的点积, 用 64bit 中间量防止 Python 大整数干扰, 最后按 32bit 补码截断
golden = []
for g in range(LANES):
    acc = 0
    for i in range(K):
        acc += act[i] * wt[i][g]
    golden.append(acc)

# ---------- 写文件 ----------
with open("act_data.txt", "w") as f:
    for v in act:
        f.write(s16(v) + "\n")

with open("wt_data.txt", "w") as f:
    for i in range(K):
        for g in range(LANES):          # 第 i 拍的 8 个权重连排 -> TB 的 i*8+g
            f.write(s16(wt[i][g]) + "\n")

with open("golden.txt", "w") as f:
    for v in golden:
        f.write(s32(v) + "\n")

# ---------- 自检打印 ----------
print(f"K={K}, LANES={LANES}, 共生成 {K*LANES} 个权重")
for g in range(LANES):
    print(f"lane{g} golden = {golden[g]}  (0x{s32(golden[g])})")

# 溢出预警: 8 链 32bit acc 理论上限 |sum| < 2^15 * 2^15 * 128 = 2^36, 但随机数据下
# 实际远达不到; 若未来改大数据分布, 注意 32bit acc 会溢出, golden 与 RTL 要同步扩位
