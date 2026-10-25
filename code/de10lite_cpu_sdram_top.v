module de10lite_cpu_sdram_top (
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

    /*
     * DE10-Lite pushbuttons are active-low.
     * Pressing KEY[0] resets the CPU and memory system.
     */
    wire system_clk;
    wire sdram_clk;
    wire pll_locked;
    wire async_reset_n;
    wire board_reset_n;
    wire reset;
    reg [1:0] reset_sync;

    de10lite_sdram_pll clock_generator (
        .inclk0     (MAX10_CLK1_50),
        .areset     (~KEY[0]),
        .system_clk (system_clk),
        .sdram_clk  (sdram_clk),
        .locked     (pll_locked)
    );

    assign async_reset_n = KEY[0] && pll_locked;
    assign board_reset_n = reset_sync[1];
    assign reset         = ~board_reset_n;

    always @(posedge system_clk or negedge async_reset_n) begin
        if (!async_reset_n)
            reset_sync <= 2'b00;
        else
            reset_sync <= {reset_sync[0], 1'b1};
    end

    /*
     * AXI connections between cached_riscv_cpu_top and
     * the exported AXI subordinate interface in sdram_system_1.
     */
    wire        axi_aresetn;

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
    wire        axi_rvalid;
    wire        axi_rready;

    wire        cache_error;

    /*
     * CPU, caches, cache arbiter and custom AXI master.
     */
    cached_riscv_cpu_top cpu_subsystem (
        .clk            (system_clk),
        .reset          (reset),

        .M_AXI_ARESETN  (axi_aresetn),

        .M_AXI_AWADDR   (axi_awaddr),
        .M_AXI_AWVALID  (axi_awvalid),
        .M_AXI_AWREADY  (axi_awready),

        .M_AXI_WDATA    (axi_wdata),
        .M_AXI_WSTRB    (axi_wstrb),
        .M_AXI_WVALID   (axi_wvalid),
        .M_AXI_WREADY   (axi_wready),

        .M_AXI_BRESP    (axi_bresp),
        .M_AXI_BVALID   (axi_bvalid),
        .M_AXI_BREADY   (axi_bready),

        .M_AXI_ARADDR   (axi_araddr),
        .M_AXI_ARVALID  (axi_arvalid),
        .M_AXI_ARREADY  (axi_arready),

        .M_AXI_RDATA    (axi_rdata),
        .M_AXI_RRESP    (axi_rresp),
        .M_AXI_RVALID   (axi_rvalid),
        .M_AXI_RREADY   (axi_rready),

        .cache_error    (cache_error)
    );

    /*
     * Generated Platform Designer system containing:
     *
     *   AXI Bridge
     *   AXI-to-Avalon interconnect
     *   32-bit to 16-bit width adaptation
     *   SDRAM controller
     */
    sdram_system_1 memory_system (
        .clk_clk            (system_clk),
        .reset_reset_n      (axi_aresetn),

        /*
         * Single-beat AXI4 write-address channel.
         */
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

        /*
         * AXI write-data channel.
         */
        .cpu_axi_wdata       (axi_wdata),
        .cpu_axi_wstrb       (axi_wstrb),
        .cpu_axi_wlast       (1'b1),
        .cpu_axi_wvalid      (axi_wvalid),
        .cpu_axi_wready      (axi_wready),

        /*
         * AXI write-response channel.
         */
        .cpu_axi_bid         (),
        .cpu_axi_bresp       (axi_bresp),
        .cpu_axi_bvalid      (axi_bvalid),
        .cpu_axi_bready      (axi_bready),

        /*
         * Single-beat AXI4 read-address channel.
         */
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

        /*
         * AXI read-data channel.
         */
        .cpu_axi_rid         (),
        .cpu_axi_rdata       (axi_rdata),
        .cpu_axi_rresp       (axi_rresp),
        .cpu_axi_rlast       (),
        .cpu_axi_rvalid      (axi_rvalid),
        .cpu_axi_rready      (axi_rready),

        /*
         * Physical DE10-Lite SDRAM connections.
         */
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

    /*
     * Show a cache/memory error on LEDR[0].
     */
    assign LEDR = {9'b0, cache_error};

endmodule
