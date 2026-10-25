// de10lite_sdram_test_top.v
//
// Temporary hardware-verification top for the DE10-Lite SDRAM path:
//
//   AXI memory tester -> sdram_system_1 -> 16-bit board SDRAM
//
// KEY[0] is active-low reset.  Press KEY[1] once to start.  Reset the board
// before starting a second test.

module de10lite_sdram_test_top (
    input  wire        MAX10_CLK1_50,
    input  wire [1:0]  KEY,

    output wire [12:0] DRAM_ADDR,
    output wire [1:0]  DRAM_BA,
    output wire        DRAM_CAS_N,
    output wire        DRAM_CKE,
    output wire        DRAM_CLK,
    output wire        DRAM_CS_N,
    inout  wire [15:0] DRAM_DQ,
    output wire        DRAM_LDQM,
    output wire        DRAM_RAS_N,
    output wire        DRAM_UDQM,
    output wire        DRAM_WE_N,

    output wire [9:0]  LEDR
);

    wire system_clk;
    wire sdram_clk;
    wire pll_locked;
    wire async_reset_n;
    wire reset_n;
    wire start;

    reg [1:0] reset_sync;
    reg [1:0] start_sync;

    de10lite_sdram_pll clock_generator (
        .inclk0     (MAX10_CLK1_50),
        .areset     (~KEY[0]),
        .system_clk (system_clk),
        .sdram_clk  (sdram_clk),
        .locked     (pll_locked)
    );

    assign async_reset_n = KEY[0] && pll_locked;
    assign reset_n       = reset_sync[1];
    assign start         = start_sync[1];

    // Asynchronous assertion and synchronous release after PLL lock.
    always @(posedge system_clk or negedge async_reset_n) begin
        if (!async_reset_n)
            reset_sync <= 2'b00;
        else
            reset_sync <= {reset_sync[0], 1'b1};
    end

    // Synchronize the active-low start pushbutton into system_clk.
    always @(posedge system_clk or negedge reset_n) begin
        if (!reset_n)
            start_sync <= 2'b00;
        else
            start_sync <= {start_sync[0], ~KEY[1]};
    end

    wire [31:0] axi_awaddr;
    wire        axi_awvalid;
    wire        axi_awready;
    wire [31:0] axi_wdata;
    wire [3:0]  axi_wstrb;
    wire        axi_wvalid;
    wire        axi_wready;
    wire [1:0]  axi_bresp;
    wire        axi_bvalid;
    wire        axi_bready;
    wire [31:0] axi_araddr;
    wire        axi_arvalid;
    wire        axi_arready;
    wire [31:0] axi_rdata;
    wire [1:0]  axi_rresp;
    wire        axi_rlast;
    wire        axi_rvalid;
    wire        axi_rready;

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

    // Four 4-KiB regions are tested at 0, 16, 32 and 48 MiB.  This is quick
    // while still exercising the SDRAM's upper address and bank mapping.
    axi_sdram_memtest #(
        .WORDS_PER_REGION (1024),
        .REGION_COUNT     (4),
        .REGION_STRIDE    (32'h0100_0000),
        .PATTERN_COUNT    (6)
    ) tester (
        .clk              (system_clk),
        .reset_n          (reset_n),
        .start            (start),

        .m_axi_awaddr     (axi_awaddr),
        .m_axi_awvalid    (axi_awvalid),
        .m_axi_awready    (axi_awready),
        .m_axi_wdata      (axi_wdata),
        .m_axi_wstrb      (axi_wstrb),
        .m_axi_wvalid     (axi_wvalid),
        .m_axi_wready     (axi_wready),
        .m_axi_bresp      (axi_bresp),
        .m_axi_bvalid     (axi_bvalid),
        .m_axi_bready     (axi_bready),
        .m_axi_araddr     (axi_araddr),
        .m_axi_arvalid    (axi_arvalid),
        .m_axi_arready    (axi_arready),
        .m_axi_rdata      (axi_rdata),
        .m_axi_rresp      (axi_rresp),
        .m_axi_rlast      (axi_rlast),
        .m_axi_rvalid     (axi_rvalid),
        .m_axi_rready     (axi_rready),

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

    sdram_system_1 memory_system (
        .clk_clk            (system_clk),
        .reset_reset_n      (reset_n),

        .cpu_axi_awid        (1'b0),
        .cpu_axi_awaddr      (axi_awaddr),
        .cpu_axi_awlen       (8'd0),
        .cpu_axi_awsize      (3'b010),
        .cpu_axi_awburst     (2'b01),
        .cpu_axi_awlock      (1'b0),
        .cpu_axi_awcache     (4'b0000),
        .cpu_axi_awprot      (3'b000),
        .cpu_axi_awqos       (4'b0000),
        .cpu_axi_awregion    (4'b0000),
        .cpu_axi_awvalid     (axi_awvalid),
        .cpu_axi_awready     (axi_awready),

        .cpu_axi_wdata       (axi_wdata),
        .cpu_axi_wstrb       (axi_wstrb),
        .cpu_axi_wlast       (1'b1),
        .cpu_axi_wvalid      (axi_wvalid),
        .cpu_axi_wready      (axi_wready),

        .cpu_axi_bid         (),
        .cpu_axi_bresp       (axi_bresp),
        .cpu_axi_bvalid      (axi_bvalid),
        .cpu_axi_bready      (axi_bready),

        .cpu_axi_arid        (1'b0),
        .cpu_axi_araddr      (axi_araddr),
        .cpu_axi_arlen       (8'd0),
        .cpu_axi_arsize      (3'b010),
        .cpu_axi_arburst     (2'b01),
        .cpu_axi_arlock      (1'b0),
        .cpu_axi_arcache     (4'b0000),
        .cpu_axi_arprot      (3'b000),
        .cpu_axi_arqos       (4'b0000),
        .cpu_axi_arregion    (4'b0000),
        .cpu_axi_arvalid     (axi_arvalid),
        .cpu_axi_arready     (axi_arready),

        .cpu_axi_rid         (),
        .cpu_axi_rdata       (axi_rdata),
        .cpu_axi_rresp       (axi_rresp),
        .cpu_axi_rlast       (axi_rlast),
        .cpu_axi_rvalid      (axi_rvalid),
        .cpu_axi_rready      (axi_rready),

        .sdram_wire_addr     (DRAM_ADDR),
        .sdram_wire_ba       (DRAM_BA),
        .sdram_wire_cas_n    (DRAM_CAS_N),
        .sdram_wire_cke      (DRAM_CKE),
        .sdram_wire_cs_n     (DRAM_CS_N),
        .sdram_wire_dq       (DRAM_DQ),
        .sdram_wire_dqm      ({DRAM_UDQM, DRAM_LDQM}),
        .sdram_wire_ras_n    (DRAM_RAS_N),
        .sdram_wire_we_n     (DRAM_WE_N)
    );

    assign DRAM_CLK = sdram_clk;

    // LEDR[0]    busy
    // LEDR[1]    pass
    // LEDR[2]    fail
    // LEDR[3]    done
    // LEDR[6:4]  current pattern
    // LEDR[8:7]  current region
    assign LEDR = {1'b0, current_region[1:0], current_pattern,
                   done, fail, pass, busy};

endmodule
