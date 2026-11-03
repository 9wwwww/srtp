`timescale 1ns/1ns

module rmsnorm_2blk #(
    parameter DATA_W        = 16,
    parameter EXP_W         = 8,
    parameter LANES         = 32,
    parameter BLOCKS        = 28,
    parameter BLOCKS_PER_CYCLE = 2,

    parameter INPUT_FRAC    = 15,  //mantissa：Q0.15
    parameter FIXED_FRAC    = 10,  //转换后：Q11.10 / Q5.10
    parameter INV_FRAC      = 14,  //inv_rms：Q1.14

    parameter SUM_W         = 48,
    parameter LUT_ADDR_W    = 12
)(
    input  												 clk,
    input  												 rst_n,

    input                                 				 s_valid,
    output                            			    	 s_ready,
    input  signed [BLOCKS_PER_CYCLE*LANES*DATA_W-1:0]	 s_mant,
    input  signed [BLOCKS_PER_CYCLE*EXP_W-1:0] 			 s_exp,
    output                              			     m_valid,
    input                                 				 m_ready,
    output signed [BLOCKS_PER_CYCLE*LANES*DATA_W-1:0] 	 m_data,
    output                              			     m_last
);

reg input_done;         //输入完成标志
reg calc_done;          //归一化系数计算完成标志

reg [3:0] collect_cnt;  //输入计数器：0~13，标记当前是第几拍输入
reg [3:0] output_cnt;   //输出计数器：0~13，标记当前是第几拍输出
reg [47:0] sum_sq;		//累加平方和寄存器
reg [47:0] final_sum_sq;//最终平方和寄存器
reg [15:0] inv_rms;		//归一化系数寄存器
reg inv_rms_start;		//归一化计算开始信号
reg inv_rms_valid;		//归一化计算完成信号

// 输出端口寄存器
reg s_ready;
reg m_valid;
reg signed [BLOCKS_PER_CYCLE*LANES*DATA_W-1:0] m_data;
reg m_last;

always @(posedge clk,negedge rst_n)begin
	if(!rst_n)begin
		m_valid<=0;
        collect_cnt <= 4'd0;
        output_cnt <= 4'd0;
        sum_sq <= 48'd0;
        inv_rms_start <= 1'b0;
        input_done <= 1'b0;
        calc_done <= 1'b0;
        s_ready <= 1'b1;
        m_last <= 1'b0;
	end
	else begin
		if(s_valid&&s_ready)begin
			for(i=0;i<BLOCKS_PER_CYCLE*LANES*DATA_W;i=i+1)begin
				sum_sq=sum_sq+s_mant[i]*s_mant[i];
			end
		end
	end

end 

endmodule
