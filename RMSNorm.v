`timescale 1ns/1ns

module rmsnorm_2blk #(
    
	//输入数据相关常量
	parameter DATA_W        	=16,
    parameter EXP_W         	=8,
    parameter LANES         	=32,
    parameter BLOCKS        	=28,
    parameter BLOCKS_PER_CYCLE	=2,

)(
    input  												 	clk,
    input  												 	rst_n,

	//输入数据
    input                                 				 	s_valid,//上游输入有效
    output   reg                        		    	 	s_ready,//可以接收数据
    input  		 signed [BLOCKS_PER_CYCLE*LANES*DATA_W-1:0]	s_mant,
    input  		 signed [BLOCKS_PER_CYCLE*EXP_W-1:0] 		s_exp,
	
	//输出数据
    output   reg                           			     	m_valid,//输出数据有效
    input                                 				 	m_ready,//下游可以接收数据
    output   reg signed [BLOCKS_PER_CYCLE*LANES*DATA_W-1:0]	m_data,
    output   reg                           			     	m_last
);

//内部常量定义
localparam STORE_W		=25;//储存输入数据真实值的位宽
localparam SUM_W        =48;//平方和位宽
localparam LUT_ADDR_W   =12;//

localparam SHIFT_BASE 	=5;	//计算使用的常量

//内部寄存器定义
//输入
reg [3:0] collect_cnt;  //输入计数器：0~13，标记当前是第几拍输入
reg [47:0] sum;			//累加平方和寄存器
reg [47:0] final_sum;	//最终平方和寄存器
reg input_done;         //输入完成标志

//储存
reg signed [STORE_W-1:0] fixd_value;                      //储存刚计算的真实值          
reg signed [STORE_W-1:0] fixd_buf [0:BLOCKS-1][0:LANES-1];//储存每一个真实值

//计算
reg calc_done;          //归一化系数计算完成标志
reg inv_rms_start;		//归一化计算开始信号
wire inv_rms_valid;		//归一化计算完成信号
wire [15:0] inv_rms;	//归一化系数

//输出
reg [3:0] output_cnt;   //输出计数器：0~13，标记当前是第几拍输出


//循环索引
integer i;
integer j=0;


always @(*)begin

			cycle_sum=0;
		
			for(i=0;i<LANES;i=i+1)begin
				fixd_value=$signed(s_mant[i*DATA_W+:DATA_W])>>>(SHIFT_BASE-$signed(s_exp[0+:EXP_W]));
				fixd_buf[j][i] = fixd_value;
				cycle_sum=cycle_sum+fixd_value*fixd_value;
			end
			
			
			for(i=0;i<LANES;i=i+1)begin
				fixd_value=$signed(s_mant[(i+31)*DATA_W+:DATA_W])>>>(SHIFT_BASE-$signed(s_exp[EXP_W+:EXP_W]));
				fixd_buf[j+1][i] = fixd_value;
				cycle_sum=cycle_sum+fixd_value*fixd_value;
			end
			
			 
			
	end
	
end


always @(posedge clk,negedge rst_n)begin
	if(!rst_n)begin
		j<=0;
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
			if(collect_cnt==13)begin
				j<=0;
				s_ready<=0;
				input_done<=1;
				collect_cnt<=0;
				final_sum<=sum_sq+cycle_sum;
				inv_rms_start<=1;
				sum<=48'd0;
			end
		
			else begin
				j=j+2;
				sum<=sum+cycle_sum;
				inv_rms_start<=0;
				collect_cnt=collect_cnt+1;
			end
		end	
			
		
		
		if(input_done && !calc_done) begin
			if(inv_rms_valid) begin
				calc_done <= 1'b1;
				output_cnt <= 4'd0;
			end
		end

		
		if(calc_done)begin
			m_valid=1;
		end
		
		if(m_ready&&m_valid)begin
		
		
		
			if((output_cnt==13)&&m_ready)begin
				m_valid=0;
				output_cnt=0;
				calc_done <= 1'b0;
				input_done <= 1'b0;
				s_ready <= 1'b1;

			end
			else begin
				output_cnt=output_cnt+1;
			end
		
		end
		 
	end

end 

endmodule
