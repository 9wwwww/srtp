import numpy as np

def gen_silu_lut(frac, path, sat_pos=None, sat_neg=None):
    """
    addr = x + BOUND,  x ∈ [-8, 8)  →  addr ∈ [0, 2*BOUND)
    饱和区（x ≥ 8 或 x ≤ -8）由硬件直接输出 sat_pos / sat_neg，
    ROM 不覆盖该区间。
    """
    bound = 8 << frac          # 8.0 的 Q(frac) 表示
    depth = 2 * bound          # 只覆盖 x ∈ [-8, 8) 的地址范围

    i = np.arange(depth, dtype=np.int64)
    x_int  = i - bound
    x_real = x_int / (1 << frac)

    # SiLU
    y_real  = x_real / (1.0 + np.exp(-x_real))

    # 标准四舍五入（远离零），比 np.round 更直观
    scaled = y_real * (1 << frac)
    y_fixed = np.where(scaled >= 0,
                       np.floor(scaled + 0.5),
                       np.ceil (scaled - 0.5)).astype(np.int64)

    # int16 防御性钳位（SiLU 在 [-8, 8) 上其实不会溢出，留着保险）
    y_fixed = np.clip(y_fixed, -32768, 32767)
    bit_pattern = y_fixed & 0xFFFF

    with open(path, "w", newline="\n") as fp:
        for v in bit_pattern:
            fp.write(f"{v:04X}\n")

    # 打印边界值，方便你写硬件侧的饱和常量
    print(f"[frac={frac}] depth={depth}, bound={bound}")
    print(f"  SiLU(-8) Q{frac} = {y_fixed[0]:>6d} (0x{y_fixed[0] & 0xFFFF:04X})")
    print(f"  SiLU(+8-) Q{frac} = {y_fixed[-1]:>6d} (0x{y_fixed[-1] & 0xFFFF:04X})")
    print(f"  addr=bound(i={bound}) → {y_fixed[bound]}  # 应为 0 (x=0)")

for f in (11, 10, 9):
    gen_silu_lut(f, f"silu_lut_q{f}.hex")