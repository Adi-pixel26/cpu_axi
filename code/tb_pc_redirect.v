`timescale 1ns/1ps

// Checks the PC-critical forwarding paths: adjacent ADDI -> JALR and
// ADDI -> BEQ. The JALR target is intentionally odd before bit-zero clearing.
module tb_pc_redirect;
    reg clk = 1'b0;
    reg reset = 1'b1;
    wire [31:0] pc;
    wire [31:0] instruction;
    reg [31:0] rom [0:63];
    integer i;
    integer failures;

    assign instruction = rom[pc[7:2]];
    always #10 clk = ~clk; // 50 MHz

    riscv_cpu dut (
        .clk(clk), .reset(reset),
        .ICacheStall(1'b0), .DCacheStall(1'b0),
        .PC(pc), .Instr(instruction),
        .MemWrite(), .MemRead(), .Mem_WrAddr(), .Mem_WrData(),
        .ReadData(32'd0), .Result(), .funct3(),
        .PCW(), .ALUResultW(), .WriteDataW()
    );

    initial begin
        failures = 0;
        for (i = 0; i < 64; i = i + 1)
            rom[i] = 32'h00000013; // nop

        rom[0]  = 32'h01800093; // 0x00 addi x1,x0,0x18
        rom[1]  = 32'h001082e7; // 0x04 jalr x5,1(x1) -> 0x18
        rom[2]  = 32'h05500513; // 0x08 wrong-path addi x10,x0,0x55
        rom[3]  = 32'h06600593; // 0x0c wrong-path addi x11,x0,0x66
        rom[6]  = 32'h00700113; // 0x18 addi x2,x0,7
        rom[7]  = 32'h00700193; // 0x1c addi x3,x0,7
        rom[8]  = 32'h00310663; // 0x20 beq x2,x3,+12 -> 0x2c
        rom[9]  = 32'h07700613; // 0x24 wrong-path addi x12,x0,0x77
        rom[10] = 32'h08800693; // 0x28 wrong-path addi x13,x0,0x88
        rom[11] = 32'h03300213; // 0x2c addi x4,x0,0x33
        rom[12] = 32'h0000006f; // 0x30 jal x0,0

        repeat (3) @(posedge clk);
        reset <= 1'b0;
        repeat (50) @(posedge clk);
        #1;

        if (dut.dp.rf.reg_file_arr[1] !== 32'h00000018) failures = failures + 1;
        if (dut.dp.rf.reg_file_arr[5] !== 32'h00000008) failures = failures + 1;
        if (dut.dp.rf.reg_file_arr[2] !== 32'h00000007) failures = failures + 1;
        if (dut.dp.rf.reg_file_arr[3] !== 32'h00000007) failures = failures + 1;
        if (dut.dp.rf.reg_file_arr[4] !== 32'h00000033) failures = failures + 1;
        if (dut.dp.rf.reg_file_arr[10] !== 32'h00000000) failures = failures + 1;
        if (dut.dp.rf.reg_file_arr[11] !== 32'h00000000) failures = failures + 1;
        if (dut.dp.rf.reg_file_arr[12] !== 32'h00000000) failures = failures + 1;
        if (dut.dp.rf.reg_file_arr[13] !== 32'h00000000) failures = failures + 1;

        if (failures == 0)
            $display("PASS PC forwarding, JALR target/link, BEQ, and flush at 50 MHz");
        else
            $display("FAIL PC redirect: %0d register mismatches, pc=%h x4=%h x5=%h",
                     failures, pc, dut.dp.rf.reg_file_arr[4], dut.dp.rf.reg_file_arr[5]);
        $finish;
    end
endmodule
