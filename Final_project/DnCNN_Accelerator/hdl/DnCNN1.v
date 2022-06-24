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
localparam IDLE = 3'd0, READ_WEIGHT = 3'd1, CALCULATE = 3'd2, QUANTIZE = 3'd3, WRITE_OUTPUT = 3'd4, FINISH = 3'd5;
reg [2:0] DnCNN_cs, DnCNN_ns;

// Counter
reg [5:0] cnt;
reg [5:0] col_cnt; 
reg [5:0] row_cnt;
reg [5:0] filter_cnt;
reg [5:0] diag_cnt;
reg [5:0] layer_cnt;
reg [5:0] channel_cnt;

wire signed [31:0] scale;

// SRAM Address
wire [15:0] inact_addr, weight_addr, outact_addr;

// ================= Storage ================= //
// Weight Storage
reg [23:0] Weight [2:0];

reg signed [31:0] row0 [31:0];
reg signed [31:0] row1 [31:0];
reg signed [31:0] row2 [31:0];
reg signed [31:0] row3 [31:0];
wire signed [31:0] out_row0, out_row1, out_row2, out_row3;


// ========================================== Counter ========================================== //
// General Counter
always @(posedge clk) begin
    if (DnCNN_cs != DnCNN_ns) cnt <= 0;
    else if (DnCNN_cs == READ_WEIGHT) cnt <= cnt + 1;
    else if (DnCNN_cs == CALCULATE) cnt <= cnt + 1;
    else if (DnCNN_cs == QUANTIZE) cnt <= cnt + 1;
    else if (DnCNN_cs == WRITE_OUTPUT) cnt <= cnt + 1;
    else cnt <= cnt;
end

// Column Counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) col_cnt <= 0;
    else if (DnCNN_cs == CALCULATE && DnCNN_ns == CALCULATE) begin
        if (cnt == 7 || cnt == 15 || cnt == 23) col_cnt <= col_cnt + 1;
        else col_cnt <= col_cnt;
    end
    else if (DnCNN_cs == WRITE_OUTPUT && (DnCNN_ns == CALCULATE || DnCNN_ns == READ_WEIGHT)) begin
        col_cnt <= 0;
    end
    else if (DnCNN_cs == READ_WEIGHT && DnCNN_ns == CALCULATE) begin
        col_cnt <= 0;
    end
    else col_cnt <= col_cnt;
end

// Row Counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) row_cnt <= 0;
    else if (DnCNN_cs == WRITE_OUTPUT && DnCNN_ns == CALCULATE) begin
        row_cnt <= row_cnt + 1;
    end
    else if (DnCNN_cs == WRITE_OUTPUT && DnCNN_ns == READ_WEIGHT) begin
        if (layer_cnt == 0) row_cnt <= 0;
        else if (layer_cnt >= 1 && layer_cnt <= 6) begin
            if (row_cnt == 7) row_cnt <= 0;
            else row_cnt <= row_cnt + 1;
        end
    end
    else row_cnt <= row_cnt;
end

// Filter Counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) filter_cnt <= 0;
    else if (DnCNN_cs == WRITE_OUTPUT && DnCNN_ns == READ_WEIGHT && layer_cnt == 0) begin
        if (filter_cnt == 15) filter_cnt <= 0;
        else filter_cnt <= filter_cnt + 1;
    end
    else if (DnCNN_cs == WRITE_OUTPUT && DnCNN_ns == READ_WEIGHT && layer_cnt >= 1 && layer_cnt <= 6) begin
        if (row_cnt == 7 && filter_cnt == 15) filter_cnt <= 0;
        else if (row_cnt == 7 && filter_cnt < 15) filter_cnt <= filter_cnt + 1;
        else filter_cnt <= filter_cnt;
    end
    else filter_cnt <= filter_cnt;
end

// Diagonal Counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) diag_cnt <= 0;
    else if (DnCNN_cs == CALCULATE && DnCNN_ns == CALCULATE) begin
        if (cnt[2:0] <= 4 && cnt < 34) diag_cnt <= diag_cnt + 1;
        else if (cnt[2:0] == 7 && cnt < 34) diag_cnt <= 0;
        else diag_cnt <= diag_cnt;
    end
    else if (DnCNN_cs == WRITE_OUTPUT && (DnCNN_ns == CALCULATE || DnCNN_ns == READ_WEIGHT)) begin
        diag_cnt <= 0;
    end
    else if (DnCNN_cs == CALCULATE && DnCNN_ns == READ_WEIGHT) begin
        diag_cnt <= 0;
    end
    else diag_cnt <= diag_cnt;
end

// Layer Counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) layer_cnt <= 0;
    else if (DnCNN_cs == WRITE_OUTPUT && cnt==16 && row_cnt==7 && filter_cnt==15) begin
        layer_cnt <= layer_cnt + 1;
    end
    else layer_cnt <= layer_cnt;
end

// Channel Counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) channel_cnt <= 0;
    else if (DnCNN_cs == CALCULATE && DnCNN_ns == READ_WEIGHT) begin
        channel_cnt <= channel_cnt + 1;
    end
    else if (DnCNN_cs == WRITE_OUTPUT && DnCNN_ns == READ_WEIGHT) begin
        channel_cnt <= 0;
    end
    else channel_cnt <= channel_cnt;
end

assign scale = (layer_cnt == 0) ? scale_C1 :
               (layer_cnt == 1) ? scale_C2 :
               (layer_cnt == 2) ? scale_C3 :
               (layer_cnt == 3) ? scale_C4 :
               (layer_cnt == 4) ? scale_C5 :
               (layer_cnt == 5) ? scale_C6 :
               (layer_cnt == 6) ? scale_C7 :
               0;

// ========================================== SRAM Controller ========================================== //
// SRAM Address
assign inact_addr = (layer_cnt == 0) ? 8*diag_cnt+2*col_cnt-8+row_cnt*32 :
                    (layer_cnt >= 1 && layer_cnt <= 6) ? 8*diag_cnt+2*col_cnt-8+row_cnt*32+256+channel_cnt*256+4096*(layer_cnt-1):
                     0;
assign weight_addr = (layer_cnt == 0) ? cnt+3*filter_cnt :
                     (layer_cnt >= 1 && layer_cnt <= 6) ? cnt+48*filter_cnt+48+3*channel_cnt+768*(layer_cnt-1) :
                      0;
assign outact_addr = (layer_cnt == 0) ? 256+2*(cnt%4)+8*(cnt/4)+0+row_cnt*32+256*filter_cnt :
                     (layer_cnt >= 1 && layer_cnt <= 6) ? 256+4096*layer_cnt+2*(cnt%4)+8*(cnt/4)+0+row_cnt*32+256*filter_cnt :
                      0;

always @* begin
    if (DnCNN_cs == CALCULATE && DnCNN_ns == CALCULATE) begin
        sram_act_addr0 = inact_addr;
        sram_act_addr1 = inact_addr + 1;
    end
    else if (DnCNN_cs == WRITE_OUTPUT && DnCNN_ns == WRITE_OUTPUT) begin
        sram_act_addr0 = outact_addr;
        sram_act_addr1 = outact_addr + 1;
    end
    else begin
        sram_act_addr0 = sram_act_addr0;
        sram_act_addr1 = sram_act_addr1;
    end
end

always @* begin
    if (DnCNN_cs == READ_WEIGHT && DnCNN_ns == READ_WEIGHT) begin
        sram_weight_addr0 = weight_addr;
        sram_weight_addr1 = weight_addr;       
    end
    else begin
        sram_weight_addr0 = sram_weight_addr0;
        sram_weight_addr1 = sram_weight_addr1;
    end
end

// SRAM Write Enable
always @(posedge clk) begin
    sram_weight_wea0 <= 4'b0000;
    sram_weight_wea1 <= 4'b0000;
end

always @* begin 
    if (DnCNN_cs == WRITE_OUTPUT && DnCNN_ns == WRITE_OUTPUT) begin
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
    if (DnCNN_cs == WRITE_OUTPUT && DnCNN_ns == WRITE_OUTPUT) begin
        case (cnt/4)
            0: begin
                sram_act_wdata0 = {row0[8*(cnt%4)+3][7:0],row0[8*(cnt%4)+2][7:0],row0[8*(cnt%4)+1][7:0],row0[8*(cnt%4)+0][7:0]};
                sram_act_wdata1 = {row0[8*(cnt%4)+7][7:0],row0[8*(cnt%4)+6][7:0],row0[8*(cnt%4)+5][7:0],row0[8*(cnt%4)+4][7:0]};
            end
            1: begin
                sram_act_wdata0 = {row1[8*(cnt%4)+3][7:0],row1[8*(cnt%4)+2][7:0],row1[8*(cnt%4)+1][7:0],row1[8*(cnt%4)+0][7:0]};
                sram_act_wdata1 = {row1[8*(cnt%4)+7][7:0],row1[8*(cnt%4)+6][7:0],row1[8*(cnt%4)+5][7:0],row1[8*(cnt%4)+4][7:0]};
            end
            2: begin
                sram_act_wdata0 = {row2[8*(cnt%4)+3][7:0],row2[8*(cnt%4)+2][7:0],row2[8*(cnt%4)+1][7:0],row2[8*(cnt%4)+0][7:0]};
                sram_act_wdata1 = {row2[8*(cnt%4)+7][7:0],row2[8*(cnt%4)+6][7:0],row2[8*(cnt%4)+5][7:0],row2[8*(cnt%4)+4][7:0]};
            end
            3: begin
                sram_act_wdata0 = {row3[8*(cnt%4)+3][7:0],row3[8*(cnt%4)+2][7:0],row3[8*(cnt%4)+1][7:0],row3[8*(cnt%4)+0][7:0]};
                sram_act_wdata1 = {row3[8*(cnt%4)+7][7:0],row3[8*(cnt%4)+6][7:0],row3[8*(cnt%4)+5][7:0],row3[8*(cnt%4)+4][7:0]};
            end
        endcase
    end
end

// SRAM Activation Write Data
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for(i=0;i<32;i=i+1) begin
            row0[i] <= 32'b0;
        end
    end
    else if (DnCNN_cs == CALCULATE && DnCNN_ns == CALCULATE) begin
        if (cnt >= 9 && cnt <= 40) begin
            row0[cnt-9] <= row0[cnt-9] + out_row0;
        end
    end
    else if (DnCNN_cs == QUANTIZE && DnCNN_ns == QUANTIZE) begin
        for(i=0;i<32;i=i+1) begin
            if (layer_cnt < 6) begin
                row0[i] <= (row0[i]<=0) ? 32'b0 :
                           (((row0[i]*scale) >>> 16) > 127) ? 127 :
                           (row0[i]*scale) >>> 16;
            end
            else if (layer_cnt == 6) begin
                row0[i] <= (((row0[i]*scale) >>> 16) >  127) ?  127 :
                           (((row0[i]*scale) >>> 16) < -128) ? -128 :
                           (row0[i]*scale) >>> 16;
            end
        end
    end
    else if (DnCNN_cs == WRITE_OUTPUT && (DnCNN_ns == READ_WEIGHT || DnCNN_ns == CALCULATE)) begin
        for(i=0;i<32;i=i+1) begin
            row0[i] <= 32'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for(i=0;i<32;i=i+1) begin
            row1[i] <= 32'b0;
        end
    end
    else if (DnCNN_cs == CALCULATE && DnCNN_ns == CALCULATE) begin
        if (cnt >= 10 && cnt <= 41) begin
            row1[cnt-10] <= row1[cnt-10] + out_row1;
        end
    end
    else if (DnCNN_cs == QUANTIZE && DnCNN_ns == QUANTIZE) begin
        for(i=0;i<32;i=i+1) begin
            if (layer_cnt < 6) begin
                row1[i] <= (row1[i]<=0) ? 32'b0 :
                           (((row1[i]*scale) >>> 16) > 127) ? 127 :
                           (row1[i]*scale) >>> 16;
            end
            else if (layer_cnt == 6) begin
                row1[i] <= (((row1[i]*scale) >>> 16) >  127) ?  127 :
                           (((row1[i]*scale) >>> 16) < -128) ? -128 :
                           (row1[i]*scale) >>> 16;
            end
        end
    end
    else if (DnCNN_cs == WRITE_OUTPUT && (DnCNN_ns == READ_WEIGHT || DnCNN_ns == CALCULATE)) begin
        for(i=0;i<32;i=i+1) begin
            row1[i] <= 32'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for(i=0;i<32;i=i+1) begin
            row2[i] <= 32'b0;
        end
    end
    else if (DnCNN_cs == CALCULATE && DnCNN_ns == CALCULATE) begin
        if (cnt >= 11 && cnt <= 42) begin
            row2[cnt-11] <= row2[cnt-11] + out_row2;
        end
    end
    else if (DnCNN_cs == QUANTIZE && DnCNN_ns == QUANTIZE) begin
        for(i=0;i<32;i=i+1) begin
            if (layer_cnt < 6) begin
                row2[i] <= (row2[i]<=0) ? 32'b0 :
                           (((row2[i]*scale) >>> 16) > 127) ? 127 :
                           (row2[i]*scale) >>> 16;
            end
            else if (layer_cnt == 6) begin
                row2[i] <= (((row2[i]*scale) >>> 16) >  127) ?  127 :
                           (((row2[i]*scale) >>> 16) < -128) ? -128 :
                           (row2[i]*scale) >>> 16;
            end
        end
    end
    else if (DnCNN_cs == WRITE_OUTPUT && (DnCNN_ns == READ_WEIGHT || DnCNN_ns == CALCULATE)) begin
        for(i=0;i<32;i=i+1) begin
            row2[i] <= 32'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for(i=0;i<32;i=i+1) begin
            row3[i] <= 32'b0;
        end
    end
    else if (DnCNN_cs == CALCULATE && DnCNN_ns == CALCULATE) begin
        if (cnt >= 12 && cnt <= 43) begin
            row3[cnt-12] <= row3[cnt-12] + out_row3;
        end
    end
    else if (DnCNN_cs == QUANTIZE && DnCNN_ns == QUANTIZE) begin
        for(i=0;i<32;i=i+1) begin
            if (layer_cnt < 6) begin
                row3[i] <= (row3[i]<=0) ? 32'b0 :
                           (((row3[i]*scale) >>> 16) > 127) ? 127 :
                           (row3[i]*scale) >>> 16;
            end
            else if (layer_cnt == 6) begin
                row3[i] <= (((row3[i]*scale) >>> 16) >  127) ?  127 :
                           (((row3[i]*scale) >>> 16) < -128) ? -128 :
                           (row3[i]*scale) >>> 16;
            end
        end
    end
    else if (DnCNN_cs == WRITE_OUTPUT && (DnCNN_ns == READ_WEIGHT || DnCNN_ns == CALCULATE)) begin
        for(i=0;i<32;i=i+1) begin
            row3[i] <= 32'b0;
        end
    end
end

// ========================================== Memory Storage ========================================== //
// Weight Storage
always @(posedge clk) begin
    if (DnCNN_cs == READ_WEIGHT) Weight[cnt-1] <= sram_weight_rdata0[23:0];
    else begin
        for(i=0; i<3; i=i+1) Weight[i] <= Weight[i];
    end
end

// ======================================================= DnCNN FSM ======================================================= //
// Current State
always @(posedge clk or negedge rst_n) begin
// always @(posedge clk) begin
    if (!rst_n) DnCNN_cs <= IDLE;
    else DnCNN_cs <= DnCNN_ns;
end    

// Next State
always @* begin
    case(DnCNN_cs)
        IDLE: begin
            if (compute_start) DnCNN_ns = READ_WEIGHT;
            else DnCNN_ns = DnCNN_cs; 
        end
        READ_WEIGHT: begin
            if (cnt == 3) DnCNN_ns = CALCULATE;
            else DnCNN_ns = DnCNN_cs; 
        end
        CALCULATE: begin
            if (layer_cnt == 0) begin
                if (cnt == 45) DnCNN_ns = QUANTIZE;
                else DnCNN_ns = DnCNN_cs; 
            end
            else if (layer_cnt >= 1 && layer_cnt <= 6) begin
                if (cnt == 45 && channel_cnt == 15) DnCNN_ns = QUANTIZE;
                else if (cnt == 45 && channel_cnt < 15) DnCNN_ns = READ_WEIGHT;
                else DnCNN_ns = DnCNN_cs; 
            end
        end
        QUANTIZE: begin
            if (cnt == 1) DnCNN_ns = WRITE_OUTPUT;
            else DnCNN_ns = DnCNN_cs; 
        end
        WRITE_OUTPUT: begin
            if (cnt == 16) begin 
                if (layer_cnt == 0) begin
                    if (row_cnt == 7 && filter_cnt == 15) DnCNN_ns = READ_WEIGHT;
                    else if (row_cnt == 7 && filter_cnt < 15) DnCNN_ns = READ_WEIGHT;
                    else DnCNN_ns = CALCULATE;
                end
                else if (layer_cnt >= 1 && layer_cnt <= 5) begin
                    if (row_cnt == 7 && filter_cnt == 15) DnCNN_ns = READ_WEIGHT;
                    else DnCNN_ns = READ_WEIGHT;
                end
                else if (layer_cnt == 6) begin
                    if (row_cnt == 7 && filter_cnt == 0) DnCNN_ns = FINISH;
                    else DnCNN_ns = READ_WEIGHT;
                end
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
        .col_cnt(col_cnt),
        .row_cnt(row_cnt),
        .scale(scale_C1),
        .sram_act_rdata0(sram_act_rdata0),
        .sram_act_rdata1(sram_act_rdata1),
        .weight_row0(Weight[0]),
        .weight_row1(Weight[1]),
        .weight_row2(Weight[2]),
        .out_row0(out_row0),
        .out_row1(out_row1),
        .out_row2(out_row2),
        .out_row3(out_row3)
        );

endmodule

// ======================================================= CONTROLLER ======================================================= //
module CONTROLLER (
    input wire clk,

    input wire ctrl_en,

    input wire [5:0] start,
    input wire [5:0] cur,

    input wire [2:0] diagonal,

    output reg read_act,
    output reg fifo_en,
    output reg cal_en
);

always @* begin
    if (ctrl_en) begin
        read_act = (cur == start+1);
        // fifo_en = (cur >= start+2 && cur <= start+9) || (cur >= start+11 && cur <= start+18);
        fifo_en = (cur >= 2+diagonal) && (!read_act);
        // cal_en = (cur >= 5+diagonal && cur <= 36+diagonal);
        cal_en = (cur >= 4+diagonal && cur <= 37+diagonal);
    end
    else begin
        read_act = 0;
        fifo_en = 0;
        cal_en = 0;
    end
end

endmodule

// ======================================================= BUFFER ======================================================= //
module BUFFER (
    input wire clk,

    input wire read_act,
    input wire fifo_en,
    input wire padding,

    input wire [31:0] sram_act_rdata0,
    input wire [31:0] sram_act_rdata1,

    output wire signed [7:0] act0,
    output wire signed [7:0] act1,
    output wire signed [7:0] act2
);

reg [63:0] temp;
reg signed [7:0] Act [2:0];

always @(posedge clk) begin
    if (padding) begin
        temp <= 0;
    end
    else if (read_act) begin
        temp <= {sram_act_rdata1, sram_act_rdata0};
    end
    else if (fifo_en) begin
        temp <= (temp >> 8);
    end
    else begin
        // temp <= temp;
        temp <= 0;
    end
end

always @(posedge clk) begin
    // if (fifo_en) begin
    //     Act[0] <= Act[1];
    //     Act[1] <= Act[2];
    //     Act[2] <= $signed(temp[7:0]);
    // end
    // else begin
    //     Act[0] <= Act[0];
    //     Act[1] <= Act[1];
    //     Act[2] <= Act[2];
    // end
    Act[0] <= Act[1];
    Act[1] <= Act[2];
    Act[2] <= $signed(temp[7:0]);
end

assign act0 = Act[0];
assign act1 = Act[1];
assign act2 = Act[2];

endmodule

// ======================================================= PE ======================================================= //
module PE (
    input wire clk,

    input wire cal_en,

    // Input activation
    input wire signed [7:0] act0,
    input wire signed [7:0] act1,
    input wire signed [7:0] act2,

    // Weight
    input wire signed [7:0] weight0,
    input wire signed [7:0] weight1,
    input wire signed [7:0] weight2,

    // Input partial sum
    input wire signed [31:0] psum_in,

    // Output partial sum
    output reg signed [31:0] psum_out

);

reg signed [15:0] product [2:0];
reg signed [16:0] adder;

integer i;

always @(posedge clk) begin
    if (cal_en) begin
        // 1st stage
        product[0] <= act0 * weight0;
        product[1] <= act1 * weight1;
        product[2] <= act2 * weight2;

        // 2nd stage
        adder <= product[0] + product[1] + product[2];

        // 3th stage
        psum_out <= psum_in + adder;
    end 
    else psum_out <= 0;
end

endmodule


// ======================================================= PEA ======================================================= //
module PEA (
    input wire clk,

    // Control Signals
    input wire [2:0] DnCNN_cs,
    input wire [5:0] cnt,
    input wire [5:0] col_cnt,
    input wire [5:0] row_cnt,

    input wire [31:0] scale,

    // Input Activation
    input wire [31:0] sram_act_rdata0,
    input wire [31:0] sram_act_rdata1,

    // Weight
    input wire [23:0] weight_row0,
    input wire [23:0] weight_row1,
    input wire [23:0] weight_row2,

    // Output Activation
    output reg signed [31:0] out_row0,
    output reg signed [31:0] out_row1,
    output reg signed [31:0] out_row2,
    output reg signed [31:0] out_row3
);

wire read_act00, fifo_en00, cal_en00;
wire read_act01, fifo_en01, cal_en01;
wire read_act02, fifo_en02, cal_en02;
wire read_act03, fifo_en03, cal_en03;

wire read_act10, fifo_en10, cal_en10;
wire read_act11, fifo_en11, cal_en11;
wire read_act12, fifo_en12, cal_en12;
wire read_act13, fifo_en13, cal_en13;

wire read_act20, fifo_en20, cal_en20;
wire read_act21, fifo_en21, cal_en21;
wire read_act22, fifo_en22, cal_en22;
wire read_act23, fifo_en23, cal_en23;

wire [5:0] start00;
wire [5:0] start01;
wire [5:0] start02;
wire [5:0] start03;

wire [5:0] start10;
wire [5:0] start11;
wire [5:0] start12;
wire [5:0] start13;

wire [5:0] start20;
wire [5:0] start21;
wire [5:0] start22;
wire [5:0] start23;

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


assign start00 = 8*col_cnt;
assign start01 = 8*col_cnt+1;
assign start02 = 8*col_cnt+2;
assign start03 = 8*col_cnt+3;

assign start10 = 8*col_cnt+1;
assign start11 = 8*col_cnt+2;
assign start12 = 8*col_cnt+3;
assign start13 = 8*col_cnt+4;

assign start20 = 8*col_cnt+2;
assign start21 = 8*col_cnt+3;
assign start22 = 8*col_cnt+4;
assign start23 = 8*col_cnt+5;

always @* begin
    out_row0 = psum20;
    out_row1 = psum21;
    out_row2 = psum22;
    out_row3 = psum23;
end

// ========================================== 1st diagonal ========================================== //
CONTROLLER ctrl00(.clk(clk),
                  .ctrl_en(DnCNN_cs==2),
                  .start(start00),
                  .cur(cnt),
                  .diagonal(3'd0),
                  .read_act(read_act00),
                  .fifo_en(fifo_en00),
                  .cal_en(cal_en00)
                  );

BUFFER buff00(.clk(clk),
              .read_act(read_act00),
              .fifo_en(fifo_en00),
              .padding(row_cnt==0),
              .sram_act_rdata0(sram_act_rdata0),
              .sram_act_rdata1(sram_act_rdata1),
              .act0(act00[0]), 
              .act1(act00[1]), 
              .act2(act00[2])
              );

PE pe00(.clk(clk),
        .cal_en(cal_en00),
        .act0(act00[0]), 
        .act1(act00[1]), 
        .act2(act00[2]),
        .weight0(weight_row0[7:0]),
        .weight1(weight_row0[15:8]),
        .weight2(weight_row0[23:16]),
        .psum_in(32'd0),
        .psum_out(psum00)
        );

// ========================================== 2nd diagonal ========================================== //
CONTROLLER ctrl01(.clk(clk),
                  .ctrl_en(DnCNN_cs==2),
                  .start(start01),
                  .cur(cnt),
                  .diagonal(3'd1),
                  .read_act(read_act01),
                  .fifo_en(fifo_en01),
                  .cal_en(cal_en01)
                  );

BUFFER buff01(.clk(clk),
              .read_act(read_act01),
              .fifo_en(fifo_en01),
              .padding(1'b0),
              .sram_act_rdata0(sram_act_rdata0),
              .sram_act_rdata1(sram_act_rdata1),
              .act0(act01[0]), 
              .act1(act01[1]), 
              .act2(act01[2])
              );

PE pe01(.clk(clk),
        .cal_en(cal_en01),
        .act0(act01[0]), 
        .act1(act01[1]), 
        .act2(act01[2]),
        .weight0(weight_row0[7:0]),
        .weight1(weight_row0[15:8]),
        .weight2(weight_row0[23:16]),
        .psum_in(32'd0),
        .psum_out(psum01)
        );

CONTROLLER ctrl10(.clk(clk),
                  .ctrl_en(DnCNN_cs==2),
                  .start(start10),
                  .cur(cnt),
                  .diagonal(3'd1),
                  .read_act(read_act10),
                  .fifo_en(fifo_en10),
                  .cal_en(cal_en10)
                  );

BUFFER buff10(.clk(clk),
              .read_act(read_act10),
              .fifo_en(fifo_en10),
              .padding(1'b0),
              .sram_act_rdata0(sram_act_rdata0),
              .sram_act_rdata1(sram_act_rdata1),
              .act0(act10[0]), 
              .act1(act10[1]), 
              .act2(act10[2])
              );

PE pe10(.clk(clk),
        .cal_en(cal_en10),
        .act0(act10[0]), 
        .act1(act10[1]), 
        .act2(act10[2]),
        .weight0(weight_row1[7:0]),
        .weight1(weight_row1[15:8]),
        .weight2(weight_row1[23:16]),
        .psum_in(psum00),
        .psum_out(psum10)
        );


// ========================================== 3rd diagonal ========================================== //
CONTROLLER ctrl02(.clk(clk),
                  .ctrl_en(DnCNN_cs==2),
                  .start(start02),
                  .cur(cnt),
                  .diagonal(3'd2),
                  .read_act(read_act02),
                  .fifo_en(fifo_en02),
                  .cal_en(cal_en02)
                  );

BUFFER buff02(.clk(clk),
              .read_act(read_act02),
              .fifo_en(fifo_en02),
              .padding(1'b0),
              .sram_act_rdata0(sram_act_rdata0),
              .sram_act_rdata1(sram_act_rdata1),
              .act0(act02[0]), 
              .act1(act02[1]), 
              .act2(act02[2])
              );

PE pe02(.clk(clk),
        .cal_en(cal_en02),
        .act0(act02[0]), 
        .act1(act02[1]), 
        .act2(act02[2]),
        .weight0(weight_row0[7:0]),
        .weight1(weight_row0[15:8]),
        .weight2(weight_row0[23:16]),
        .psum_in(32'd0),
        .psum_out(psum02)
        );

CONTROLLER ctrl11(.clk(clk),
                  .ctrl_en(DnCNN_cs==2),
                  .start(start11),
                  .cur(cnt),
                  .diagonal(3'd2),
                  .read_act(read_act11),
                  .fifo_en(fifo_en11),
                  .cal_en(cal_en11)
                  );

BUFFER buff11(.clk(clk),
              .read_act(read_act11),
              .fifo_en(fifo_en11),
              .padding(1'b0),
              .sram_act_rdata0(sram_act_rdata0),
              .sram_act_rdata1(sram_act_rdata1),
              .act0(act11[0]), 
              .act1(act11[1]), 
              .act2(act11[2])
              );

PE pe11(.clk(clk),
        .cal_en(cal_en11),
        .act0(act11[0]), 
        .act1(act11[1]), 
        .act2(act11[2]),
        .weight0(weight_row1[7:0]),
        .weight1(weight_row1[15:8]),
        .weight2(weight_row1[23:16]),
        .psum_in(psum01),
        .psum_out(psum11)
        );

CONTROLLER ctrl20(.clk(clk),
                  .ctrl_en(DnCNN_cs==2),
                  .start(start20),
                  .cur(cnt),
                  .diagonal(3'd2),
                  .read_act(read_act20),
                  .fifo_en(fifo_en20),
                  .cal_en(cal_en20)
                  );

BUFFER buff20(.clk(clk),
              .read_act(read_act20),
              .fifo_en(fifo_en20),
              .padding(1'b0),
              .sram_act_rdata0(sram_act_rdata0),
              .sram_act_rdata1(sram_act_rdata1),
              .act0(act20[0]), 
              .act1(act20[1]), 
              .act2(act20[2])
              );

PE pe20(.clk(clk),
        .cal_en(cal_en20),
        .act0(act20[0]), 
        .act1(act20[1]), 
        .act2(act20[2]),
        .weight0(weight_row2[7:0]),
        .weight1(weight_row2[15:8]),
        .weight2(weight_row2[23:16]),
        .psum_in(psum10),
        .psum_out(psum20)
        );

// ========================================== 4th diagonal ========================================== //
CONTROLLER ctrl03(.clk(clk),
                  .ctrl_en(DnCNN_cs==2),
                  .start(start03),
                  .cur(cnt),
                  .diagonal(3'd3),
                  .read_act(read_act03),
                  .fifo_en(fifo_en03),
                  .cal_en(cal_en03)
                  );

BUFFER buff03(.clk(clk),
              .read_act(read_act03),
              .fifo_en(fifo_en03),
              .padding(1'b0),
              .sram_act_rdata0(sram_act_rdata0),
              .sram_act_rdata1(sram_act_rdata1),
              .act0(act03[0]), 
              .act1(act03[1]), 
              .act2(act03[2])
              );

PE pe03(.clk(clk),
        .cal_en(cal_en03),
        .act0(act03[0]), 
        .act1(act03[1]), 
        .act2(act03[2]),
        .weight0(weight_row0[7:0]),
        .weight1(weight_row0[15:8]),
        .weight2(weight_row0[23:16]),
        .psum_in(32'd0),
        .psum_out(psum03)
        );

CONTROLLER ctrl12(.clk(clk),
                  .ctrl_en(DnCNN_cs==2),
                  .start(start12),
                  .cur(cnt),
                  .diagonal(3'd3),
                  .read_act(read_act12),
                  .fifo_en(fifo_en12),
                  .cal_en(cal_en12)
                  );

BUFFER buff12(.clk(clk),
              .read_act(read_act12),
              .fifo_en(fifo_en12),
              .padding(1'b0),
              .sram_act_rdata0(sram_act_rdata0),
              .sram_act_rdata1(sram_act_rdata1),
              .act0(act12[0]), 
              .act1(act12[1]), 
              .act2(act12[2])
              );

PE pe12(.clk(clk),
        .cal_en(cal_en12),
        .act0(act12[0]), 
        .act1(act12[1]), 
        .act2(act12[2]),
        .weight0(weight_row1[7:0]),
        .weight1(weight_row1[15:8]),
        .weight2(weight_row1[23:16]),
        .psum_in(psum02),
        .psum_out(psum12)
        );

CONTROLLER ctrl21(.clk(clk),
                  .ctrl_en(DnCNN_cs==2),
                  .start(start21),
                  .cur(cnt),
                  .diagonal(3'd3),
                  .read_act(read_act21),
                  .fifo_en(fifo_en21),
                  .cal_en(cal_en21)
                  );

BUFFER buff21(.clk(clk),
              .read_act(read_act21),
              .fifo_en(fifo_en21),
              .padding(1'b0),
              .sram_act_rdata0(sram_act_rdata0),
              .sram_act_rdata1(sram_act_rdata1),
              .act0(act21[0]), 
              .act1(act21[1]), 
              .act2(act21[2])
              );

PE pe21(.clk(clk),
        .cal_en(cal_en21),
        .act0(act21[0]), 
        .act1(act21[1]), 
        .act2(act21[2]),
        .weight0(weight_row2[7:0]),
        .weight1(weight_row2[15:8]),
        .weight2(weight_row2[23:16]),
        .psum_in(psum11),
        .psum_out(psum21)
        );

// ========================================== 5th diagonal ========================================== //
CONTROLLER ctrl13(.clk(clk),
                  .ctrl_en(DnCNN_cs==2),
                  .start(start13),
                  .cur(cnt),
                  .diagonal(3'd4),
                  .read_act(read_act13),
                  .fifo_en(fifo_en13),
                  .cal_en(cal_en13)
                  );

BUFFER buff13(.clk(clk),
              .read_act(read_act13),
              .fifo_en(fifo_en13),
              .padding(1'b0),
              .sram_act_rdata0(sram_act_rdata0),
              .sram_act_rdata1(sram_act_rdata1),
              .act0(act13[0]), 
              .act1(act13[1]), 
              .act2(act13[2])
              );

PE pe13(.clk(clk),
        .cal_en(cal_en13),
        .act0(act13[0]), 
        .act1(act13[1]), 
        .act2(act13[2]),
        .weight0(weight_row1[7:0]),
        .weight1(weight_row1[15:8]),
        .weight2(weight_row1[23:16]),
        .psum_in(psum03),
        .psum_out(psum13)
        );

CONTROLLER ctrl22(.clk(clk),
                  .ctrl_en(DnCNN_cs==2),
                  .start(start22),
                  .cur(cnt),
                  .diagonal(3'd4),
                  .read_act(read_act22),
                  .fifo_en(fifo_en22),
                  .cal_en(cal_en22)
                  );

BUFFER buff22(.clk(clk),
              .read_act(read_act22),
              .fifo_en(fifo_en22),
              .padding(1'b0),
              .sram_act_rdata0(sram_act_rdata0),
              .sram_act_rdata1(sram_act_rdata1),
              .act0(act22[0]), 
              .act1(act22[1]), 
              .act2(act22[2])
              );

PE pe22(.clk(clk),
        .cal_en(cal_en22),
        .act0(act22[0]), 
        .act1(act22[1]), 
        .act2(act22[2]),
        .weight0(weight_row2[7:0]),
        .weight1(weight_row2[15:8]),
        .weight2(weight_row2[23:16]),
        .psum_in(psum12),
        .psum_out(psum22)
        );

// ========================================== 6th diagonal ========================================== //
CONTROLLER ctrl23(.clk(clk),
                  .ctrl_en(DnCNN_cs==2),
                  .start(start23),
                  .cur(cnt),
                  .diagonal(3'd5),
                  .read_act(read_act23),
                  .fifo_en(fifo_en23),
                  .cal_en(cal_en23)
                  );

BUFFER buff23(.clk(clk),
              .read_act(read_act23),
              .fifo_en(fifo_en23),
              .padding(row_cnt==7),
              .sram_act_rdata0(sram_act_rdata0),
              .sram_act_rdata1(sram_act_rdata1),
              .act0(act23[0]), 
              .act1(act23[1]), 
              .act2(act23[2])
              );

PE pe23(.clk(clk),
        .cal_en(cal_en23),
        .act0(act23[0]), 
        .act1(act23[1]), 
        .act2(act23[2]),
        .weight0(weight_row2[7:0]),
        .weight1(weight_row2[15:8]),
        .weight2(weight_row2[23:16]),
        .psum_in(psum13),
        .psum_out(psum23)
        );

endmodule