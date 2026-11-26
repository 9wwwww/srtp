module mac_chain (
    input clk, rstn,
    input signed [15:0] act, wt,   
    input valid,
    input last,
    output signed [31:0] sum,
    output reg done
);

    reg signed [31:0] acc,result;
    always @(posedge clk) begin
        if (!rstn)      acc <= 0;
        else if (valid) begin
            if(last) acc <= 0;
            else   acc <= acc + act * wt;
        end
    end
  
    always @(posedge clk) begin
        if (!rstn)     begin
            done <= 0;
            result <= 0;
        end
        else if (last && valid)  begin
            result <= acc + act * wt; 
            done <= 1;
        end
        else   begin
            done <= 0;
        end
    end

    assign sum = result;

endmodule
