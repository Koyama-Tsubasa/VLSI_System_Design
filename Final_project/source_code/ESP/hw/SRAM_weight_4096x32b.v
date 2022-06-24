module SRAM_weight_4096x32b( 
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

reg  [3:0] WEA0 [1:0];
reg  [3:0] WEA1 [1:0];

wire [31:0] RDATA0 [1:0];
wire [31:0] RDATA1 [1:0];

reg [15:0] addr0_prev;
reg [15:0] addr1_prev;

always @(posedge clk) begin
    addr0_prev <= addr0;
    addr1_prev <= addr1;
end

integer x;

always @* begin
    for (x=0; x<2; x=x+1) begin
        WEA0[x] = 4'b0000;
    end
    case (addr0[11])
        1'b0: WEA0[0] = wea0; 
        1'b1: WEA0[1] = wea0; 
    endcase
end

always @* begin
    for (x=0; x<2; x=x+1) begin
        WEA1[x] = 4'b0000;
    end
    case (addr1[11])
        1'b0: WEA1[0] = wea1; 
        1'b1: WEA1[1] = wea1;   
    endcase
end

assign rdata0 = addr0_prev[11] == 1'b0 ? RDATA0[0] :
                RDATA0[1]; 

assign rdata1 = addr1_prev[11] == 1'b0 ? RDATA1[0] :
                RDATA1[1]; 

genvar i, j;

generate 
for (i=0; i<2; i=i+1) begin : outer
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