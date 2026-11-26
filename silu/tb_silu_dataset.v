`timescale 1ns / 1ps
//===========================================================================
// tb_silu_dataset.v
//   Drive the SiLU ROM with REAL vectors from the Qwen2.5-0.5B fixed-point
//   dataset (data/quantized/<layer>/<layer>_mlp_act_fn_SiLU_{in,out}).
//
//   Unlike tb_silu.v (which sweeps all 65536 codes), this one replays the
//   4864 activation values that the model actually produces at one layer,
//   so the result answers "does this ROM work on my data", not "is the LUT
//   monotone everywhere".
//
//   The *_hex.txt files produced by scripts/06c_quantize_export.py are
//   int16 two's complement, one 4-digit hex per line -- already $readmemh
//   format, no conversion needed.
//
//   Compile-time switches (override with -DNAME=value):
//     FRAC      fractional bits of the layer          (11 / 10 / 9)
//     NVEC      number of vectors                     (4864)
//     STIMFILE  input vectors   ("stimulus/xxx_in.hex")
//     GOLDFILE  expected output ("stimulus/xxx_out.hex")
//     LUTFILE   LUT loaded by the DUT ("silu_lut_q11.hex")
//     LOGFILE   text log        ("log/xxx.log")
//     HWOUT     hardware output dumped as hex ("log/xxx_hw.hex")
//===========================================================================
module tb_silu_dataset;

`ifndef FRAC
  `define FRAC 11
`endif
`ifndef NVEC
  `define NVEC 4864
`endif
`ifndef STIMFILE
  `define STIMFILE "stimulus/stim_L00_in.hex"
`endif
`ifndef GOLDFILE
  `define GOLDFILE "stimulus/stim_L00_out.hex"
`endif
`ifndef LUTFILE
  `define LUTFILE "silu_lut_q11.hex"
`endif
`ifndef LOGFILE
  `define LOGFILE "log/dataset.log"
`endif
`ifndef HWOUT
  `define HWOUT "log/dataset_hw.hex"
`endif
`ifndef TOL
  `define TOL 2
`endif

    localparam integer P_FRAC  = `FRAC;
    localparam integer P_N     = `NVEC;
    localparam integer P_BOUND = 8 << P_FRAC;
    localparam integer P_TOL   = `TOL;

    //---------------- DUT ----------------
    reg  signed [15:0] x;
    reg                clk;
    reg                rst_n;
    wire signed [15:0] y;

    silu #(.FRAC(P_FRAC), .LUT_FILE(`LUTFILE)) u_silu
        (.x(x), .clk(clk), .rst_n(rst_n), .y(y));

    //---------------- vectors ----------------
    reg [15:0] stim [0:P_N-1];
    reg [15:0] gold [0:P_N-1];

    //---------------- clock ----------------
    initial clk = 0;
    always #5 clk = ~clk;

    //---------------- bookkeeping ----------------
    integer fd_log, fd_hw;
    integer i, d, yv, gv;
    integer n_total, n_err, max_err, max_err_at;
    integer n_err_lut, n_err_satp, n_err_satn;
    integer n_satp, n_satn;
    integer shown;
    integer max_in, max_hw, max_exp;
    integer region;   // 0 = LUT, 1 = negative saturation, 2 = positive saturation

    initial begin
        n_total = 0; n_err = 0; max_err = 0; max_err_at = -1;
        n_err_lut = 0; n_err_satp = 0; n_err_satn = 0;
        n_satp = 0; n_satn = 0; shown = 0;

        $readmemh(`STIMFILE, stim);
        $readmemh(`GOLDFILE, gold);

        if (stim[0] === 16'hxxxx || gold[0] === 16'hxxxx) begin
            $display("[FATAL] vector file not loaded: %s / %s", `STIMFILE, `GOLDFILE);
            $finish;
        end

        fd_log = $fopen(`LOGFILE, "w");
        fd_hw  = $fopen(`HWOUT,   "w");
        if (fd_log == 0 || fd_hw == 0) begin
            $display("[FATAL] cannot open log/hw output");
            $finish;
        end

        $fwrite(fd_log, "=== SiLU ROM on real dataset ===\n");
        $fwrite(fd_log, "stimulus : %s\n", `STIMFILE);
        $fwrite(fd_log, "expected : %s\n", `GOLDFILE);
        $fwrite(fd_log, "lut      : %s\n", `LUTFILE);
        $fwrite(fd_log, "FRAC     : %0d   BOUND : +/-%0d   vectors : %0d   tol : %0d LSB\n\n",
                P_FRAC, P_BOUND, P_N, P_TOL);

        x = 0; rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk); #1;

        $display("=== SiLU ROM on real dataset (%0d vectors, FRAC=%0d) ===", P_N, P_FRAC);

        for (i = 0; i < P_N; i = i + 1) begin
            @(negedge clk);
            x = stim[i];
            @(posedge clk);
            #1;

            yv = $signed(y);
            gv = $signed(gold[i]);
            d  = yv - gv;
            if (d < 0) d = -d;

            // region of the *input*, mirroring the DUT's own comparison
            if ($signed(stim[i]) <= -P_BOUND) begin
                region = 1; n_satn = n_satn + 1;
            end else if ($signed(stim[i]) >= P_BOUND) begin
                region = 2; n_satp = n_satp + 1;
            end else begin
                region = 0;
            end

            n_total = n_total + 1;
            if (d > max_err) begin
                max_err = d; max_err_at = i;
                max_in = $signed(stim[i]); max_hw = yv; max_exp = gv;
            end

            if (d > P_TOL) begin
                n_err = n_err + 1;
                if (region == 0) n_err_lut  = n_err_lut  + 1;
                if (region == 1) n_err_satn = n_err_satn + 1;
                if (region == 2) n_err_satp = n_err_satp + 1;
                if (shown < 20) begin
                    shown = shown + 1;
                    $fwrite(fd_log, "MISMATCH idx=%0d in=%0d hw=%0d exp=%0d diff=%0d region=%0d\n",
                            i, $signed(stim[i]), yv, gv, d, region);
                end
            end

            $fwrite(fd_hw, "%04X\n", y);
        end

        $fwrite(fd_log, "\n=== SUMMARY ===\n");
        $fwrite(fd_log, "vectors          : %0d\n", n_total);
        $fwrite(fd_log, "mismatch (>%0d LSB): %0d\n", P_TOL, n_err);
        $fwrite(fd_log, "  in LUT region  : %0d\n", n_err_lut);
        $fwrite(fd_log, "  in neg sat     : %0d  (of %0d inputs)\n", n_err_satn, n_satn);
        $fwrite(fd_log, "  in pos sat     : %0d  (of %0d inputs)\n", n_err_satp, n_satp);
        $fwrite(fd_log, "max abs error    : %0d LSB @ idx=%0d\n", max_err, max_err_at);
        if (max_err_at >= 0)
            $fwrite(fd_log, "  at that point  : in=%0d hw=%0d exp=%0d\n",
                    max_in, max_hw, max_exp);
        $fwrite(fd_log, "verdict          : %s\n", (n_err == 0) ? "PASS" : "FAIL");

        $display(" total=%0d  mismatch=%0d  max_err=%0d @idx=%0d",
                 n_total, n_err, max_err, max_err_at);
        if (n_err == 0) $display("*** PASS ***");
        else            $display("*** FAIL ***");

        $fclose(fd_log);
        $fclose(fd_hw);
        $finish;
    end

endmodule
