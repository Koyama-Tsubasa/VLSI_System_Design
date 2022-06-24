`timescale 1ns/1ps
`define CYCLE 3.16
`define END_CYCLES 2000000
module tb_DnCNN();

    

    // ===== System Signals =====
    reg clk;
    integer i, cycle_count;
    reg start_count;


    // ===== SRAM Signals =====
    wire [ 3:0] sram_weight_wea0;
    wire [15:0] sram_weight_addr0;
    wire [31:0] sram_weight_wdata0;
    wire [31:0] sram_weight_rdata0;
    wire [ 3:0] sram_weight_wea1;
    wire [15:0] sram_weight_addr1;
    wire [31:0] sram_weight_wdata1;
    wire [31:0] sram_weight_rdata1;
    
    wire [ 3:0] sram_act_wea0;
    wire [15:0] sram_act_addr0;
    wire [31:0] sram_act_wdata0;
    wire [31:0] sram_act_rdata0;
    wire [ 3:0] sram_act_wea1;
    wire [15:0] sram_act_addr1;
    wire [31:0] sram_act_wdata1;
    wire [31:0] sram_act_rdata1;

    // ===== Golden =====
    reg [31:0] golden [0:32767];

    // ===== Lenet Signals =====
    reg rst_n;
    reg compute_start;
    wire compute_finish;
    
    reg [31:0] scale_C1;
    reg [31:0] scale_C2;
    reg [31:0] scale_C3;
    reg [31:0] scale_C4;
    reg [31:0] scale_C5;
    reg [31:0] scale_C6;
    reg [31:0] scale_C7;

    // ===== Module instantiation =====
    DnCNN DnCNN_inst(
        .clk(clk),
        .rst_n(rst_n),

        .compute_start(compute_start),
        .compute_finish(compute_finish),

        // Quantization scale
        .scale_C1(scale_C1),
        .scale_C2(scale_C2),
        .scale_C3(scale_C3),
        .scale_C4(scale_C4),
        .scale_C5(scale_C5),
        .scale_C6(scale_C6),
        .scale_C7(scale_C7),


        // weight sram, single port
        .sram_weight_wea0(sram_weight_wea0),
        .sram_weight_addr0(sram_weight_addr0),
        .sram_weight_wdata0(sram_weight_wdata0),
        .sram_weight_rdata0(sram_weight_rdata0),
        .sram_weight_wea1(sram_weight_wea1),
        .sram_weight_addr1(sram_weight_addr1),
        .sram_weight_wdata1(sram_weight_wdata1),
        .sram_weight_rdata1(sram_weight_rdata1),

        // Output sram,dual port
        .sram_act_wea0(sram_act_wea0),
        .sram_act_addr0(sram_act_addr0),
        .sram_act_wdata0(sram_act_wdata0),
        .sram_act_rdata0(sram_act_rdata0),
        .sram_act_wea1(sram_act_wea1),
        .sram_act_addr1(sram_act_addr1),
        .sram_act_wdata1(sram_act_wdata1),
        .sram_act_rdata1(sram_act_rdata1)
    );

    SRAM_weight_4096x32b weight_sram( 
        .clk(clk),
        .wea0(sram_weight_wea0),
        .addr0(sram_weight_addr0),
        .wdata0(sram_weight_wdata0),
        .rdata0(sram_weight_rdata0),
        .wea1(sram_weight_wea1),
        .addr1(sram_weight_addr1),
        .wdata1(sram_weight_wdata1),
        .rdata1(sram_weight_rdata1)
    );
    
    SRAM_activation_32768x32b act_sram( 
        .clk(clk),
        .wea0(sram_act_wea0),
        .addr0(sram_act_addr0),
        .wdata0(sram_act_wdata0),
        .rdata0(sram_act_rdata0),
        .wea1(sram_act_wea1),
        .addr1(sram_act_addr1),
        .wdata1(sram_act_wdata1),
        .rdata1(sram_act_rdata1)
    );



    // ===== Load data ===== //
    initial begin
        weight_sram.load_data("../../patterns/dncnn/weights/weights.csv");
        act_sram.load_data("../../patterns/dncnn//patterns/image00.csv");
        $readmemh("../../patterns/dncnn//patterns/golden00.csv", golden);

    end


    // ===== System reset ===== //
    initial begin
        clk = 0;
        rst_n = 1;
        compute_start = 0;
        cycle_count = 0;
    end
    
    // ===== Cycle count ===== //
    initial begin
        wait(compute_start == 1);
        start_count = 1;
        wait(compute_finish == 1);
        start_count = 0;
    end

    always @(posedge clk) begin
        if(start_count)
            cycle_count <= cycle_count + 1;
    end 
   
    // ===== Time Exceed Abortion ===== //
    initial begin
        #(`CYCLE*`END_CYCLES);
        $display("\n========================================================");
        $display("You have exceeded the cycle count limit.");
        $display("Simulation abort");
        $display("========================================================");
        $finish;    
    end

    // ===== Clk fliping ===== //
    always #(`CYCLE/2) begin
        clk = ~clk;
    end 

    // ===== Set simulation info ===== //
    initial begin
    `ifdef GATESIM
        $fsdbDumpfile("DnCNN_syn.fsdb");
        $fsdbDumpvars;
        $sdf_annotate("../syn/netlist/DnCNN_syn.sdf", DnCNN_inst);
	`else
        `ifdef POSTSIM
            $fsdbDumpfile("DnCNN_post.fsdb");
            $fsdbDumpvars;
            $sdf_annotate("../apr/netlist/CHIP.sdf", DnCNN_inst);
        `else
            // $fsdbDumpfile("DnCNN.fsdb");
            // $fsdbDumpvars(0,"+mda");
            $dumpfile("DnCNN.vcd");
            $dumpvars("+mda");
            // $dumpvars("+all");
        `endif
    `endif
    end
        

    // ===== Simulating  ===== //
    initial begin

        scale_C1 = 149;
        scale_C2 = 119;
        scale_C3 =  81;
        scale_C4 = 157;
        scale_C5 = 184;
        scale_C6 = 279;
        scale_C7 = 225;

        #(`CYCLE*100);
        $display("Reset System");
        @(negedge clk);
        rst_n = 1'b0;
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        $display("Compute start");
        @(negedge clk);
        compute_start = 1'b1;
        @(negedge clk);
        compute_start = 1'b0;

        wait(compute_finish == 1);
        $display("Compute finished, start validating result...");

        validate();

        $display("Simulation finish");
        $finish;
    end

    integer errors, total_errors;
    task validate; begin
        // Input Image
        
        total_errors = 0;
        $display("=====================");

        errors = 0;
        for(i=0 ; i<256 ; i=i+1)
            if(golden[i] !== act_sram.RAM[i]) begin
                $display("[ERROR] Image Result:%8h Golden:%8h", act_sram.RAM[i], golden[i]);
                errors = errors + 1;
            end
            else begin
                // $display("[CORRECT]   [%d] Image Result:%8h Golden:%8h", i, act_sram.RAM[i], golden[i]);
            end
        if(errors == 0)
            $display("Image             [PASS]");
        else
            $display("Image             [FAIL]");
        total_errors = total_errors + errors;
            
        errors = 0;
        for(i=256 ; i<4352 ; i=i+1)
            if(golden[i] !== act_sram.RAM[i]) begin
                $display("[ERROR]   [%d] Conv1 Result:%8h Golden:%8h", i-256, act_sram.RAM[i], golden[i]);
                errors = errors + 1;
            end
            else begin
                // $display("[CORRECT]   [%d] Conv1 Result:%8h Golden:%8h", i-256, act_sram.RAM[i], golden[i]);
            end
        if(errors == 0)
            $display("Conv 1 activation [PASS]");
        else
            $display("Conv 1 activation [FAIL]");
        total_errors = total_errors + errors;
            
        errors = 0;
        for(i=4352 ; i<8448 ; i=i+1)
            if(golden[i] !== act_sram.RAM[i]) begin
                $display("[ERROR]     [%d] Conv2 Result:%8h Golden:%8h", i-4352, act_sram.RAM[i], golden[i]);
                errors = errors + 1;
            end
            else begin
                // $display("[CORRECT]   [%d] Conv2 Result:%8h Golden:%8h", i-4352, act_sram.RAM[i], golden[i]);
            end
        if(errors == 0)
            $display("Conv 2 activation [PASS]");
        else
            $display("Conv 2 activation [FAIL]");
        total_errors = total_errors + errors;

        errors = 0;
        for(i=8448 ; i<12544 ; i=i+1)
            if(golden[i] !== act_sram.RAM[i]) begin
                $display("[ERROR]     [%d] Conv3 Result:%8h Golden:%8h", i-8448, act_sram.RAM[i], golden[i]);
                errors = errors + 1;
            end
            else begin
                //$display("[CORRECT]   [%d] Conv3 Result:%8h Golden:%8h", i-8448, act_sram.RAM[i], golden[i]);
            end
        if(errors == 0)
            $display("Conv 3 activation [PASS]");
        else
            $display("Conv 3 activation [FAIL]");
        total_errors = total_errors + errors;

        errors = 0;
        for(i=12544 ; i<16640 ; i=i+1)
            if(golden[i] !== act_sram.RAM[i]) begin
                $display("[ERROR]     [%d] Conv4 Result:%8h Golden:%8h", i-12544, act_sram.RAM[i], golden[i]);
                errors = errors + 1;
            end
            else begin
                //$display("[CORRECT]   [%d] Conv4 Result:%8h Golden:%8h", i-12544, act_sram.RAM[i], golden[i]);
            end
        if(errors == 0)
            $display("Conv 4 activation [PASS]");
        else
            $display("Conv 4 activation [FAIL]");
        total_errors = total_errors + errors;
        
        errors = 0;
        for(i=16640 ; i<20736 ; i=i+1)
            if(golden[i] !== act_sram.RAM[i]) begin
                $display("[ERROR]     [%d] Conv5 Result:%8h Golden:%8h", i-16640, act_sram.RAM[i], golden[i]);
                errors = errors + 1;
            end
            else begin
                //$display("[CORRECT]   [%d] Conv5 Result:%8h Golden:%8h", i-16640, act_sram.RAM[i], golden[i]);
            end
        if(errors == 0)
            $display("Conv 5 activation [PASS]");
        else
            $display("Conv 5 activation [FAIL]");
        total_errors = total_errors + errors;

        errors = 0;
        for(i=20736 ; i<24832 ; i=i+1)
            if(golden[i] !== act_sram.RAM[i]) begin
                $display("[ERROR]     [%d] Conv6 Result:%8h Golden:%8h", i-20736, act_sram.RAM[i], golden[i]);
                errors = errors + 1;
            end
            else begin
                //$display("[CORRECT]   [%d] Conv6 Result:%8h Golden:%8h", i-20736, act_sram.RAM[i], golden[i]);
            end
        if(errors == 0)
            $display("Conv 6 activation [PASS]");
        else
            $display("Conv 6 activation [FAIL]");
        total_errors = total_errors + errors;

        errors = 0;
        for(i=24832 ; i<25088 ; i=i+1)
            if(golden[i] !== act_sram.RAM[i]) begin
                $display("[ERROR]     [%d] Conv7 Result:%8h Golden:%8h", i-24832, act_sram.RAM[i], golden[i]);
                errors = errors + 1;
            end
            else begin
                // $display("[CORRECT]   [%d] Conv7 Result:%8h Golden:%8h", i-24832, act_sram.RAM[i], golden[i]);
            end
        if(errors == 0)
            $display("Conv 7 activation [PASS]");
        else
            $display("Conv 7 activation [FAIL]");
        total_errors = total_errors + errors;
        
        if(total_errors == 0)
            $display(">>> Congratulation! All result are correct");
        else
            $display(">>> There are %d errors QQ", total_errors);
            
    `ifdef GATESIM
        $display("  [Pre-layout gate-level simulation]");
	`else
        `ifdef POSTSIM
            $display("  [Post-layout gate-level simulation]");
        `else
            $display("  [RTL simulation]");
        `endif
    `endif
        $display("Clock Period: %.2f ns,Total cycle count: %d cycles", `CYCLE, cycle_count);
        $display("=====================");
    end
    endtask



endmodule
