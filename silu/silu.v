
module silu( 
           input signed [15:0]x,
           input clk,
           input rst_n,
           output reg signed [15:0]y
            );
parameter FRAC = 11;

parameter LUT_FILE = "silu_lut_q11.hex";
parameter signed BOUND = 8<<FRAC;
parameter DEPTH = 2*BOUND;
wire sat_pos,sat_neg;
assign sat_pos = (x >= BOUND);
assign sat_neg = (x <= -BOUND); 
reg [15:0] rom [0:DEPTH-1];
initial $readmemh(LUT_FILE, rom);
wire signed [16:0] addr_full = {x[15], x} + BOUND;
wire        [14:0] addr      = addr_full[14:0];
always@(posedge clk,negedge rst_n)
begin
    if(!rst_n)
    y<=16'd0;
    else if(sat_neg==1)
    y<=16'd0;
    else if(sat_pos==1)
    y<=x;
    else
    y<=rom[addr];
end

endmodule


