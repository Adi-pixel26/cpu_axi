`timescale 1ns/1ps

module tb_custom();

    reg clk;
    reg reset;
    
    // Wires to monitor the CPU
    wire        MemWrite;
    wire [31:0] WriteData;
    wire [31:0] DataAdr;
    wire [31:0] PC;
    wire [31:0] Result;

    // Instantiate your motherboard
    t1_riscv_cpu uut (
        .clk(clk),
        .reset(reset),
        .Ext_MemWrite(1'b0), // Not using external write
        .Ext_WriteData(32'd0),
        .Ext_DataAdr(32'd0),
        .MemWrite(MemWrite),
        .WriteData(WriteData),
        .DataAdr(DataAdr),
        .ReadData(),
        .PC(PC),
        .Result(Result)
    );

    // Generate a 10ns Clock
    always #5 clk = ~clk;

    initial begin
        // 1. Initialize and hit the Reset button
        clk = 0;
        reset = 1;
        #20; 
        
        // 2. Release Reset and let the CPU run!
        reset = 0;
        
        // 3. Fail-safe timeout (Don't run forever)
        #5000;
        $display("\n[FAILED] Simulation timed out! The CPU never wrote the correct answer.");
        $stop;
    end

    // 4. The "Security Camera" (Self-Checking Logic)
    always @(negedge clk) begin
        // DEBUG PRINT
        $display("Time=%0t | rst=%b | state=%b | stall=%b | EN=%b | PC=%h", 
                 $time, reset, uut.rvcpu.state, uut.rvcpu.stall, uut.rvcpu.dp.pcreg.EN, PC);
                 
        if (MemWrite == 1) begin
            // The CPU is trying to write to memory. Let's check what it is writing!
            if (DataAdr == 32'd100 && WriteData == 32'd25) begin
                $display("\n==================================================");
                $display("[SUCCESS] CPU IS PERFECT!");
                $display("The CPU successfully calculated 10 + 15 = 25 and saved it!");
                $display("AXI Master and AXI Slave are working perfectly together.");
                $display("==================================================\n");
                $stop;
            end else begin
                $display("[WARNING] CPU wrote %d to address %d (Expected 25 to address 100)", WriteData, DataAdr);
            end
        end
    end

endmodule