// cached_riscv_cpu_top.v
//
// CPU subsystem top level:
//   RV32I pipeline -> split blocking L1 caches -> I/D arbiter
//   -> cache/AXI bridge -> AXI word master.
//
// The AXI signals must be connected to an AXI-compatible SDRAM controller.
// The physical 16-bit SDRAM data width is handled behind that controller;
// the CPU, caches, and this AXI interface remain 32 bits wide.

module cached_riscv_cpu_top (
    input  wire        clk,
    input  wire        reset,

    output wire        M_AXI_ARESETN,

    // AXI write-address channel.
    output wire [31:0] M_AXI_AWADDR,
    output wire        M_AXI_AWVALID,
    input  wire        M_AXI_AWREADY,

    // AXI write-data channel.
    output wire [31:0] M_AXI_WDATA,
    output wire [3:0]  M_AXI_WSTRB,
    output wire        M_AXI_WVALID,
    input  wire        M_AXI_WREADY,

    // AXI write-response channel.
    input  wire [1:0]  M_AXI_BRESP,
    input  wire        M_AXI_BVALID,
    output wire        M_AXI_BREADY,

    // AXI read-address channel.
    output wire [31:0] M_AXI_ARADDR,
    output wire        M_AXI_ARVALID,
    input  wire        M_AXI_ARREADY,

    // AXI read-data channel.
    input  wire [31:0] M_AXI_RDATA,
    input  wire [1:0]  M_AXI_RRESP,
    input  wire        M_AXI_RVALID,
    output wire        M_AXI_RREADY,

    // Diagnostic status.  A later exception unit should convert this into
    // instruction/load/store access-fault and misalignment traps.
    output wire        cache_error
);

    /* ================================================================
     * CPU-side signals
     * ================================================================ */
    wire [31:0] cpu_pc;
    wire [31:0] cpu_instruction;

    wire        cpu_mem_write;
    wire        cpu_mem_read;
    wire [31:0] cpu_mem_addr;
    wire [31:0] cpu_store_data;
    wire [31:0] cpu_load_data;
    wire [2:0]  cpu_mem_funct3;

    wire [31:0] cpu_result;
    wire [31:0] cpu_pc_w;
    wire [31:0] cpu_alu_result_w;
    wire [31:0] cpu_write_data_w;

    wire        icache_stall;
    wire        dcache_stall;
    wire        cpu_memory_request;
    wire        pipeline_accept;

    assign cpu_memory_request = cpu_mem_read | cpu_mem_write;

    riscv_cpu cpu (
        .clk(clk),
        .reset(reset),
        .ICacheStall(icache_stall),
        .DCacheStall(dcache_stall),
        .PC(cpu_pc),
        .Instr(cpu_instruction),
        .MemWrite(cpu_mem_write),
        .MemRead(cpu_mem_read),
        .Mem_WrAddr(cpu_mem_addr),
        .Mem_WrData(cpu_store_data),
        .ReadData(cpu_load_data),
        .Result(cpu_result),
        .funct3(cpu_mem_funct3),
        .PCW(cpu_pc_w),
        .ALUResultW(cpu_alu_result_w),
        .WriteDataW(cpu_write_data_w)
    );

    /* ================================================================
     * Load/store byte-lane and sign-extension adapter
     * ================================================================ */
    wire [31:0] dcache_cpu_wdata;
    wire [3:0]  dcache_cpu_wstrb;
    wire [31:0] dcache_cpu_raw_rdata;
    wire        memory_misaligned;

    load_store_adapter load_store (
        .address(cpu_mem_addr),
        .funct3(cpu_mem_funct3),
        .store_data(cpu_store_data),
        .raw_load_data(dcache_cpu_raw_rdata),
        .aligned_store_data(dcache_cpu_wdata),
        .store_strobe(dcache_cpu_wstrb),
        .formatted_load_data(cpu_load_data),
        .misaligned(memory_misaligned)
    );

    /* ================================================================
     * I-cache CPU and lower-memory signals
     * ================================================================ */
    wire        icache_cpu_req_ready;
    wire        icache_cpu_rsp_valid;
    wire        icache_cpu_rsp_ready;
    wire        icache_cpu_rsp_error;

    wire        icache_mem_req_valid;
    wire        icache_mem_req_ready;
    wire [31:0] icache_mem_req_addr;
    wire        icache_mem_rsp_valid;
    wire [31:0] icache_mem_rsp_rdata;
    wire        icache_mem_rsp_error;

    l1_icache_4way icache (
        .clk(clk),
        .reset(reset),
        .invalidate_all(1'b0),

        .cpu_req_valid(!reset),
        .cpu_req_ready(icache_cpu_req_ready),
        .cpu_req_addr(cpu_pc),
        .cpu_rsp_valid(icache_cpu_rsp_valid),
        .cpu_rsp_ready(icache_cpu_rsp_ready),
        .cpu_rsp_instr(cpu_instruction),
        .cpu_rsp_error(icache_cpu_rsp_error),

        .mem_req_valid(icache_mem_req_valid),
        .mem_req_ready(icache_mem_req_ready),
        .mem_req_addr(icache_mem_req_addr),
        .mem_rsp_valid(icache_mem_rsp_valid),
        .mem_rsp_rdata(icache_mem_rsp_rdata),
        .mem_rsp_error(icache_mem_rsp_error)
    );

    /* ================================================================
     * D-cache CPU and lower-memory signals
     * ================================================================ */
    wire        dcache_cpu_req_ready;
    wire        dcache_cpu_rsp_valid;
    wire        dcache_cpu_rsp_ready;
    wire        dcache_cpu_rsp_error;

    wire        dcache_flush_ready;
    wire        dcache_flush_busy;
    wire        dcache_flush_done;
    wire        dcache_flush_error;

    wire        dcache_mem_req_valid;
    wire        dcache_mem_req_ready;
    wire        dcache_mem_req_write;
    wire [31:0] dcache_mem_req_addr;
    wire [31:0] dcache_mem_req_wdata;
    wire        dcache_mem_rsp_valid;
    wire [31:0] dcache_mem_rsp_rdata;
    wire        dcache_mem_rsp_error;

    l1_dcache_4way dcache (
        .clk(clk),
        .reset(reset),

        .cpu_req_valid(cpu_memory_request && !reset),
        .cpu_req_ready(dcache_cpu_req_ready),
        .cpu_req_addr(cpu_mem_addr),
        .cpu_req_write(cpu_mem_write),
        .cpu_req_wdata(dcache_cpu_wdata),
        .cpu_req_wstrb(dcache_cpu_wstrb),

        .cpu_rsp_valid(dcache_cpu_rsp_valid),
        .cpu_rsp_ready(dcache_cpu_rsp_ready),
        .cpu_rsp_rdata(dcache_cpu_raw_rdata),
        .cpu_rsp_error(dcache_cpu_rsp_error),

        .flush_req(1'b0),
        .flush_ready(dcache_flush_ready),
        .flush_busy(dcache_flush_busy),
        .flush_done(dcache_flush_done),
        .flush_error(dcache_flush_error),

        .mem_req_valid(dcache_mem_req_valid),
        .mem_req_ready(dcache_mem_req_ready),
        .mem_req_write(dcache_mem_req_write),
        .mem_req_addr(dcache_mem_req_addr),
        .mem_req_wdata(dcache_mem_req_wdata),
        .mem_rsp_valid(dcache_mem_rsp_valid),
        .mem_rsp_rdata(dcache_mem_rsp_rdata),
        .mem_rsp_error(dcache_mem_rsp_error)
    );

    /*
     * The current core uses a conservative global cache hold.  Keep a cache
     * response asserted until every response required by the current pipeline
     * state is present, then consume them together on the advancing clock.
     * This prevents a completed request from being issued a second time while
     * the other cache is still blocking the pipeline.
     */
    assign pipeline_accept =
        icache_cpu_rsp_valid &&
        (!cpu_memory_request || dcache_cpu_rsp_valid);

    assign icache_stall = !icache_cpu_rsp_valid;
    assign dcache_stall =
        cpu_memory_request && !dcache_cpu_rsp_valid;

    assign icache_cpu_rsp_ready = pipeline_accept;
    assign dcache_cpu_rsp_ready =
        pipeline_accept && cpu_memory_request;

    assign cache_error =
        (icache_cpu_rsp_valid && icache_cpu_rsp_error) ||
        (dcache_cpu_rsp_valid && dcache_cpu_rsp_error) ||
        (cpu_memory_request && memory_misaligned);

    /* ================================================================
     * I-cache/D-cache lower-memory arbiter
     * ================================================================ */
    wire        arb_mem_req_valid;
    wire        arb_mem_req_ready;
    wire        arb_mem_req_write;
    wire [31:0] arb_mem_req_addr;
    wire [31:0] arb_mem_req_wdata;
    wire        arb_mem_rsp_valid;
    wire [31:0] arb_mem_rsp_rdata;
    wire        arb_mem_rsp_error;

    cache_memory_arbiter cache_arbiter (
        .clk(clk),
        .reset(reset),

        .i_req_valid(icache_mem_req_valid),
        .i_req_ready(icache_mem_req_ready),
        .i_req_addr(icache_mem_req_addr),
        .i_rsp_valid(icache_mem_rsp_valid),
        .i_rsp_rdata(icache_mem_rsp_rdata),
        .i_rsp_error(icache_mem_rsp_error),

        .d_req_valid(dcache_mem_req_valid),
        .d_req_ready(dcache_mem_req_ready),
        .d_req_write(dcache_mem_req_write),
        .d_req_addr(dcache_mem_req_addr),
        .d_req_wdata(dcache_mem_req_wdata),
        .d_rsp_valid(dcache_mem_rsp_valid),
        .d_rsp_rdata(dcache_mem_rsp_rdata),
        .d_rsp_error(dcache_mem_rsp_error),

        .mem_req_valid(arb_mem_req_valid),
        .mem_req_ready(arb_mem_req_ready),
        .mem_req_write(arb_mem_req_write),
        .mem_req_addr(arb_mem_req_addr),
        .mem_req_wdata(arb_mem_req_wdata),
        .mem_rsp_valid(arb_mem_rsp_valid),
        .mem_rsp_rdata(arb_mem_rsp_rdata),
        .mem_rsp_error(arb_mem_rsp_error)
    );

    /* ================================================================
     * Ready/valid cache channel to the existing AXI-master request API
     * ================================================================ */
    wire        axi_cpu_write_req;
    wire        axi_cpu_read_req;
    wire [31:0] axi_cpu_address;
    wire [31:0] axi_cpu_wdata;
    wire        axi_cpu_write_done;
    wire        axi_cpu_write_error;
    wire        axi_cpu_read_done;
    wire        axi_cpu_read_error;
    wire [31:0] axi_cpu_rdata;

    cache_axi_bridge cache_to_axi (
        .clk(clk),
        .reset(reset),

        .mem_req_valid(arb_mem_req_valid),
        .mem_req_ready(arb_mem_req_ready),
        .mem_req_write(arb_mem_req_write),
        .mem_req_addr(arb_mem_req_addr),
        .mem_req_wdata(arb_mem_req_wdata),
        .mem_rsp_valid(arb_mem_rsp_valid),
        .mem_rsp_rdata(arb_mem_rsp_rdata),
        .mem_rsp_error(arb_mem_rsp_error),

        .axi_cpu_write_req(axi_cpu_write_req),
        .axi_cpu_read_req(axi_cpu_read_req),
        .axi_cpu_address(axi_cpu_address),
        .axi_cpu_wdata(axi_cpu_wdata),
        .axi_cpu_write_done(axi_cpu_write_done),
        .axi_cpu_write_error(axi_cpu_write_error),
        .axi_cpu_read_done(axi_cpu_read_done),
        .axi_cpu_read_error(axi_cpu_read_error),
        .axi_cpu_rdata(axi_cpu_rdata)
    );

    /* ================================================================
     * AXI master
     * ================================================================ */
    assign M_AXI_ARESETN = !reset;

    axi_master axi (
        .ACLK(clk),
        .ARESETn(M_AXI_ARESETN),

        .cpu_write_req(axi_cpu_write_req),
        .cpu_address(axi_cpu_address),
        .cpu_data(axi_cpu_wdata),
        .cpu_write_done(axi_cpu_write_done),
        .cpu_write_error(axi_cpu_write_error),

        .cpu_read_req(axi_cpu_read_req),
        .cpu_read_data(axi_cpu_rdata),
        .cpu_read_done(axi_cpu_read_done),
        .cpu_read_error(axi_cpu_read_error),

        .AWADDR(M_AXI_AWADDR),
        .AWVALID(M_AXI_AWVALID),
        .AWREADY(M_AXI_AWREADY),
        .WDATA(M_AXI_WDATA),
        .WSTRB(M_AXI_WSTRB),
        .WVALID(M_AXI_WVALID),
        .WREADY(M_AXI_WREADY),
        .BRESP(M_AXI_BRESP),
        .BVALID(M_AXI_BVALID),
        .BREADY(M_AXI_BREADY),
        .ARADDR(M_AXI_ARADDR),
        .ARVALID(M_AXI_ARVALID),
        .ARREADY(M_AXI_ARREADY),
        .RDATA(M_AXI_RDATA),
        .RRESP(M_AXI_RRESP),
        .RVALID(M_AXI_RVALID),
        .RREADY(M_AXI_RREADY)
    );

endmodule
