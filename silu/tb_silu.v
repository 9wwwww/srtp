`timescale 1ns / 1ps
//===========================================================================
// tb_silu.v  —  SiLU ROM 验证：mismatch 线 + 日志 + 分区容差
//===========================================================================
module tb_silu;

    //----------- DUT 接口 -----------
    reg  signed [15:0] x;
    reg                clk;
    reg                rst_n;
    wire signed [15:0] y;

    silu u_silu (.x(x), .clk(clk), .rst_n(rst_n), .y(y));

    //----------- 参数（必须与 DUT 一致）-----------
    localparam integer FRAC  = 11;
    localparam integer BOUND = 8 << FRAC;      // 16384
    localparam real    SCALE = 2048.0;
    localparam integer STEP  = 1;              // 1=全扫 65536 点，改 100 快跑

    //----------- 时钟 -----------
    initial clk = 0;
    always #5 clk = ~clk;    // 10ns 周期

    //----------- 参考模型：real SiLU → Q4.11 -----------
    function integer silu_ref;
        input integer xi;
        real xr, yr, scaled;
        begin
            xr     = xi / SCALE;
            yr     = xr / (1.0 + $exp(-xr));
            scaled = yr * SCALE;
            if (scaled >= 0.0)
                silu_ref = $rtoi($floor(scaled + 0.5));
            else
                silu_ref = $rtoi($ceil (scaled - 0.5));
        end
    endfunction

    // 期望值：组合信号，跟着 x 实时变
    wire signed [15:0] y_exp = silu_ref(x);

    //----------- 分区 + 容差 -----------
    //   region: 0 = ROM 区, 1 = 负饱和, 2 = 正饱和
    wire [1:0] region = (x <= -BOUND) ? 2'd1 :
                        (x >=  BOUND) ? 2'd2 : 2'd0;

    reg [3:0] tol;
    always @(*) begin
        case (region)
            2'd0: tol = 1;   // ROM 区：量化误差 0~1 LSB
            2'd1: tol = 7;   // 负饱和：|SiLU(x)| ≤ 5.5 LSB
            2'd2: tol = 7;   // 正饱和：|x - SiLU(x)| ≤ 5.5 LSB
            default: tol = 1;
        endcase
    end

    //----------- mismatch 信号（波形里直接看这根）-----------
    wire signed [16:0] diff     = {y[15], y} - {y_exp[15], y_exp};
    wire        [16:0] abs_diff = diff[16] ? -diff : diff;
    wire               mismatch = (abs_diff > tol);   // 1 = 这一拍超出容差

    //----------- 统计 + 日志 -----------
    integer err_cnt, total, max_err, max_err_at;
    integer log_fd;

    //----------- 波形（用 `-DDUMP` 才生成）-----------
`ifdef DUMP
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_silu);
    end
`endif

    //----------- 主流程 -----------
    initial begin
        x = 0; rst_n = 0;
        err_cnt = 0; total = 0; max_err = 0; max_err_at = 0;

        log_fd = $fopen("sim.log", "w");
        if (log_fd == 0) begin
            $display("[FATAL] cannot open sim.log");
            $finish;
        end

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk); #1;

        $display("=== SiLU ROM test start ===");
        $fwrite(log_fd, "=== SiLU ROM test ===\n");

        // 扫描全部 16-bit 输入
        begin : scan
            integer i, yi, ye, d;
            for (i = -32768; i <= 32767; i = i + STEP) begin
                @(negedge clk);
                x = i;               // 驱动新 x
                @(posedge clk);
                #1;                  // 等 NBA，y 更新完毕

                // 此刻：y = f(i)，y_exp = f(i)，对齐！
                yi = y;
                ye = silu_ref(i);
                d  = yi - ye;  if (d < 0) d = -d;

                total = total + 1;
                if (d > max_err) begin
                    max_err = d;
                    max_err_at = i;
                end

                if (abs_diff > tol) begin
                    err_cnt = err_cnt + 1;
                    $display("[MISMATCH] x=%0d (%f) hw=%0d exp=%0d diff=%0d tol=%0d region=%0d",
                             i, i/SCALE, yi, ye, abs_diff, tol, region);
                    $fwrite(log_fd, "MISMATCH x=%0d hw=%0d exp=%0d diff=%0d region=%0d\n",
                            i, yi, ye, abs_diff, region);
                end
            end
        end

        $display("=== SUMMARY ===");
        $display(" total    : %0d", total);
        $display(" mismatch : %0d", err_cnt);
        $display(" max_err  : %0d LSB @ x=%0d", max_err, max_err_at);
        $fwrite(log_fd, "=== SUMMARY ===\ntotal=%0d mismatch=%0d max_err=%0d @x=%0d\n",
                total, err_cnt, max_err, max_err_at);

        if (err_cnt == 0) $display("*** PASS ***");
        else              $display("*** FAIL ***");

        $fclose(log_fd);
        $finish;
    end

endmodule