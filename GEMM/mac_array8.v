module mac_array8 (
    input clk, rstn,
    input signed [15:0] act,
    input signed [127:0] wt,
    input valid,
    input last,
    output signed [255:0] sum,
    output done
);
    wire [7:0] done_reg ;
    genvar i;
    generate
        for (i=0; i<8; i=i+1) begin : mac_chain_gen
            mac_chain mac_chain_inst (
                .clk(clk),
                .rstn(rstn),
                .act(act),
                .wt(wt[i*16 +: 16]),
                .valid(valid),
                .last(last),
                .sum(sum[i*32 +: 32]),
                .done(done_reg[i])
            );
        end
    endgenerate
    assign done = &done_reg;
    endmodule