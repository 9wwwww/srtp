module absmax_32 #(
    parameter W=8,
    parameter N=32
)(
    input  wire [N*W-1:0] vec,        // 一组 N 个有符号数
    input  wire [W-1:0]   old_max,    // 历史 absmax（非负）
    output wire [W-1:0]   new_max     // 更新后的 absmax
);
wire [W-1:0] abs_vec [0:N-1];
genvar i;
generate
    for(i=0;i<N;i=i+1) begin:absmax_loop
        assign abs_vec[i] = vec[(i+1)*W-1]?(~vec[(i+1)*W-1:i*W]+1'b1):vec[(i+1)*W-1:i*W];
    end
endgenerate

wire [W-1:0] m1 [0:N/2-1];  
generate
    for(i=0;i<N/2;i=i+1) begin:absmax_loop2
        assign m1[i] = (abs_vec[2*i]>abs_vec[2*i+1])?abs_vec[2*i]:abs_vec[2*i+1];
    end
endgenerate

wire [W-1:0] m2 [0:N/4-1];  
generate
    for(i=0;i<N/4;i=i+1) begin:absmax_loop3
        assign m2[i] = (m1[2*i]>m1[2*i+1])?m1[2*i]:m1[2*i+1];
    end
endgenerate

wire [W-1:0] m3 [0:N/8-1];  
generate
    for(i=0;i<N/8;i=i+1) begin:absmax_loop4
        assign m3[i] = (m2[2*i]>m2[2*i+1])?m2[2*i]:m2[2*i+1];
    end
endgenerate

wire [W-1:0] m4 [0:N/16-1];  
generate    
    for(i=0;i<N/16;i=i+1) begin:absmax_loop5
        assign m4[i] = (m3[2*i]>m3[2*i+1])?m3[2*i]:m3[2*i+1];
    end
endgenerate

wire [W-1:0] max_val;
assign max_val = (m4[0]>m4[1])?m4[0]:m4[1];
assign new_max = (max_val>old_max)?max_val:old_max;

endmodule