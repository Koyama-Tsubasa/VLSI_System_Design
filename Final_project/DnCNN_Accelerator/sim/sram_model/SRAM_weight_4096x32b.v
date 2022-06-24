module SRAM_weight_4096x32b( 
    input wire clk,
    input wire [ 3:0] wea0,
    input wire [15:0] addr0,
    input wire [31:0] wdata0,
    output reg [31:0] rdata0,
    input wire [ 3:0] wea1,
    input wire [15:0] addr1,
    input wire [31:0] wdata1,
    output reg [31:0] rdata1
);

    reg [31:0] RAM [0:4095];
    wire [31:0] masked_wdata0, masked_wdata1;
    
    assign masked_wdata0[ 7: 0] = (wea0[0] ? wdata0[ 7: 0] : RAM[addr0][ 7: 0]);
    assign masked_wdata0[15: 8] = (wea0[1] ? wdata0[15: 8] : RAM[addr0][15: 8]);
    assign masked_wdata0[23:16] = (wea0[2] ? wdata0[23:16] : RAM[addr0][23:16]);
    assign masked_wdata0[31:24] = (wea0[3] ? wdata0[31:24] : RAM[addr0][31:24]);

    assign masked_wdata1[ 7: 0] = (wea1[0] ? wdata1[ 7: 0] : RAM[addr1][ 7: 0]);
    assign masked_wdata1[15: 8] = (wea1[1] ? wdata1[15: 8] : RAM[addr1][15: 8]);
    assign masked_wdata1[23:16] = (wea1[2] ? wdata1[23:16] : RAM[addr1][23:16]);
    assign masked_wdata1[31:24] = (wea1[3] ? wdata1[31:24] : RAM[addr1][31:24]);

    always @(posedge clk) begin
        RAM[addr0] <= #(`CYCLE*0.5)masked_wdata0;
        if(addr0 != addr1)
            RAM[addr1] <= #(`CYCLE*0.5)masked_wdata1;
    end 

    always @(posedge clk) begin
        rdata0 <= #(`CYCLE*0.5)RAM[addr0];
    end
    always @(posedge clk) begin
        rdata1 <= #(`CYCLE*0.5) RAM[addr1];
    end
    
    
    task load_data(
        input [511:0] file_name
    );
        $readmemh(file_name, RAM);
    endtask

endmodule