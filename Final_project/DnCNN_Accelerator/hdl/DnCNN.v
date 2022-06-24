module DnCNN (
    input wire clk,
    input wire rst_n,

    input wire compute_start,
    output reg compute_finish,

    // Quantization scale
    input wire [31:0] scale_C1,
    input wire [31:0] scale_C2,
    input wire [31:0] scale_C3,
    input wire [31:0] scale_C4,
    input wire [31:0] scale_C5,
    input wire [31:0] scale_C6,
    input wire [31:0] scale_C7,

    // Weight sram, dual port
    output reg [ 3:0] sram_weight_wea0,
    output reg [15:0] sram_weight_addr0,
    output reg [31:0] sram_weight_wdata0,
    input wire [31:0] sram_weight_rdata0,
    output reg [ 3:0] sram_weight_wea1,
    output reg [15:0] sram_weight_addr1,
    output reg [31:0] sram_weight_wdata1,
    input wire [31:0] sram_weight_rdata1,

    // Activation sram, dual port
    output reg [ 3:0] sram_act_wea0,
    output reg [15:0] sram_act_addr0,
    output reg [31:0] sram_act_wdata0,
    input wire [31:0] sram_act_rdata0,
    output reg [ 3:0] sram_act_wea1,
    output reg [15:0] sram_act_addr1,
    output reg [31:0] sram_act_wdata1,
    input wire [31:0] sram_act_rdata1
);
    // Add your design here

integer i;

// DnCNN FSM
localparam IDLE = 3'd0, READ = 3'd1, CALCULATE = 3'd2, QUANTIZE = 3'd3, WRITE = 3'd4, FINISH = 3'd5;
reg [2:0] DnCNN_cs, DnCNN_ns;

// Counter
reg [5:0] cnt;
reg [2:0] col_cnt; 
reg [2:0] row_cnt;
reg [3:0] filter_cnt;
reg [3:0] channel_cnt;
reg [2:0] layer_cnt;

// Quantize Scale
wire [31:0] Quantize_scale;

// SRAM Address
wire [15:0] inact_addr, weight_addr, outact_addr;

// ================= Storage ================= //
// Weight Storage
reg [23:0] Weight [2:0];

// Activation Storage
reg [47:0] Activation [5:0];
reg [47:0] last_Act_prev [15:0];
reg [47:0] last_Act_cur  [15:0];

// Output Activation Storage
reg signed [31:0] write_row0 [3:0];
reg signed [31:0] write_row1 [3:0];
reg signed [31:0] write_row2 [3:0];
reg signed [31:0] write_row3 [3:0];

wire signed [31:0] out_row0 [3:0];
wire signed [31:0] out_row1 [3:0];
wire signed [31:0] out_row2 [3:0];
wire signed [31:0] out_row3 [3:0];

// ========================================== Counter ========================================== //
// General Counter
always @(posedge clk) begin
    if (DnCNN_cs != DnCNN_ns) cnt <= 0;
    else if (DnCNN_cs == READ) cnt <= cnt + 1;
    else if (DnCNN_cs == CALCULATE) cnt <= cnt + 1;
    else if (DnCNN_cs == QUANTIZE) cnt <= cnt + 1;
    else if (DnCNN_cs == WRITE) cnt <= cnt + 1;
    else cnt <= cnt;
end

// Column Counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) col_cnt <= 0;
    else if (DnCNN_cs == WRITE && DnCNN_ns == READ) begin
        if (col_cnt == 7) col_cnt <= 0;
        else col_cnt <= col_cnt + 1;
    end
    else col_cnt <= col_cnt;
end

// Row Counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) row_cnt <= 0;
    else if (DnCNN_cs == WRITE && DnCNN_ns == READ) begin
        if (col_cnt == 7 && row_cnt < 7) row_cnt <= row_cnt + 1;
        else if (col_cnt == 7 && row_cnt == 7) row_cnt <= 0;
        else row_cnt <= row_cnt;
    end
    else row_cnt <= row_cnt;
end

// Filter Counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) filter_cnt <= 0;
    else if (DnCNN_cs == WRITE && DnCNN_ns == READ) begin
        if (col_cnt == 7 && row_cnt == 7 && filter_cnt < 15) filter_cnt <= filter_cnt + 1;
        else if (col_cnt == 7 && row_cnt == 7 && filter_cnt == 15) filter_cnt <= 0;
        else filter_cnt <= filter_cnt;
    end
    else filter_cnt <= filter_cnt;
end

// Channel Counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) channel_cnt <= 0;
    else if (DnCNN_cs == CALCULATE && DnCNN_ns == READ) begin
        channel_cnt <= channel_cnt + 1;
    end
    else if (DnCNN_cs == CALCULATE && DnCNN_ns == QUANTIZE) begin
        channel_cnt <= 0;
    end
    else channel_cnt <= channel_cnt;
end

// Layer Counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) layer_cnt <= 0;
    else if (DnCNN_cs == WRITE && DnCNN_ns == READ) begin
        if (col_cnt == 7 && row_cnt == 7 && filter_cnt == 15) begin
            layer_cnt <= layer_cnt + 1;
        end
        else layer_cnt <= layer_cnt;
    end
    else layer_cnt <= layer_cnt;
end

// ========================================== Quantize Scale ========================================== //
assign Quantize_scale = (layer_cnt == 0) ? scale_C1 :
                        (layer_cnt == 1) ? scale_C2 :
                        (layer_cnt == 2) ? scale_C3 :
                        (layer_cnt == 3) ? scale_C4 :
                        (layer_cnt == 4) ? scale_C5 :
                        (layer_cnt == 5) ? scale_C6 :
                        (layer_cnt == 6) ? scale_C7 :
                         0;

// ========================================== SRAM Controller ========================================== //
// SRAM Address
assign inact_addr = (layer_cnt == 0) ? -8 + 8*cnt + col_cnt + 32*row_cnt + 256*channel_cnt :
                     -8 + 256 + 8*cnt + col_cnt + 32*row_cnt + 256*channel_cnt + 4096*(layer_cnt-1);
assign weight_addr = (layer_cnt == 0) ? cnt + 3*filter_cnt  + 3*channel_cnt :
                      48 + cnt + 48*filter_cnt + 3*channel_cnt + 768*(layer_cnt-1);
assign outact_addr = 256 + 16*cnt + col_cnt + 32*row_cnt + 256*filter_cnt + 4096*layer_cnt;

// SRAM Activation Address
always @* begin
    if (DnCNN_cs == READ && DnCNN_ns == READ) begin
        sram_act_addr0 = inact_addr;
        sram_act_addr1 = inact_addr + 1;
    end
    else if (DnCNN_cs == WRITE && DnCNN_ns == WRITE) begin
        sram_act_addr0 = outact_addr;
        sram_act_addr1 = outact_addr + 8;
    end
    else begin
        // sram_act_addr0 = sram_act_addr0;
        // sram_act_addr1 = sram_act_addr1;
        sram_act_addr0 = 32'd0;
        sram_act_addr1 = 32'd0;
    end
end

// SRAM Weight Address
always @* begin
    if (DnCNN_cs == READ && DnCNN_ns == READ) begin
        sram_weight_addr0 = weight_addr;
        sram_weight_addr1 = weight_addr;       
    end
    else begin
        sram_weight_addr0 = sram_weight_addr0;
        sram_weight_addr1 = sram_weight_addr1;
    end
end

// SRAM Weight Write Enable
always @(posedge clk) begin
    sram_weight_wea0 <= 4'b0000;
    sram_weight_wea1 <= 4'b0000;
end

// SRAM Activation Write Enable
always @* begin 
    if (DnCNN_cs == WRITE && DnCNN_ns == WRITE) begin
        sram_act_wea0 = 4'b1111;
        sram_act_wea1 = 4'b1111;
    end
    else begin
        sram_act_wea0 = 4'b0000;
        sram_act_wea1 = 4'b0000;
    end
end

// SRAM Activation Write Data
always @* begin
    if (DnCNN_cs == WRITE && DnCNN_ns == WRITE) begin
        if (cnt == 0) begin
            sram_act_wdata0 = {write_row0[3][7:0], write_row0[2][7:0], write_row0[1][7:0], write_row0[0][7:0]};
            sram_act_wdata1 = {write_row1[3][7:0], write_row1[2][7:0], write_row1[1][7:0], write_row1[0][7:0]};
        end
        else if (cnt == 1) begin
            sram_act_wdata0 = {write_row2[3][7:0], write_row2[2][7:0], write_row2[1][7:0], write_row2[0][7:0]};
            sram_act_wdata1 = {write_row3[3][7:0], write_row3[2][7:0], write_row3[1][7:0], write_row3[0][7:0]};
        end
        else begin
            // sram_act_wdata0 = sram_act_wdata0;
            // sram_act_wdata1 = sram_act_wdata1;
            sram_act_wdata0 = 32'd0;
            sram_act_wdata1 = 32'd0;
        end
    end
    else begin
        sram_act_wdata0 = 32'd0;
        sram_act_wdata1 = 32'd0;
    end
end

// ========================================== Memory Storage ========================================== //
// Weight Storage
always @(posedge clk) begin
    if (DnCNN_cs == READ && cnt >= 1 && cnt <= 3) Weight[cnt-1] <= sram_weight_rdata0[23:0];
    else begin
        for(i=0; i<3; i=i+1) Weight[i] <= Weight[i];
    end
end

// Activation Storage
always @(posedge clk) begin
    if (DnCNN_cs == READ && cnt >= 1 && cnt <= 6) begin
        case (cnt)
            1: begin // Avtivation row0
                if (row_cnt == 0) Activation[cnt-1] <= 48'd0;
                else if (col_cnt == 0) Activation[cnt-1] <= {sram_act_rdata1[7:0], sram_act_rdata0, 8'd0};
                else if (col_cnt == 7) Activation[cnt-1] <= {8'd0, sram_act_rdata0, last_Act_prev[channel_cnt][ 7: 0]};
                else Activation[cnt-1] <= {sram_act_rdata1[7:0], sram_act_rdata0, last_Act_prev[channel_cnt][ 7: 0]};
            end
            2: begin
                if (col_cnt == 0) Activation[cnt-1] <= {sram_act_rdata1[7:0], sram_act_rdata0, 8'd0};
                else if (col_cnt == 7) Activation[cnt-1] <= {8'd0, sram_act_rdata0, last_Act_prev[channel_cnt][15: 8]};
                else Activation[cnt-1] <= {sram_act_rdata1[7:0], sram_act_rdata0, last_Act_prev[channel_cnt][15: 8]};
            end
            3: begin
                if (col_cnt == 0) Activation[cnt-1] <= {sram_act_rdata1[7:0], sram_act_rdata0, 8'd0};
                else if (col_cnt == 7) Activation[cnt-1] <= {8'd0, sram_act_rdata0, last_Act_prev[channel_cnt][23:16]};
                else Activation[cnt-1] <= {sram_act_rdata1[7:0], sram_act_rdata0, last_Act_prev[channel_cnt][23:16]};
            end
            4: begin
                if (col_cnt == 0) Activation[cnt-1] <= {sram_act_rdata1[7:0], sram_act_rdata0, 8'd0};
                else if (col_cnt == 7) Activation[cnt-1] <= {8'd0, sram_act_rdata0, last_Act_prev[channel_cnt][31:24]};
                else Activation[cnt-1] <= {sram_act_rdata1[7:0], sram_act_rdata0, last_Act_prev[channel_cnt][31:24]};
            end
            5: begin
                if (col_cnt == 0) Activation[cnt-1] <= {sram_act_rdata1[7:0], sram_act_rdata0, 8'd0};
                else if (col_cnt == 7) Activation[cnt-1] <= {8'd0, sram_act_rdata0, last_Act_prev[channel_cnt][39:32]};
                else Activation[cnt-1] <= {sram_act_rdata1[7:0], sram_act_rdata0, last_Act_prev[channel_cnt][39:32]};
            end
            6: begin // Avtivation row5
                if (row_cnt == 7) Activation[cnt-1] <= 48'd0;
                else if (col_cnt == 0) Activation[cnt-1] <= {sram_act_rdata1[7:0], sram_act_rdata0, 8'd0};
                else if (col_cnt == 7) Activation[cnt-1] <= {8'd0, sram_act_rdata0, last_Act_prev[channel_cnt][47:40]};
                else Activation[cnt-1] <= {sram_act_rdata1[7:0], sram_act_rdata0, last_Act_prev[channel_cnt][47:40]};
            end
        endcase
    end
    else begin
        for(i=0; i<6; i=i+1) Activation[i] <= Activation[i];
    end
end

// Last Activation Storage
always @(posedge clk) begin
    if (DnCNN_cs == READ && cnt >= 0 && cnt <= 5) begin
        case (cnt) 
            0: last_Act_prev[channel_cnt][ 7: 0] <= last_Act_cur[channel_cnt][ 7: 0];
            1: last_Act_prev[channel_cnt][15: 8] <= last_Act_cur[channel_cnt][15: 8];
            2: last_Act_prev[channel_cnt][23:16] <= last_Act_cur[channel_cnt][23:16];
            3: last_Act_prev[channel_cnt][31:24] <= last_Act_cur[channel_cnt][31:24];
            4: last_Act_prev[channel_cnt][39:32] <= last_Act_cur[channel_cnt][39:32];
            5: last_Act_prev[channel_cnt][47:40] <= last_Act_cur[channel_cnt][47:40];
        endcase
    end
    else if (DnCNN_cs == WRITE && DnCNN_ns == READ) begin
        if (col_cnt == 7) for(i=0; i<16; i=i+1) last_Act_prev[i] <= 48'd0;
        else for(i=0; i<16; i=i+1) last_Act_prev[i] <= last_Act_prev[i];
    end
    else begin
        for(i=0; i<16; i=i+1) last_Act_prev[i] <= last_Act_prev[i];
    end
end

always @(posedge clk) begin
    if (DnCNN_cs == READ && cnt >= 1 && cnt <= 6) begin
        case (cnt) 
            1: last_Act_cur[channel_cnt][ 7: 0] <= sram_act_rdata0[31:24];
            2: last_Act_cur[channel_cnt][15: 8] <= sram_act_rdata0[31:24];
            3: last_Act_cur[channel_cnt][23:16] <= sram_act_rdata0[31:24];
            4: last_Act_cur[channel_cnt][31:24] <= sram_act_rdata0[31:24];
            5: last_Act_cur[channel_cnt][39:32] <= sram_act_rdata0[31:24];
            6: last_Act_cur[channel_cnt][47:40] <= sram_act_rdata0[31:24];
        endcase
    end
    else if (DnCNN_cs == WRITE && DnCNN_ns == READ) begin
        if (col_cnt == 7) for(i=0; i<16; i=i+1) last_Act_cur[i] <= 48'd0;
        else for(i=0; i<16; i=i+1) last_Act_cur[i] <= last_Act_cur[i];
    end
    else begin
        for(i=0; i<16; i=i+1) last_Act_cur[i] <= last_Act_cur[i];
    end
end

// ========================================== Output Activation Accumulate ========================================== //
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for(i=0;i<4;i=i+1) write_row0[i] <= 32'd0;
        for(i=0;i<4;i=i+1) write_row1[i] <= 32'd0;
        for(i=0;i<4;i=i+1) write_row2[i] <= 32'd0;
        for(i=0;i<4;i=i+1) write_row3[i] <= 32'd0;
    end
    else if (DnCNN_cs == CALCULATE && (DnCNN_ns == READ || DnCNN_ns == QUANTIZE)) begin
        for(i=0;i<4;i=i+1) write_row0[i] <= write_row0[i] + out_row0[i];
        for(i=0;i<4;i=i+1) write_row1[i] <= write_row1[i] + out_row1[i];
        for(i=0;i<4;i=i+1) write_row2[i] <= write_row2[i] + out_row2[i];
        for(i=0;i<4;i=i+1) write_row3[i] <= write_row3[i] + out_row3[i];
    end
    else if (DnCNN_cs == QUANTIZE && DnCNN_ns == QUANTIZE) begin
        case (cnt) 
            0: begin
                for(i=0;i<4;i=i+1) write_row0[i] <= write_row0[i] * Quantize_scale;
                for(i=0;i<4;i=i+1) write_row1[i] <= write_row1[i] * Quantize_scale;
                for(i=0;i<4;i=i+1) write_row2[i] <= write_row2[i] * Quantize_scale;
                for(i=0;i<4;i=i+1) write_row3[i] <= write_row3[i] * Quantize_scale;
            end
            1: begin
                for(i=0;i<4;i=i+1) write_row0[i] <= write_row0[i] >>> 16;
                for(i=0;i<4;i=i+1) write_row1[i] <= write_row1[i] >>> 16;
                for(i=0;i<4;i=i+1) write_row2[i] <= write_row2[i] >>> 16;
                for(i=0;i<4;i=i+1) write_row3[i] <= write_row3[i] >>> 16;
            end
            2: begin
                for(i=0;i<4;i=i+1) write_row0[i] <= (write_row0[i] > 127) ? 127 : write_row0[i];
                for(i=0;i<4;i=i+1) write_row1[i] <= (write_row1[i] > 127) ? 127 : write_row1[i];
                for(i=0;i<4;i=i+1) write_row2[i] <= (write_row2[i] > 127) ? 127 : write_row2[i];
                for(i=0;i<4;i=i+1) write_row3[i] <= (write_row3[i] > 127) ? 127 : write_row3[i];
            end
            3: begin
                for(i=0;i<4;i=i+1) write_row0[i] <= (write_row0[i] < -128) ? -128 : write_row0[i];
                for(i=0;i<4;i=i+1) write_row1[i] <= (write_row1[i] < -128) ? -128 : write_row1[i];
                for(i=0;i<4;i=i+1) write_row2[i] <= (write_row2[i] < -128) ? -128 : write_row2[i];
                for(i=0;i<4;i=i+1) write_row3[i] <= (write_row3[i] < -128) ? -128 : write_row3[i];
            end
            4: begin
                for(i=0;i<4;i=i+1) write_row0[i] <= (write_row0[i] < 0 && layer_cnt != 6) ? 0 : write_row0[i];
                for(i=0;i<4;i=i+1) write_row1[i] <= (write_row1[i] < 0 && layer_cnt != 6) ? 0 : write_row1[i];
                for(i=0;i<4;i=i+1) write_row2[i] <= (write_row2[i] < 0 && layer_cnt != 6) ? 0 : write_row2[i];
                for(i=0;i<4;i=i+1) write_row3[i] <= (write_row3[i] < 0 && layer_cnt != 6) ? 0 : write_row3[i];
            end
            default: begin
                for(i=0;i<4;i=i+1) write_row0[i] <= write_row0[i];
                for(i=0;i<4;i=i+1) write_row1[i] <= write_row1[i];
                for(i=0;i<4;i=i+1) write_row2[i] <= write_row2[i];
                for(i=0;i<4;i=i+1) write_row3[i] <= write_row3[i];
            end
        endcase
        
    end
    else if (DnCNN_cs == WRITE && DnCNN_ns == READ) begin
        for(i=0;i<4;i=i+1) write_row0[i] <= 32'd0;
        for(i=0;i<4;i=i+1) write_row1[i] <= 32'd0;
        for(i=0;i<4;i=i+1) write_row2[i] <= 32'd0;
        for(i=0;i<4;i=i+1) write_row3[i] <= 32'd0;
    end
end

// ======================================================= DnCNN FSM ======================================================= //
// Current State
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) DnCNN_cs <= IDLE;
    else DnCNN_cs <= DnCNN_ns;
end    

// Next State
always @* begin
    case(DnCNN_cs)
        IDLE: begin
            if (compute_start) DnCNN_ns = READ;
            else DnCNN_ns = DnCNN_cs; 
        end
        READ: begin
            if (cnt == 6) DnCNN_ns = CALCULATE;
            else DnCNN_ns = DnCNN_cs; 
        end
        CALCULATE: begin
            if (layer_cnt == 0) begin
                if (cnt == 5) DnCNN_ns = QUANTIZE;
                else DnCNN_ns = DnCNN_cs; 
            end
            else if (layer_cnt >= 1 && layer_cnt <= 6) begin
                if (cnt == 5 && channel_cnt == 15) DnCNN_ns = QUANTIZE;
                else if (cnt == 5 && channel_cnt < 15) DnCNN_ns = READ;
                else DnCNN_ns = DnCNN_cs; 
            end
            else DnCNN_ns = DnCNN_cs; 
        end
        QUANTIZE: begin
            if (cnt == 5) DnCNN_ns = WRITE;
            else DnCNN_ns = DnCNN_cs; 
        end
        WRITE: begin
            if (cnt == 2) begin 
                if (col_cnt == 7 && row_cnt == 7 && filter_cnt == 0 && layer_cnt == 6) DnCNN_ns = FINISH;
                else DnCNN_ns = READ;
            end
            else DnCNN_ns = DnCNN_cs; 
        end
        FINISH: begin
            DnCNN_ns = IDLE;
        end
        default: DnCNN_ns = DnCNN_cs;  
    endcase
end

// Output Logic
always @* begin
    compute_finish = (DnCNN_cs == FINISH);
end

// ========================================== Module Initialization ========================================== //
PEA pea(.clk(clk),
        .DnCNN_cs(DnCNN_cs),
        .cnt(cnt),
        .act_row0(Activation[0]),
        .act_row1(Activation[1]),
        .act_row2(Activation[2]),
        .act_row3(Activation[3]),
        .act_row4(Activation[4]),
        .act_row5(Activation[5]),
        .weight_row0(Weight[0]),
        .weight_row1(Weight[1]),
        .weight_row2(Weight[2]),
        .out_row0_0(out_row0[0]),
        .out_row0_1(out_row0[1]),
        .out_row0_2(out_row0[2]),
        .out_row0_3(out_row0[3]),
        .out_row1_0(out_row1[0]),
        .out_row1_1(out_row1[1]),
        .out_row1_2(out_row1[2]),
        .out_row1_3(out_row1[3]),
        .out_row2_0(out_row2[0]),
        .out_row2_1(out_row2[1]),
        .out_row2_2(out_row2[2]),
        .out_row2_3(out_row2[3]),
        .out_row3_0(out_row3[0]),
        .out_row3_1(out_row3[1]),
        .out_row3_2(out_row3[2]),
        .out_row3_3(out_row3[3])
        );

endmodule

// ======================================================= PE ======================================================= //
module PE (
    input wire clk,
    input wire en,

    // Input activation
    input wire signed [7:0] act0,
    input wire signed [7:0] act1,
    input wire signed [7:0] act2,

    // Weight
    input wire signed [7:0] weight0,
    input wire signed [7:0] weight1,
    input wire signed [7:0] weight2,

    // Output partial sum
    output reg signed [31:0] psum

);

reg signed [15:0] product0;
reg signed [15:0] product1;
reg signed [15:0] product2;

integer i;

always @(posedge clk) begin
    if (en) begin
        // 1st stage
        product0 <= act0 * weight0;
        product1 <= act1 * weight1;
        product2 <= act2 * weight2;

        // 2nd stage
        psum <= product0 + product1 + product2;
    end 
    else psum <= 0;
end

endmodule

// ======================================================= PEA ======================================================= //
module PEA (
    input wire clk,

    // Control Signals
    input wire [2:0] DnCNN_cs,
    input wire [5:0] cnt,

    // Input Activation
    input wire [47:0] act_row0,
    input wire [47:0] act_row1,
    input wire [47:0] act_row2,
    input wire [47:0] act_row3,
    input wire [47:0] act_row4,
    input wire [47:0] act_row5,

    // Weight
    input wire [23:0] weight_row0,
    input wire [23:0] weight_row1,
    input wire [23:0] weight_row2,

    // Output Activation
    output reg signed [31:0] out_row0_0,
    output reg signed [31:0] out_row0_1,
    output reg signed [31:0] out_row0_2,
    output reg signed [31:0] out_row0_3,

    output reg signed [31:0] out_row1_0,
    output reg signed [31:0] out_row1_1,
    output reg signed [31:0] out_row1_2,
    output reg signed [31:0] out_row1_3,

    output reg signed [31:0] out_row2_0,
    output reg signed [31:0] out_row2_1,
    output reg signed [31:0] out_row2_2,
    output reg signed [31:0] out_row2_3,

    output reg signed [31:0] out_row3_0,
    output reg signed [31:0] out_row3_1,
    output reg signed [31:0] out_row3_2,
    output reg signed [31:0] out_row3_3
);

wire enable;
assign enable = (DnCNN_cs==2 && cnt>=0 && cnt<=4);

wire signed [7:0] act00 [2:0];
wire signed [7:0] act01 [2:0];
wire signed [7:0] act02 [2:0];
wire signed [7:0] act03 [2:0];

wire signed [7:0] act10 [2:0];
wire signed [7:0] act11 [2:0];
wire signed [7:0] act12 [2:0];
wire signed [7:0] act13 [2:0];

wire signed [7:0] act20 [2:0];
wire signed [7:0] act21 [2:0];
wire signed [7:0] act22 [2:0];
wire signed [7:0] act23 [2:0];

wire signed [31:0] psum00;
wire signed [31:0] psum01;
wire signed [31:0] psum02;
wire signed [31:0] psum03;

wire signed [31:0] psum10;
wire signed [31:0] psum11;
wire signed [31:0] psum12;
wire signed [31:0] psum13;

wire signed [31:0] psum20;
wire signed [31:0] psum21;
wire signed [31:0] psum22;
wire signed [31:0] psum23;


assign act00[0] = (cnt==0) ? act_row0[ 7: 0] :
                  (cnt==1) ? act_row0[15: 8] :
                  (cnt==2) ? act_row0[23:16] :
                  (cnt==3) ? act_row0[31:24] :
                   0;

assign act00[1] = (cnt==0) ? act_row0[15: 8] :
                  (cnt==1) ? act_row0[23:16] :
                  (cnt==2) ? act_row0[31:24] :
                  (cnt==3) ? act_row0[39:32] :
                   0;

assign act00[2] = (cnt==0) ? act_row0[23:16] :
                  (cnt==1) ? act_row0[31:24] :
                  (cnt==2) ? act_row0[39:32] :
                  (cnt==3) ? act_row0[47:40] :
                   0;

assign act01[0] = (cnt==0) ? act_row1[ 7: 0] :
                  (cnt==1) ? act_row1[15: 8] :
                  (cnt==2) ? act_row1[23:16] :
                  (cnt==3) ? act_row1[31:24] :
                   0;

assign act01[1] = (cnt==0) ? act_row1[15: 8] :
                  (cnt==1) ? act_row1[23:16] :
                  (cnt==2) ? act_row1[31:24] :
                  (cnt==3) ? act_row1[39:32] :
                   0;

assign act01[2] = (cnt==0) ? act_row1[23:16] :
                  (cnt==1) ? act_row1[31:24] :
                  (cnt==2) ? act_row1[39:32] :
                  (cnt==3) ? act_row1[47:40] :
                   0;

assign act02[0] = (cnt==0) ? act_row2[ 7: 0] :
                  (cnt==1) ? act_row2[15: 8] :
                  (cnt==2) ? act_row2[23:16] :
                  (cnt==3) ? act_row2[31:24] :
                   0;

assign act02[1] = (cnt==0) ? act_row2[15: 8] :
                  (cnt==1) ? act_row2[23:16] :
                  (cnt==2) ? act_row2[31:24] :
                  (cnt==3) ? act_row2[39:32] :
                   0;

assign act02[2] = (cnt==0) ? act_row2[23:16] :
                  (cnt==1) ? act_row2[31:24] :
                  (cnt==2) ? act_row2[39:32] :
                  (cnt==3) ? act_row2[47:40] :
                   0;

assign act03[0] = (cnt==0) ? act_row3[ 7: 0] :
                  (cnt==1) ? act_row3[15: 8] :
                  (cnt==2) ? act_row3[23:16] :
                  (cnt==3) ? act_row3[31:24] :
                   0;

assign act03[1] = (cnt==0) ? act_row3[15: 8] :
                  (cnt==1) ? act_row3[23:16] :
                  (cnt==2) ? act_row3[31:24] :
                  (cnt==3) ? act_row3[39:32] :
                   0;

assign act03[2] = (cnt==0) ? act_row3[23:16] :
                  (cnt==1) ? act_row3[31:24] :
                  (cnt==2) ? act_row3[39:32] :
                  (cnt==3) ? act_row3[47:40] :
                   0;

assign act10[0] = (cnt==0) ? act_row1[ 7: 0] :
                  (cnt==1) ? act_row1[15: 8] :
                  (cnt==2) ? act_row1[23:16] :
                  (cnt==3) ? act_row1[31:24] :
                   0;

assign act10[1] = (cnt==0) ? act_row1[15: 8] :
                  (cnt==1) ? act_row1[23:16] :
                  (cnt==2) ? act_row1[31:24] :
                  (cnt==3) ? act_row1[39:32] :
                   0;

assign act10[2] = (cnt==0) ? act_row1[23:16] :
                  (cnt==1) ? act_row1[31:24] :
                  (cnt==2) ? act_row1[39:32] :
                  (cnt==3) ? act_row1[47:40] :
                   0;

assign act11[0] = (cnt==0) ? act_row2[ 7: 0] :
                  (cnt==1) ? act_row2[15: 8] :
                  (cnt==2) ? act_row2[23:16] :
                  (cnt==3) ? act_row2[31:24] :
                   0;

assign act11[1] = (cnt==0) ? act_row2[15: 8] :
                  (cnt==1) ? act_row2[23:16] :
                  (cnt==2) ? act_row2[31:24] :
                  (cnt==3) ? act_row2[39:32] :
                   0;

assign act11[2] = (cnt==0) ? act_row2[23:16] :
                  (cnt==1) ? act_row2[31:24] :
                  (cnt==2) ? act_row2[39:32] :
                  (cnt==3) ? act_row2[47:40] :
                   0;

assign act12[0] = (cnt==0) ? act_row3[ 7: 0] :
                  (cnt==1) ? act_row3[15: 8] :
                  (cnt==2) ? act_row3[23:16] :
                  (cnt==3) ? act_row3[31:24] :
                   0;

assign act12[1] = (cnt==0) ? act_row3[15: 8] :
                  (cnt==1) ? act_row3[23:16] :
                  (cnt==2) ? act_row3[31:24] :
                  (cnt==3) ? act_row3[39:32] :
                   0;

assign act12[2] = (cnt==0) ? act_row3[23:16] :
                  (cnt==1) ? act_row3[31:24] :
                  (cnt==2) ? act_row3[39:32] :
                  (cnt==3) ? act_row3[47:40] :
                   0;

assign act13[0] = (cnt==0) ? act_row4[ 7: 0] :
                  (cnt==1) ? act_row4[15: 8] :
                  (cnt==2) ? act_row4[23:16] :
                  (cnt==3) ? act_row4[31:24] :
                   0;

assign act13[1] = (cnt==0) ? act_row4[15: 8] :
                  (cnt==1) ? act_row4[23:16] :
                  (cnt==2) ? act_row4[31:24] :
                  (cnt==3) ? act_row4[39:32] :
                   0;

assign act13[2] = (cnt==0) ? act_row4[23:16] :
                  (cnt==1) ? act_row4[31:24] :
                  (cnt==2) ? act_row4[39:32] :
                  (cnt==3) ? act_row4[47:40] :
                   0;

assign act20[0] = (cnt==0) ? act_row2[ 7: 0] :
                  (cnt==1) ? act_row2[15: 8] :
                  (cnt==2) ? act_row2[23:16] :
                  (cnt==3) ? act_row2[31:24] :
                   0;

assign act20[1] = (cnt==0) ? act_row2[15: 8] :
                  (cnt==1) ? act_row2[23:16] :
                  (cnt==2) ? act_row2[31:24] :
                  (cnt==3) ? act_row2[39:32] :
                   0;

assign act20[2] = (cnt==0) ? act_row2[23:16] :
                  (cnt==1) ? act_row2[31:24] :
                  (cnt==2) ? act_row2[39:32] :
                  (cnt==3) ? act_row2[47:40] :
                   0;

assign act21[0] = (cnt==0) ? act_row3[ 7: 0] :
                  (cnt==1) ? act_row3[15: 8] :
                  (cnt==2) ? act_row3[23:16] :
                  (cnt==3) ? act_row3[31:24] :
                   0;

assign act21[1] = (cnt==0) ? act_row3[15: 8] :
                  (cnt==1) ? act_row3[23:16] :
                  (cnt==2) ? act_row3[31:24] :
                  (cnt==3) ? act_row3[39:32] :
                   0;

assign act21[2] = (cnt==0) ? act_row3[23:16] :
                  (cnt==1) ? act_row3[31:24] :
                  (cnt==2) ? act_row3[39:32] :
                  (cnt==3) ? act_row3[47:40] :
                   0;

assign act22[0] = (cnt==0) ? act_row4[ 7: 0] :
                  (cnt==1) ? act_row4[15: 8] :
                  (cnt==2) ? act_row4[23:16] :
                  (cnt==3) ? act_row4[31:24] :
                   0;

assign act22[1] = (cnt==0) ? act_row4[15: 8] :
                  (cnt==1) ? act_row4[23:16] :
                  (cnt==2) ? act_row4[31:24] :
                  (cnt==3) ? act_row4[39:32] :
                   0;

assign act22[2] = (cnt==0) ? act_row4[23:16] :
                  (cnt==1) ? act_row4[31:24] :
                  (cnt==2) ? act_row4[39:32] :
                  (cnt==3) ? act_row4[47:40] :
                   0;

assign act23[0] = (cnt==0) ? act_row5[ 7: 0] :
                  (cnt==1) ? act_row5[15: 8] :
                  (cnt==2) ? act_row5[23:16] :
                  (cnt==3) ? act_row5[31:24] :
                   0;

assign act23[1] = (cnt==0) ? act_row5[15: 8] :
                  (cnt==1) ? act_row5[23:16] :
                  (cnt==2) ? act_row5[31:24] :
                  (cnt==3) ? act_row5[39:32] :
                   0;

assign act23[2] = (cnt==0) ? act_row5[23:16] :
                  (cnt==1) ? act_row5[31:24] :
                  (cnt==2) ? act_row5[39:32] :
                  (cnt==3) ? act_row5[47:40] :
                   0;

always @* begin
    case (cnt)
        2: begin
            out_row0_0 = psum00 + psum10 + psum20;
            out_row1_0 = psum01 + psum11 + psum21;
            out_row2_0 = psum02 + psum12 + psum22;
            out_row3_0 = psum03 + psum13 + psum23;
            out_row0_1 = out_row0_1;
            out_row1_1 = out_row1_1;
            out_row2_1 = out_row2_1;
            out_row3_1 = out_row3_1;
            out_row0_2 = out_row0_2;
            out_row1_2 = out_row1_2;
            out_row2_2 = out_row2_2;
            out_row3_2 = out_row3_2;
            out_row0_3 = out_row0_3;
            out_row1_3 = out_row1_3;
            out_row2_3 = out_row2_3;
            out_row3_3 = out_row3_3;
        end
        3: begin
            out_row0_0 = out_row0_0;
            out_row1_0 = out_row1_0;
            out_row2_0 = out_row2_0;
            out_row3_0 = out_row3_0;
            out_row0_1 = psum00 + psum10 + psum20;
            out_row1_1 = psum01 + psum11 + psum21;
            out_row2_1 = psum02 + psum12 + psum22;
            out_row3_1 = psum03 + psum13 + psum23;
            out_row0_2 = out_row0_2;
            out_row1_2 = out_row1_2;
            out_row2_2 = out_row2_2;
            out_row3_2 = out_row3_2;
            out_row0_3 = out_row0_3;
            out_row1_3 = out_row1_3;
            out_row2_3 = out_row2_3;
            out_row3_3 = out_row3_3;
        end
        4: begin
            out_row0_0 = out_row0_0;
            out_row1_0 = out_row1_0;
            out_row2_0 = out_row2_0;
            out_row3_0 = out_row3_0;
            out_row0_1 = out_row0_1;
            out_row1_1 = out_row1_1;
            out_row2_1 = out_row2_1;
            out_row3_1 = out_row3_1;
            out_row0_2 = psum00 + psum10 + psum20;
            out_row1_2 = psum01 + psum11 + psum21;
            out_row2_2 = psum02 + psum12 + psum22;
            out_row3_2 = psum03 + psum13 + psum23;
            out_row0_3 = out_row0_3;
            out_row1_3 = out_row1_3;
            out_row2_3 = out_row2_3;
            out_row3_3 = out_row3_3;
        end
        5: begin
            out_row0_0 = out_row0_0;
            out_row1_0 = out_row1_0;
            out_row2_0 = out_row2_0;
            out_row3_0 = out_row3_0;
            out_row0_1 = out_row0_1;
            out_row1_1 = out_row1_1;
            out_row2_1 = out_row2_1;
            out_row3_1 = out_row3_1;
            out_row0_2 = out_row0_2;
            out_row1_2 = out_row1_2;
            out_row2_2 = out_row2_2;
            out_row3_2 = out_row3_2;
            out_row0_3 = psum00 + psum10 + psum20;
            out_row1_3 = psum01 + psum11 + psum21;
            out_row2_3 = psum02 + psum12 + psum22;
            out_row3_3 = psum03 + psum13 + psum23;
        end
        default: begin
            out_row0_0 = out_row0_0;
            out_row1_0 = out_row1_0;
            out_row2_0 = out_row2_0;
            out_row3_0 = out_row3_0;
            out_row0_1 = out_row0_1;
            out_row1_1 = out_row1_1;
            out_row2_1 = out_row2_1;
            out_row3_1 = out_row3_1;
            out_row0_2 = out_row0_2;
            out_row1_2 = out_row1_2;
            out_row2_2 = out_row2_2;
            out_row3_2 = out_row3_2;
            out_row0_3 = out_row0_3;
            out_row1_3 = out_row1_3;
            out_row2_3 = out_row2_3;
            out_row3_3 = out_row3_3;
        end
    endcase
end

// ========================================== 1st diagonal ========================================== //
PE pe00(.clk(clk),
        .en(enable),
        .act0(act00[0]), 
        .act1(act00[1]), 
        .act2(act00[2]),
        .weight0(weight_row0[7:0]),
        .weight1(weight_row0[15:8]),
        .weight2(weight_row0[23:16]),
        .psum(psum00)
        );

// ========================================== 2nd diagonal ========================================== //
PE pe01(.clk(clk),
        .en(enable),
        .act0(act01[0]), 
        .act1(act01[1]), 
        .act2(act01[2]),
        .weight0(weight_row0[7:0]),
        .weight1(weight_row0[15:8]),
        .weight2(weight_row0[23:16]),
        .psum(psum01)
        );

PE pe10(.clk(clk),
        .en(enable),
        .act0(act10[0]), 
        .act1(act10[1]), 
        .act2(act10[2]),
        .weight0(weight_row1[7:0]),
        .weight1(weight_row1[15:8]),
        .weight2(weight_row1[23:16]),
        .psum(psum10)
        );

// ========================================== 3rd diagonal ========================================== //
PE pe02(.clk(clk),
        .en(enable),
        .act0(act02[0]), 
        .act1(act02[1]), 
        .act2(act02[2]),
        .weight0(weight_row0[7:0]),
        .weight1(weight_row0[15:8]),
        .weight2(weight_row0[23:16]),
        .psum(psum02)
        );

PE pe11(.clk(clk),
        .en(enable),
        .act0(act11[0]), 
        .act1(act11[1]), 
        .act2(act11[2]),
        .weight0(weight_row1[7:0]),
        .weight1(weight_row1[15:8]),
        .weight2(weight_row1[23:16]),
        .psum(psum11)
        );

PE pe20(.clk(clk),
        .en(enable),
        .act0(act20[0]), 
        .act1(act20[1]), 
        .act2(act20[2]),
        .weight0(weight_row2[7:0]),
        .weight1(weight_row2[15:8]),
        .weight2(weight_row2[23:16]),
        .psum(psum20)
        );

// ========================================== 4th diagonal ========================================== //
PE pe03(.clk(clk),
        .en(enable),
        .act0(act03[0]), 
        .act1(act03[1]), 
        .act2(act03[2]),
        .weight0(weight_row0[7:0]),
        .weight1(weight_row0[15:8]),
        .weight2(weight_row0[23:16]),
        .psum(psum03)
        );

PE pe12(.clk(clk),
        .en(enable),
        .act0(act12[0]), 
        .act1(act12[1]), 
        .act2(act12[2]),
        .weight0(weight_row1[7:0]),
        .weight1(weight_row1[15:8]),
        .weight2(weight_row1[23:16]),
        .psum(psum12)
        );

PE pe21(.clk(clk),
        .en(enable),
        .act0(act21[0]), 
        .act1(act21[1]), 
        .act2(act21[2]),
        .weight0(weight_row2[7:0]),
        .weight1(weight_row2[15:8]),
        .weight2(weight_row2[23:16]),
        .psum(psum21)
        );

// ========================================== 5th diagonal ========================================== //
PE pe13(.clk(clk),
        .en(enable),
        .act0(act13[0]), 
        .act1(act13[1]), 
        .act2(act13[2]),
        .weight0(weight_row1[7:0]),
        .weight1(weight_row1[15:8]),
        .weight2(weight_row1[23:16]),
        .psum(psum13)
        );

PE pe22(.clk(clk),
        .en(enable),
        .act0(act22[0]), 
        .act1(act22[1]), 
        .act2(act22[2]),
        .weight0(weight_row2[7:0]),
        .weight1(weight_row2[15:8]),
        .weight2(weight_row2[23:16]),
        .psum(psum22)
        );

// ========================================== 6th diagonal ========================================== //
PE pe23(.clk(clk),
        .en(enable),
        .act0(act23[0]), 
        .act1(act23[1]), 
        .act2(act23[2]),
        .weight0(weight_row2[7:0]),
        .weight1(weight_row2[15:8]),
        .weight2(weight_row2[23:16]),
        .psum(psum23)
        );

endmodule