module frame_pipeline_top #(
    parameter  logic       FRAME_WIDTH             = 128,
    parameter  logic       FRAME_HIGHT             = 128,
    parameter  logic [3:0] MATRIX_COEF      [3][3] = {'{-1, -1, -1}, '{-1, 8, -1},  '{-1, -1, -1}},
    localparam             FRAME_WIDTH_BITS        = $clog2(FRAME_WIDTH),
    localparam             FRAME_HIGHT_BITS        = $clog2(FRAME_HIGHT)
)(
input  logic        clk_i,
input  logic        rstn_i,
input  logic        hs_i,
input  logic        vs_i,
input  logic [7: 0] red_i,
input  logic [7: 0] green_i,
input  logic [7: 0] blue_i,
input  logic [19:0] threshold_i,

output logic        hs_o,
output logic        vs_o,
output logic        y_o,
output logic        valid_o
);

logic [7:0] gray_1;

// =============== GRAY_CALC ===============
assign gray_1 = (red_i >> 2 + red_i >> 5) + (green_i >> 1 + green_i >> 4) + (blue_i >> 3 + blue_i >> 5);
// =============================================

// =============== WR_ADDR_LOGIC ===============

logic [3:0] wr_en;
logic [FRAME_WIDTH_BITS-1 :0] wr_addr_ff;
logic [FRAME_WIDTH_BITS-1 :0] wr_addr_next;

always_ff @(posedge clk_i or negedge rstn_i) begin
    if   (!rstn_i) wr_en <= 1;
    else if (vs_i) wr_en <= 1;
    else if (hs_i) wr_en <= {wr_en[0],wr_en[3:1]};
end

assign wr_addr_next = wr_addr_ff + 1;

always_ff @(posedge clk_i or negedge rstn_i) begin
    if   (!rstn_i) wr_addr_ff <= '0;
    if   (hs_i)      wr_addr_ff <= '0;
    else           wr_addr_ff <= wr_addr_next;
end

// =============================================

logic [3:0] 3_lines_filled;

always_ff @(posedge clk_i or negedge rstn_i) begin
    if   (!rstn_i) 3_lines_filled <= 4'd1;
    else if (vs_i) 3_lines_filled <= 4'd9;
    else if (hs_i) 3_lines_filled <= {1,3_lines_filled[3:1]};
end

// =============== RD_ADDR_LOGIC ===============

logic [3                  :0] rd_en;
logic [3                  :0] rd_en_masked;
logic [FRAME_WIDTH_BITS-1 :0] rd_addr_ff;
logic [FRAME_WIDTH_BITS-1 :0] rd_addr_next;

always_ff @(posedge clk_i or negedge rstn_i) begin
    if      (!rstn_i)                  rd_en <= 4'd7;
    else if (vs_i)                     rd_en <= 4'd7;
    else if (hs_i & 3_lines_filled[3]) rd_en <= {rd_en[0],rd_en[3:1]};
end

assign rd_en_masked = rd_en & 3_lines_filled[3];

assign rd_addr_next = rd_addr_ff + 3_lines_filled[3];

always_ff @(posedge clk_i or negedge rstn_i) begin
    if   (!rstn_i) rd_addr_ff <= '0;
    if   (hs_i)      rd_addr_ff <= '0;
    else           rd_addr_ff <= rd_addr_next;
end

// =============================================

// =============== MEM_INSTANCE ===============

// =============================================

// =============== MATRIX_MULT ===============

logic [7:0] mem_data [3:0]; 
logic [7:0] row_data [2:0]; 
logic [7:0] shift_reg_0 [2:0]; 
logic [7:0] shift_reg_1 [2:0]; 
logic [7:0] shift_reg_2 [2:0]; 

always_comb begin
    case(rd_en)
    4'b1110: begin
        row_data[0] = mem_data[0];
        row_data[1] = mem_data[1];
        row_data[2] = mem_data[2];
    end
    4'b0111: begin
        row_data[0] = mem_data[1];
        row_data[1] = mem_data[2];
        row_data[2] = mem_data[3];
    end
    4'b1011: begin
        row_data[0] = mem_data[2]; 
        row_data[1] = mem_data[3]; 
        row_data[2] = mem_data[0]; 
    end
    4'b1101: begin
        row_data[0] = mem_data[3];
        row_data[1] = mem_data[0];
        row_data[2] = mem_data[1];
    end
    default: begin
        row_data[0] = mem_data[0];
        row_data[1] = mem_data[1];
        row_data[2] = mem_data[2];
    end
    endcase
end

always_ff @(posedge clk_i or negedge rstn_i) 
    if (hs_i) shift_reg_0 <= {shift_reg_0[2:1], row_data[0]};

always_ff @(posedge clk_i or negedge rstn_i) 
    if (hs_i) shift_reg_1 <= {shift_reg_1[2:1], row_data[1]};

always_ff @(posedge clk_i or negedge rstn_i) 
    if (hs_i) shift_reg_2 <= {shift_reg_2[2:1], row_data[2]};

logic [11:0] row_0_mult [2:0];
logic [11:0] row_1_mult [2:0];
logic [11:0] row_2_mult [2:0];

logic [13:0] row_sum    [2:0];
logic [15:0] total_sum;

always_comb begin
    for(int i=0; i<3 ; i++) begin
        row_0_mult[i] = shift_reg_0[i] * MATRIX_COEF[0][i];
        row_1_mult[i] = shift_reg_1[i] * MATRIX_COEF[1][i];
        row_2_mult[i] = shift_reg_2[i] * MATRIX_COEF[2][i];
    end
end

assign row_sum[0] = row_0_mult[0] + row_0_mult[1] + row_0_mult[2];
assign row_sum[1] = row_1_mult[0] + row_1_mult[1] + row_1_mult[2];
assign row_sum[2] = row_2_mult[0] + row_2_mult[1] + row_2_mult[2];

assign total_sum = row_sum[0] + row_sum[1] + row_sum[2];
// =============================================

// =============== SYNC_LOGIC ===============

logic [3:0] valid_shift_reg;
logic [7:0] hs_cnt_ff;
logic [7:0] hs_cnt_next;
logic [7:0] vs_cnt_ff;
logic [7:0] vs_cnt_next;

always_ff @(posedge clk_i or negedge rstn_i) begin
    if      (!rstn_i)           valid_shift_reg <= 1;
    else if (hs_i)              valid_shift_reg <= 1;
    else if (3_lines_filled[3]) valid_shift_reg <= {valid_shift_reg[3:1], 1'b1};
end

assign hs_cnt_next = hs_cnt_ff + valid_shift_reg[3];

always_ff @(posedge clk_i or negedge rstn_i) begin
    if      (!rstn_i) hs_cnt_ff <= '0;
    else if (hs_o)    hs_cnt_ff <= '0;
    else              hs_cnt_ff <= hs_cnt_next;
end

assign vs_cnt_next = vs_cnt_ff + hs_o;

always_ff @(posedge clk_i or negedge rstn_i) begin
    if      (!rstn_i) vs_cnt_ff <= '0;
    else if (vs_o)    vs_cnt_ff <= '0;
    else              vs_cnt_ff <= vs_cnt_next;
end


assign hs_o    = hs_cnt_ff == 253;
assign vs_o    = vs_cnt_next == 253;
assign valid_o = valid_shift_reg[3];
assign y_o     = (valid_shift_reg[3] & total_sum) > threshold_i;
// =============================================

endmodule