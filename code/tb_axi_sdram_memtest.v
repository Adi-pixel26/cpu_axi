`timescale 1ns/1ps

// Self-checking unit test for axi_sdram_memtest.  The AXI memory below
// accepts AW and W independently and inserts deterministic backpressure.
module tb_axi_sdram_memtest;

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
    reg  [1:0]  bresp;
    reg         bvalid;
    wire        bready;
    wire [31:0] araddr;
    wire        arvalid;
    wire        arready;
    reg  [31:0] rdata;
    reg  [1:0]  rresp;
    reg         rlast;
    reg         rvalid;
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

    reg [31:0] memory [0:8191];
    reg [31:0] saved_awaddr;
    reg [31:0] saved_wdata;
    reg [3:0]  saved_wstrb;
    reg        aw_pending;
    reg        w_pending;

    reg [31:0] saved_araddr;
    reg [2:0]  read_delay;
    reg        read_pending;
    reg [7:0]  cycle_count;

    integer i;

    assign awready = reset_n && !aw_pending && !bvalid &&
                     (cycle_count[1:0] != 2'b01);
    assign wready  = reset_n && !w_pending && !bvalid &&
                     (cycle_count[2:1] != 2'b10);
    assign arready = reset_n && !read_pending && !rvalid &&
                     (cycle_count[2:0] != 3'b011);

    axi_sdram_memtest #(
        .WORDS_PER_REGION (64),
        .REGION_COUNT     (2),
        .REGION_STRIDE    (32'h0000_4000),
        .PATTERN_COUNT    (6)
    ) dut (
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

    always #10 clk = ~clk;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            saved_awaddr <= 32'd0;
            saved_wdata  <= 32'd0;
            saved_wstrb  <= 4'd0;
            aw_pending   <= 1'b0;
            w_pending    <= 1'b0;
            bresp        <= 2'b00;
            bvalid       <= 1'b0;

            saved_araddr <= 32'd0;
            read_delay   <= 3'd0;
            read_pending <= 1'b0;
            rdata        <= 32'd0;
            rresp        <= 2'b00;
            rlast        <= 1'b0;
            rvalid       <= 1'b0;
            cycle_count  <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 1'b1;

            if (awvalid && awready) begin
                saved_awaddr <= awaddr;
                aw_pending   <= 1'b1;
            end

            if (wvalid && wready) begin
                saved_wdata <= wdata;
                saved_wstrb <= wstrb;
                w_pending   <= 1'b1;
            end

            if (aw_pending && w_pending && !bvalid) begin
                if (saved_wstrb[0])
                    memory[saved_awaddr[14:2]][7:0] <= saved_wdata[7:0];
                if (saved_wstrb[1])
                    memory[saved_awaddr[14:2]][15:8] <= saved_wdata[15:8];
                if (saved_wstrb[2])
                    memory[saved_awaddr[14:2]][23:16] <= saved_wdata[23:16];
                if (saved_wstrb[3])
                    memory[saved_awaddr[14:2]][31:24] <= saved_wdata[31:24];

                aw_pending <= 1'b0;
                w_pending  <= 1'b0;
                bresp      <= 2'b00;
                bvalid     <= 1'b1;
            end

            if (bvalid && bready)
                bvalid <= 1'b0;

            if (arvalid && arready) begin
                saved_araddr <= araddr;
                read_delay   <= 3'd3;
                read_pending <= 1'b1;
            end

            if (read_pending) begin
                if (read_delay == 3'd1) begin
                    rdata        <= memory[saved_araddr[14:2]];
                    rresp        <= 2'b00;
                    rlast        <= 1'b1;
                    rvalid       <= 1'b1;
                    read_pending <= 1'b0;
                    read_delay   <= 3'd0;
                end else begin
                    read_delay <= read_delay - 1'b1;
                end
            end

            if (rvalid && rready) begin
                rvalid <= 1'b0;
                rlast  <= 1'b0;
            end
        end
    end

    initial begin
        clk     = 1'b0;
        reset_n = 1'b0;
        start   = 1'b0;

        for (i = 0; i < 8192; i = i + 1)
            memory[i] = 32'd0;

        repeat (8) @(posedge clk);
        reset_n <= 1'b1;
        repeat (4) @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;

        wait (done);
        @(posedge clk);

        if (pass && !fail)
            $display("PASS axi_sdram_memtest with independent AXI backpressure");
        else begin
            $display("FAIL axi_sdram_memtest code=%0d addr=%h expected=%h actual=%h",
                     fail_code, fail_address, fail_expected, fail_actual);
            $stop;
        end

        repeat (5) @(posedge clk);
        $finish;
    end

    initial begin
        #5000000;
        $display("FAIL axi_sdram_memtest timeout");
        $stop;
    end

endmodule
