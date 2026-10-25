`timescale 1ns/1ps

// Self-checking integration test:
// AXI tester -> generated sdram_system_1 -> simulated 16-bit SDRAM pins.
module tb_sdram_system_1;

    reg clk;
    reg reset_n;
    reg start;

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

    wire        busy;
    wire        done;
    wire        pass;
    wire        fail;
    wire [2:0]  fail_code;
    wire [31:0] fail_address;
    wire [31:0] fail_expected;
    wire [31:0] fail_actual;
    wire [2:0]  current_pattern;
    wire [7:0]  current_region;
    wire [31:0] current_address;

    wire [12:0] dram_addr;
    wire [1:0]  dram_ba;
    wire        dram_cas_n;
    wire        dram_cke;
    wire        dram_cs_n;
    wire [15:0] dram_dq;
    wire [1:0]  dram_dqm;
    wire        dram_ras_n;
    wire        dram_we_n;

    axi_sdram_memtest #(
        .WORDS_PER_REGION (64),
        .REGION_COUNT     (4),
        .REGION_STRIDE    (32'h0100_0000),
        .PATTERN_COUNT    (6)
    ) tester (
        .clk              (clk),
        .reset_n          (reset_n),
        .start            (start),
        .m_axi_awaddr     (awaddr),
        .m_axi_awvalid    (awvalid),
        .m_axi_awready    (awready),
        .m_axi_wdata      (wdata),
        .m_axi_wstrb      (wstrb),
        .m_axi_wvalid     (wvalid),
        .m_axi_wready     (wready),
        .m_axi_bresp      (bresp),
        .m_axi_bvalid     (bvalid),
        .m_axi_bready     (bready),
        .m_axi_araddr     (araddr),
        .m_axi_arvalid    (arvalid),
        .m_axi_arready    (arready),
        .m_axi_rdata      (rdata),
        .m_axi_rresp      (rresp),
        .m_axi_rlast      (rlast),
        .m_axi_rvalid     (rvalid),
        .m_axi_rready     (rready),
        .busy             (busy),
        .done             (done),
        .pass             (pass),
        .fail             (fail),
        .fail_code        (fail_code),
        .fail_address     (fail_address),
        .fail_expected    (fail_expected),
        .fail_actual      (fail_actual),
        .current_pattern  (current_pattern),
        .current_region   (current_region),
        .current_address  (current_address)
    );

    sdram_system_1 dut (
        .clk_clk            (clk),
        .reset_reset_n      (reset_n),
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

    initial begin
        clk     = 1'b0;
        reset_n = 1'b0;
        start   = 1'b0;

        repeat (10) @(posedge clk);
        reset_n <= 1'b1;
        repeat (10) @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;

        wait (done);
        @(posedge clk);

        if (pass && !fail)
            $display("PASS sdram_system_1 AXI bridge, width adapter, controller and SDRAM pins");
        else begin
            $display("FAIL sdram_system_1 code=%0d addr=%h expected=%h actual=%h",
                     fail_code, fail_address, fail_expected, fail_actual);
            $stop;
        end

        repeat (5) @(posedge clk);
        $finish;
    end

    initial begin
        #10000000;
        $display("FAIL sdram_system_1 integration timeout");
        $stop;
    end

endmodule
