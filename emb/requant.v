module requant(
    input [255:0] data_in,
    input [8:0] m,
    output [511:0] data_out
);

genvar i;
generate
for(i=0;i<32;i=i+1) begin: requant_loop
    assign data_out[i*16+:16] = ($signed(data_in[i*8+:8]) * $signed({1'b0,m}));
end
endgenerate 


endmodule