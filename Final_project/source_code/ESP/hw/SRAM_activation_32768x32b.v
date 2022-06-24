module SRAM_activation_32768x32b( 
    input wire clk,
    input wire [ 3:0] wea0,
    input wire [15:0] addr0,
    input wire [31:0] wdata0,
    output wire [31:0] rdata0,
    input wire [ 3:0] wea1,
    input wire [15:0] addr1,
    input wire [31:0] wdata1,
    output wire [31:0] rdata1
);

reg  [3:0] WEA0 [15:0];
reg  [3:0] WEA1 [15:0];

wire [31:0] RDATA0 [15:0];
wire [31:0] RDATA1 [15:0];

reg [15:0] addr0_prev;
reg [15:0] addr1_prev;

always @(posedge clk) begin
    addr0_prev <= addr0;
    addr1_prev <= addr1;
end

integer x;

always @* begin
    for (x=0; x<16; x=x+1) begin
        WEA0[x] = 4'b0000;
    end
    case (addr0[14:11])
        4'b0000: WEA0[0] = wea0;
        4'b0001: WEA0[1] = wea0;
        4'b0010: WEA0[2] = wea0;
        4'b0011: WEA0[3] = wea0;
        4'b0100: WEA0[4] = wea0;
        4'b0101: WEA0[5] = wea0;
        4'b0110: WEA0[6] = wea0;
        4'b0111: WEA0[7] = wea0;
        4'b1000: WEA0[8] = wea0;
        4'b1001: WEA0[9] = wea0;
        4'b1010: WEA0[10] = wea0;
        4'b1011: WEA0[11] = wea0;
        4'b1100: WEA0[12] = wea0;
        4'b1101: WEA0[13] = wea0;
        4'b1110: WEA0[14] = wea0;
        4'b1111: WEA0[15] = wea0;
    endcase
end

always @* begin
    for (x=0; x<16; x=x+1) begin
        WEA1[x] = 4'b0000;
    end
    case (addr1[14:11])
        4'b0000: WEA1[0] = wea1;
        4'b0001: WEA1[1] = wea1;
        4'b0010: WEA1[2] = wea1;
        4'b0011: WEA1[3] = wea1;
        4'b0100: WEA1[4] = wea1;
        4'b0101: WEA1[5] = wea1;
        4'b0110: WEA1[6] = wea1;
        4'b0111: WEA1[7] = wea1;
        4'b1000: WEA1[8] = wea1;
        4'b1001: WEA1[9] = wea1;
        4'b1010: WEA1[10] = wea1;
        4'b1011: WEA1[11] = wea1;
        4'b1100: WEA1[12] = wea1;
        4'b1101: WEA1[13] = wea1;
        4'b1110: WEA1[14] = wea1;
        4'b1111: WEA1[15] = wea1;
    endcase
end

assign rdata0 = addr0_prev[14:11] == 4'b0000 ? RDATA0[0] :
                addr0_prev[14:11] == 4'b0001 ? RDATA0[1] :
                addr0_prev[14:11] == 4'b0010 ? RDATA0[2] :
                addr0_prev[14:11] == 4'b0011 ? RDATA0[3] :
                addr0_prev[14:11] == 4'b0100 ? RDATA0[4] :
                addr0_prev[14:11] == 4'b0101 ? RDATA0[5] :
                addr0_prev[14:11] == 4'b0110 ? RDATA0[6] :
                addr0_prev[14:11] == 4'b0111 ? RDATA0[7] :
                addr0_prev[14:11] == 4'b1000 ? RDATA0[8] :
                addr0_prev[14:11] == 4'b1001 ? RDATA0[9] :
                addr0_prev[14:11] == 4'b1010 ? RDATA0[10] :
                addr0_prev[14:11] == 4'b1011 ? RDATA0[11] :
                addr0_prev[14:11] == 4'b1100 ? RDATA0[12] :
                addr0_prev[14:11] == 4'b1101 ? RDATA0[13] :
                addr0_prev[14:11] == 4'b1110 ? RDATA0[14] :
                RDATA0[15];

assign rdata1 = addr1_prev[14:11] == 4'b0000 ? RDATA1[0] :
                addr1_prev[14:11] == 4'b0001 ? RDATA1[1] :
                addr1_prev[14:11] == 4'b0010 ? RDATA1[2] :
                addr1_prev[14:11] == 4'b0011 ? RDATA1[3] :
                addr1_prev[14:11] == 4'b0100 ? RDATA1[4] :
                addr1_prev[14:11] == 4'b0101 ? RDATA1[5] :
                addr1_prev[14:11] == 4'b0110 ? RDATA1[6] :
                addr1_prev[14:11] == 4'b0111 ? RDATA1[7] :
                addr1_prev[14:11] == 4'b1000 ? RDATA1[8] :
                addr1_prev[14:11] == 4'b1001 ? RDATA1[9] :
                addr1_prev[14:11] == 4'b1010 ? RDATA1[10] :
                addr1_prev[14:11] == 4'b1011 ? RDATA1[11] :
                addr1_prev[14:11] == 4'b1100 ? RDATA1[12] :
                addr1_prev[14:11] == 4'b1101 ? RDATA1[13] :
                addr1_prev[14:11] == 4'b1110 ? RDATA1[14] :
                RDATA1[15];

genvar i, j;

generate 
for (i=0; i<16; i=i+1) begin : outer
    for (j=0; j<4; j=j+1) begin : inner
    
        BRAM_2048x8 bank_i(
            .CLK(clk),
            .A0(addr0[10:0]),
            .D0(wdata0[8*j+7:8*j+0]),
            .Q0(RDATA0[i][8*j+7:8*j+0]),
            .WE0(WEA0[i][j]),
            .WEM0(8'b0),
            .CE0(1'b1),
            .A1(addr1[10:0]),
            .D1(wdata1[8*j+7:8*j+0]),
            .Q1(RDATA1[i][8*j+7:8*j+0]),
            .WE1(WEA1[i][j]),
            .WEM1(8'b0),
            .CE1(1'b1)
        );
    end
end
endgenerate

endmodule