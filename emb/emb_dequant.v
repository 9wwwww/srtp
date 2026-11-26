module emb_dequant #(
    parameter HIDDEN      = 2560,        // hidden_size，编译期常数（结构相关）
    parameter ROW_BW      = $clog2(HIDDEN/32),  // 80 拍扫描计数位宽
    parameter W           = 32,          // 每拍并行 lane 数
    parameter ADDR_W      = 30           // 词表 389MB → 29 bit，留 1 bit 余量
)(
    input clk,rst_n,
    input [31:0] token_id,
    input [31:0] emb_base,
    input [31:0] emb_mp_base,
    input start,
    input dma_ready,
    input bram_ready,
    input [W*8-1:0] bram_data,
    input  [15:0]    data_mE,


    output reg [ADDR_W-1:0] dma_addr,
    output reg [11:0] dma_len,
    output reg dma_valid,
    output  [ROW_BW-1:0] bram_addr,
    output [511:0] data_out,
    output reg [6:0] E,
    output out_valid,
    output reg done,
    output ready
  
);

localparam S_IDLE = 4'd0;
localparam S_DMA1 = 4'd1;
localparam S_DMA2 = 4'd2;
localparam S_R    = 4'd3;


wire [ADDR_W-1:0] addr;
wire [ADDR_W-1:0] addr_mp;
reg [31:0] id;
assign addr = emb_base+token_id*2560;
assign addr_mp = emb_mp_base+id*2;

reg [3:0] state,next_state;


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= 0;
    end else begin
        state <= next_state;
    end
end
reg [ROW_BW-1:0] cnt;

always @(*) begin // 状态转移逻辑
    next_state = state;
    case(state)
        S_IDLE: begin
            if(start) begin
                next_state = S_DMA1;
            end
        end
        S_DMA1: begin
            if(bram_ready && !dma_valid) begin
                next_state = S_DMA2;
            end
        end
        S_DMA2: begin
            if(bram_ready && !dma_valid) begin
                next_state = S_R;
            end
        end
        S_R: begin
            if(cnt == 79) begin
                next_state = S_IDLE;
            end
        end

    endcase
end


reg [8:0] m;

requant requant_inst(
    .data_in(bram_data),
    .m(m),
    .data_out(data_out)
);


always @(posedge clk or negedge rst_n) begin  // 状态时序逻辑
    if(!rst_n) begin
        dma_addr <= 0;
        dma_len <= 0;
        dma_valid <= 0;
    end else begin
        case(state)
            S_IDLE: begin
                if(start) begin
                    id <= token_id;
                    dma_addr <= addr;
                    dma_valid <= 1'b1;
                    dma_len <= HIDDEN;
                end
            end
            S_DMA1: begin
                if(dma_ready) begin
                    dma_valid <= 1'b0;
                end
                if(bram_ready && !dma_valid) begin
                    dma_addr <= addr_mp;
                    dma_valid <= 1'b1;
                    dma_len <= 2;
                end
            end
            S_DMA2: begin
                if(dma_ready) begin
                    dma_valid <= 1'b0;
                end
                if(bram_ready && !dma_valid) begin
                    m<=data_mE[15:7];
                    E<=data_mE[6:0];
                end
            end

        endcase
    end
end



always @(posedge clk or negedge rst_n) begin    // 扫描计数器
    if(!rst_n) begin
        cnt <= 0;
        done <= 1'b0;
    end else begin
        if(state == S_IDLE) begin
            done <= 1'b0;
        end
        else if(state == S_R) begin
            if(cnt == 79) begin
                cnt <= 0;
                done <= 1'b1;
            end 

            else begin
                cnt <= cnt + 1;
            end
        end
    end
end

assign bram_addr = cnt;
assign out_valid = (|cnt) | done;
assign ready = (state == S_IDLE);

endmodule