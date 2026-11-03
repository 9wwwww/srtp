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
    input  												 	clk,
    input  												 	rst_n,

    input                                 				 	s_valid,
    output   reg                        		    	 	s_ready,
    input  		 signed [BLOCKS_PER_CYCLE*LANES*DATA_W-1:0]	s_mant,
    input  		 signed [BLOCKS_PER_CYCLE*EXP_W-1:0] 		s_exp,
    output   reg                           			     	m_valid,
    input                                 				 	m_ready,
    output   reg signed [BLOCKS_PER_CYCLE*LANES*DATA_W-1:0]	m_data,
    output   reg                           			     	m_last
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

reg [SUM_W-1:0] cycle_sum;  // 当前拍所有通道的平方和总和
reg signed [31:0] fixd_buf;

localparam signed [EXP_W:0] SHIFT_BASE = 5;
integer i;

always @(posedge clk,negedge rst_n)begin
	if(!rst_n)begin
		m_valid<=0;
        collect_cnt <=4'd0;
        output_cnt <=4'd0;
        sum_sq <=48'd0;
		final_sum_sq<=48'd0;
        inv_rms_start <=1'b0;
        input_done <=1'b0;
        calc_done <=1'b0;
        s_ready <=1'b1;
        m_last <=1'b0;
	end
	else begin
	
		if(s_valid&&s_ready)begin
		
			cycle_sum=0;
		
			for(i=0;i<LANES;i=i+1)begin
				fixd_buf=$signed(s_mant[(i+1)*DATA_W-1:i*DATA_W])>>>(SHIFT_BASE-s_exp[EXP_W-1:0]);
				cycle_sum=cycle_sum+fixd_buf*fixd_buf;
			end
			
			for(i=LANES;i<LANES*BLOCKS_PER_CYCLE;i=i+1)begin
				fixd_buf=$signed(s_mant[(i+1)*DATA_W-1:i*DATA_W])>>>(SHIFT_BASE-s_exp[EXP_W*BLOCKS_PER_CYCLE-1:EXP_W]);
				cycle_sum=cycle_sum+fixd_buf*fixd_buf;
			end
			
			sum_sq<=sum_sq+cycle_sum;
			
			if(collect_cnt==13)begin
				s_ready=0;
				input_done=1;
				collect_cnt=0;
				final_sum_sq<=sum_sq+cycle_sum;
			end
			
			collect_cnt=collect_cnt+1;
			
			
		end
		
		
			
		if(input_done&(!s_ready))begin
			inv_rms_start=1;
		end
		
	end

end 

endmodule
