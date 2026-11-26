`timescale 1ns/1ps
//============================================================
// tb_mac_array8.v -- 8 链对拍 testbench
// 前置: python gen_data8.py (三个 .txt 与本目录同放)
// 编译: iverilog -o sim mac_chain.v mac_array8.v tb_mac_array8.v
// 运行: vvp sim
// 判分: 逐 lane 自动比对, 外加 done 脉宽自检
//============================================================
module tb_mac_array8;

    parameter K = 128;               // tile 长度, 与 Python 的 N 一致
    parameter LANES = 8;             // 链数

    // ---------- 时钟 / 复位 ----------
    reg clk, rstn;
    initial clk = 0;
    always #5 clk = ~clk;            // 100MHz, 10ns 一拍

    // ---------- DUT 连线 ----------
    reg  signed [15:0]  act;
    reg         [127:0] wt_bus;      // 8 x 16bit 拍扁, lane g 占 [16*g +: 16]
    reg                 valid, last;
    wire signed [255:0] sum_bus;      // 8 x 32bit 拍扁, lane g 占 [32*g +: 32]
    wire                done;

    mac_array8 dut (
        .clk(clk), .rstn(rstn),
        .act(act), .wt(wt_bus),
        .valid(valid), .last(last),
        .sum(sum_bus), .done(done)
    );

    // ---------- 各 lane 的 32bit 结果切出来, 方便波形与判分 ----------
    wire signed [31:0] sum_lane [0:LANES-1];
    genvar gi;
    generate
        for (gi = 0; gi < LANES; gi = gi + 1) begin : unpack
            assign sum_lane[gi] = sum_bus[gi*32 +: 32];
        end
    endgenerate

    // ---------- 数据与黄金值 ----------
    reg signed [15:0] act_mem   [0:K-1];
    reg signed [15:0] wt_mem    [0:K*LANES-1];  // 扁平: 第 i 拍 lane g 在 i*8+g
    reg         [31:0] golden_mem [0:LANES-1];

    integer i, g, errors;

    initial begin
        $readmemh("act_data.txt", act_mem);
        $readmemh("wt_data.txt",  wt_mem);
        $readmemh("golden.txt",   golden_mem);
    end

    // ---------- 主激励 ----------
    initial begin
        rstn = 0; valid = 0; last = 0;
        act = 0; wt_bus = 0;
        errors = 0;
        repeat (3) @(posedge clk);
        rstn = 1;
        @(posedge clk);

        // 灌数据: 每拍 1 个 act + 8 个权重, 同步配对
        for (i = 0; i < K; i = i + 1) begin
            @(posedge clk);
            act    <= act_mem[i];
            for (g = 0; g < LANES; g = g + 1)
                wt_bus[16*g +: 16] <= wt_mem[i*LANES + g];
            valid  <= 1'b1;
            last   <= (i == K-1);
        end

        @(posedge clk);
        valid <= 0; last <= 0;

        // 等 8 条链同拍完成
        wait (done);
        #1;   // 等 NBA 落地再采样, 防读旧值

        // ---------- 逐 lane 判定 ----------
        $display("---- 对拍结果 (%0d lanes) ----", LANES);
        for (g = 0; g < LANES; g = g + 1) begin
            $display("lane%0d: golden=%0d(%0h)  RTL=%0d(%0h)",
                     g, $signed(golden_mem[g]), golden_mem[g],
                        sum_lane[g], sum_lane[g]);
            if (sum_lane[g] === $signed(golden_mem[g]))
                $display("lane%0d: PASS", g);
            else begin
                errors = errors + 1;
                $display("lane%0d: FAIL, 差值 = %0d",
                         g, sum_lane[g] - $signed(golden_mem[g]));
            end
        end

        // ---------- done 脉宽自检 (契约: 恰好 1 拍) ----------
        begin : done_width_check
            reg r;
            @(posedge clk);
            #1;
            r = done;
            if (r !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL: done 宽于 1 拍");
            end else
                $display("done 脉宽检查: OK (1 拍)");
        end

        // ---------- 总判定 ----------
        if (errors == 0) $display(">>> 8 链全部通过, 第 2 步收工 <<<");
        else             $display(">>> 共 %0d 处失败 <<<", errors);
        #50 $finish;
    end

    // ---------- 超时看门狗: 防呆等 done 等到天荒地老 ----------
    initial begin
        #100000;   // 最长 10 万 ns, 正常几十 us 内必完
        $display("FAIL: 超时, done 一直没来, 检查链路/valid/last");
        $finish;
    end

    // ---------- 波形 ----------
    initial begin
        $dumpfile("tb_mac_array8.vcd");
        $dumpvars(0, tb_mac_array8);
        $display("TB start: K=%0d, lanes=%0d", K, LANES);
    end

endmodule
