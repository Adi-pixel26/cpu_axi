`timescale 1ns/1ps

// Self-checking integration test for:
// CPU -> I/D caches -> arbiter -> AXI bridge/master -> AXI memory.
module tb_cached_riscv_cpu;
    reg clk;
    reg reset;

    wire        axi_aresetn;
    wire [31:0] awaddr;
    wire        awvalid;
    wire        awready;
    wire [31:0] wdata;
    wire [3:0]  wstrb;
    wire        wvalid;
    wire        wready;
    wire [1:0]  bresp;
    wire        bvalid;
    wire        bready;
    wire [31:0] araddr;
    wire        arvalid;
    wire        arready;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    wire        rready;
    wire        cache_error;

    integer failures;
    integer index;
    reg saw_cache_error;

    cached_riscv_cpu_top dut (
        .clk(clk),
        .reset(reset),
        .M_AXI_ARESETN(axi_aresetn),
        .M_AXI_AWADDR(awaddr),
        .M_AXI_AWVALID(awvalid),
        .M_AXI_AWREADY(awready),
        .M_AXI_WDATA(wdata),
        .M_AXI_WSTRB(wstrb),
        .M_AXI_WVALID(wvalid),
        .M_AXI_WREADY(wready),
        .M_AXI_BRESP(bresp),
        .M_AXI_BVALID(bvalid),
        .M_AXI_BREADY(bready),
        .M_AXI_ARADDR(araddr),
        .M_AXI_ARVALID(arvalid),
        .M_AXI_ARREADY(arready),
        .M_AXI_RDATA(rdata),
        .M_AXI_RRESP(rresp),
        .M_AXI_RVALID(rvalid),
        .M_AXI_RREADY(rready),
        .cache_error(cache_error)
    );

    axi_slave_memory memory (
        .ACLK(clk),
        .ARESETn(axi_aresetn),
        .AWADDR(awaddr),
        .AWVALID(awvalid),
        .AWREADY(awready),
        .WDATA(wdata),
        .WSTRB(wstrb),
        .WVALID(wvalid),
        .WREADY(wready),
        .BRESP(bresp),
        .BVALID(bvalid),
        .BREADY(bready),
        .ARADDR(araddr),
        .ARVALID(arvalid),
        .ARREADY(arready),
        .RDATA(rdata),
        .RRESP(rresp),
        .RVALID(rvalid),
        .RREADY(rready)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (cache_error)
            saw_cache_error <= 1'b1;
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        failures = 0;
        saw_cache_error = 1'b0;

        // Override the simulation memory contents while reset is asserted.
        #1;
        for (index = 0; index < 1024; index = index + 1)
            memory.RAM[index] = 32'h00000013;

        memory.RAM[0]  = 32'h10000093; // addi x1,x0,256
        memory.RAM[1]  = 32'h05500113; // addi x2,x0,85
        memory.RAM[2]  = 32'h002080a3; // sb x2,1(x1)
        memory.RAM[3]  = 32'h0010c183; // lbu x3,1(x1)
        memory.RAM[4]  = 32'hf8000213; // addi x4,x0,-128
        memory.RAM[5]  = 32'h00408123; // sb x4,2(x1)
        memory.RAM[6]  = 32'h00208283; // lb x5,2(x1)
        memory.RAM[7]  = 32'h0020c303; // lbu x6,2(x1)
        memory.RAM[8]  = 32'h12300393; // addi x7,x0,0x123
        memory.RAM[9]  = 32'h00709023; // sh x7,0(x1)
        memory.RAM[10] = 32'h0000d403; // lhu x8,0(x1)
        memory.RAM[11] = 32'h00009483; // lh x9,0(x1)
        memory.RAM[12] = 32'h0030a223; // sw x3,4(x1)
        memory.RAM[13] = 32'h0040a503; // lw x10,4(x1)
        memory.RAM[14] = 32'h0000006f; // jal x0,0

        // Data line at byte address 0x100.
        for (index = 64; index < 72; index = index + 1)
            memory.RAM[index] = 32'd0;

        #30;
        reset = 1'b0;

        repeat (4000)
            @(posedge clk);

        if (dut.cpu.dp.rf.reg_file_arr[3] !== 32'h00000055) begin
            $display("FAIL LBU: x3=%h", dut.cpu.dp.rf.reg_file_arr[3]);
            failures = failures + 1;
        end

        if (dut.cpu.dp.rf.reg_file_arr[5] !== 32'hffffff80) begin
            $display("FAIL LB sign extension: x5=%h",
                     dut.cpu.dp.rf.reg_file_arr[5]);
            failures = failures + 1;
        end

        if (dut.cpu.dp.rf.reg_file_arr[6] !== 32'h00000080) begin
            $display("FAIL LBU zero extension: x6=%h",
                     dut.cpu.dp.rf.reg_file_arr[6]);
            failures = failures + 1;
        end

        if (dut.cpu.dp.rf.reg_file_arr[8] !== 32'h00000123 ||
            dut.cpu.dp.rf.reg_file_arr[9] !== 32'h00000123) begin
            $display("FAIL halfword load/store: x8=%h x9=%h",
                     dut.cpu.dp.rf.reg_file_arr[8],
                     dut.cpu.dp.rf.reg_file_arr[9]);
            failures = failures + 1;
        end

        if (dut.cpu.dp.rf.reg_file_arr[10] !== 32'h00000055) begin
            $display("FAIL LW/SW: x10=%h", dut.cpu.dp.rf.reg_file_arr[10]);
            failures = failures + 1;
        end

        if (saw_cache_error) begin
            $display("FAIL cache_error asserted");
            failures = failures + 1;
        end

        if (failures == 0)
            $display("PASS cached CPU, load/store adapter, arbiter, and AXI path");
        else
            $display("TOTAL FAILURES: %0d", failures);

        $finish;
    end

endmodule
