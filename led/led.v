module flow_led(
    input clk_p,
    input clk_n,
    input rst_n,
    output reg [1:0] led
);
wire clk;
IBUFDS IBUFDS_inst(
    .O(clk),
    .I(clk_p),
    .IB(clk_n)
);
reg cnt[25:0];
 always @(posedge sys_clk or negedge sys_rst_n) begin 
     if(!sys_rst_n) 
         cnt <= 26'd0; 
     else if(cnt < (26'd5000_0000 - 26'd1)) 
         cnt <= cnt + 26'd1; 
     else 
         cnt <= 26'd0; 
 end 
  
 //对LED灯进行移位控制，以输出2位LED的状态 
 always @(posedge sys_clk or negedge sys_rst_n) begin 
     if(!sys_rst_n) 
         led <= 2'b01; 
     else if(cnt == (26'd5000_0000 - 26'd1)) 
         led <= {led[0],led[1]}; 
     else 
         led <= led; 
 end 


endmodule