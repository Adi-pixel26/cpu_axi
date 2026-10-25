`timescale 1ns/1ps

// End-to-end self-checking test:
// CPU -> caches -> arbiter -> custom AXI master -> sdram_system_1 -> SDRAM model.
module tb_cpu_sdram_system_1;

    reg clk;
    reg reset;

    wire reset_n;
    wire axi_aresetn;

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
    wire        rlast;
    wire        rvalid;
    wire        rready;
    wire        cache_error;

    wire [12:0] dram_addr;
    wire [1:0]  dram_ba;
    wire        dram_cas_n;
    wire        dram_cke;
    wire        dram_cs_n;
    wire [15:0] dram_dq;
    wire [1:0]  dram_dqm;
    wire        dram_ras_n;
    wire        dram_we_n;

    integer failures;
    integer index;
    reg saw_cache_error;

    assign reset_n = ~reset;

    cached_riscv_cpu_top cpu_dut (
        .clk            (clk),
        .reset          (reset),
        .M_AXI_ARESETN  (axi_aresetn),
        .M_AXI_AWADDR   (awaddr),
        .M_AXI_AWVALID  (awvalid),
        .M_AXI_AWREADY  (awready),
        .M_AXI_WDATA    (wdata),
        .M_AXI_WSTRB    (wstrb),
        .M_AXI_WVALID   (wvalid),
        .M_AXI_WREADY   (wready),
        .M_AXI_BRESP    (bresp),
        .M_AXI_BVALID   (bvalid),
        .M_AXI_BREADY   (bready),
        .M_AXI_ARADDR   (araddr),
        .M_AXI_ARVALID  (arvalid),
        .M_AXI_ARREADY  (arready),
        .M_AXI_RDATA    (rdata),
        .M_AXI_RRESP    (rresp),
        .M_AXI_RVALID   (rvalid),
        .M_AXI_RREADY   (rready),
        .cache_error    (cache_error)
    );

    sdram_system_1 memory_system (
        .clk_clk            (clk),
        .reset_reset_n      (axi_aresetn),
        .cpu_axi_awid        (1'b0),
        .cpu_axi_awaddr      (awaddr),
        .cpu_axi_awlen       (8'd0),
        .cpu_axi_awsize      (3'b010),
        .cpu_axi_awburst     (2'b01),
        .cpu_axi_awlock      (1'b0),
        .cpu_axi_awcache     (4'b0000),
        .cpu_axi_awprot      (3'b000),
        .cpu_axi_awqos       (4'b0000),
        .cpu_axi_awregion    (4'b0000),
        .cpu_axi_awvalid     (awvalid),
        .cpu_axi_awready     (awready),
        .cpu_axi_wdata       (wdata),
        .cpu_axi_wstrb       (wstrb),
        .cpu_axi_wlast       (1'b1),
        .cpu_axi_wvalid      (wvalid),
        .cpu_axi_wready      (wready),
        .cpu_axi_bid         (),
        .cpu_axi_bresp       (bresp),
        .cpu_axi_bvalid      (bvalid),
        .cpu_axi_bready      (bready),
        .cpu_axi_arid        (1'b0),
        .cpu_axi_araddr      (araddr),
        .cpu_axi_arlen       (8'd0),
        .cpu_axi_arsize      (3'b010),
        .cpu_axi_arburst     (2'b01),
        .cpu_axi_arlock      (1'b0),
        .cpu_axi_arcache     (4'b0000),
        .cpu_axi_arprot      (3'b000),
        .cpu_axi_arqos       (4'b0000),
        .cpu_axi_arregion    (4'b0000),
        .cpu_axi_arvalid     (arvalid),
        .cpu_axi_arready     (arready),
        .cpu_axi_rid         (),
        .cpu_axi_rdata       (rdata),
        .cpu_axi_rresp       (rresp),
        .cpu_axi_rlast       (rlast),
        .cpu_axi_rvalid      (rvalid),
        .cpu_axi_rready      (rready),
        .sdram_wire_addr     (dram_addr),
        .sdram_wire_ba       (dram_ba),
        .sdram_wire_cas_n    (dram_cas_n),
        .sdram_wire_cke      (dram_cke),
        .sdram_wire_cs_n     (dram_cs_n),
        .sdram_wire_dq       (dram_dq),
        .sdram_wire_dqm      (dram_dqm),
        .sdram_wire_ras_n    (dram_ras_n),
        .sdram_wire_we_n     (dram_we_n)
    );

    sdram_model_16_sim sdram (
        .clk   (clk),
        .cke   (dram_cke),
        .cs_n  (dram_cs_n),
        .ras_n (dram_ras_n),
        .cas_n (dram_cas_n),
        .we_n  (dram_we_n),
        .addr  (dram_addr),
        .ba    (dram_ba),
        .dq    (dram_dq),
        .dqm   (dram_dqm)
    );

    always #10 clk = ~clk; // 50 MHz

    always @(posedge clk) begin
        if (cache_error)
            saw_cache_error <= 1'b1;
    end

    initial begin
        clk             = 1'b0;
        reset           = 1'b1;
        failures        = 0;
        saw_cache_error = 1'b0;

        // Wait until the SDRAM model's own initial block has completed, then
        // preload the same RV32I program used by tb_cached_riscv_cpu.
        #1;
        sdram.write_word(32'h0000_0000, 32'h10000093); // addi x1,x0,256
        sdram.write_word(32'h0000_0004, 32'h05500113); // addi x2,x0,85
        sdram.write_word(32'h0000_0008, 32'h002080a3); // sb x2,1(x1)
        sdram.write_word(32'h0000_000c, 32'h0010c183); // lbu x3,1(x1)
        sdram.write_word(32'h0000_0010, 32'hf8000213); // addi x4,x0,-128
        sdram.write_word(32'h0000_0014, 32'h00408123); // sb x4,2(x1)
        sdram.write_word(32'h0000_0018, 32'h00208283); // lb x5,2(x1)
        sdram.write_word(32'h0000_001c, 32'h0020c303); // lbu x6,2(x1)
        sdram.write_word(32'h0000_0020, 32'h12300393); // addi x7,x0,0x123
        sdram.write_word(32'h0000_0024, 32'h00709023); // sh x7,0(x1)
        sdram.write_word(32'h0000_0028, 32'h0000d403); // lhu x8,0(x1)
        sdram.write_word(32'h0000_002c, 32'h00009483); // lh x9,0(x1)
        sdram.write_word(32'h0000_0030, 32'h0030a223); // sw x3,4(x1)
        sdram.write_word(32'h0000_0034, 32'h0040a503); // lw x10,4(x1)
        sdram.write_word(32'h0000_0038, 32'h0000006f); // jal x0,0

        // Initialize the complete data cache line at byte address 0x100.
        for (index = 0; index < 8; index = index + 1)
            sdram.write_word(32'h0000_0100 + (index * 4), 32'd0);

        repeat (10) @(posedge clk);
        reset <= 1'b0;

        // Includes the SDRAM controller's 100-us initialization interval.
        repeat (50000) @(posedge clk);

        if (cpu_dut.cpu.dp.rf.reg_file_arr[3] !== 32'h00000055) begin
            $display("FAIL CPU/Qsys LBU: x3=%h",
                     cpu_dut.cpu.dp.rf.reg_file_arr[3]);
            failures = failures + 1;
        end

        if (cpu_dut.cpu.dp.rf.reg_file_arr[5] !== 32'hffffff80) begin
            $display("FAIL CPU/Qsys LB sign extension: x5=%h",
                     cpu_dut.cpu.dp.rf.reg_file_arr[5]);
            failures = failures + 1;
        end

        if (cpu_dut.cpu.dp.rf.reg_file_arr[6] !== 32'h00000080) begin
            $display("FAIL CPU/Qsys LBU zero extension: x6=%h",
                     cpu_dut.cpu.dp.rf.reg_file_arr[6]);
            failures = failures + 1;
        end

        if ((cpu_dut.cpu.dp.rf.reg_file_arr[8] !== 32'h00000123) ||
            (cpu_dut.cpu.dp.rf.reg_file_arr[9] !== 32'h00000123)) begin
            $display("FAIL CPU/Qsys halfword: x8=%h x9=%h",
                     cpu_dut.cpu.dp.rf.reg_file_arr[8],
                     cpu_dut.cpu.dp.rf.reg_file_arr[9]);
            failures = failures + 1;
        end

        if (cpu_dut.cpu.dp.rf.reg_file_arr[10] !== 32'h00000055) begin
            $display("FAIL CPU/Qsys LW/SW: x10=%h",
                     cpu_dut.cpu.dp.rf.reg_file_arr[10]);
            failures = failures + 1;
        end

        if (saw_cache_error) begin
            $display("FAIL CPU/Qsys cache_error asserted");
            failures = failures + 1;
        end

        if (failures == 0)
            $display("PASS CPU, caches, AXI, sdram_system_1 and SDRAM model");
        else begin
            $display("FAIL CPU/Qsys total failures: %0d", failures);
            $stop;
        end

        repeat (5) @(posedge clk);
        $finish;
    end

    initial begin
        #2000000;
        $display("FAIL CPU/Qsys integration timeout");
        $stop;
    end

endmodule
