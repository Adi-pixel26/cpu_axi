// axi_sdram_memtest.v
//
// Synthesizable, single-beat AXI4 SDRAM memory tester.  The tester writes a
// complete region, reads it back, and repeats this for several data patterns
// and widely separated regions.  Only one AXI transaction is outstanding.
//
// This module deliberately uses only Verilog-2001 constructs.

module axi_sdram_memtest #(
    parameter integer WORDS_PER_REGION = 1024,
    parameter integer REGION_COUNT     = 4,
    parameter [31:0]  REGION_STRIDE    = 32'h0100_0000,
    parameter integer PATTERN_COUNT    = 6
) (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        start,

    // AXI write-address channel.
    output reg  [31:0] m_axi_awaddr,
    output reg         m_axi_awvalid,
    input  wire        m_axi_awready,

    // AXI write-data channel.
    output reg  [31:0] m_axi_wdata,
    output reg  [3:0]  m_axi_wstrb,
    output reg         m_axi_wvalid,
    input  wire        m_axi_wready,

    // AXI write-response channel.
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output reg         m_axi_bready,

    // AXI read-address channel.
    output reg  [31:0] m_axi_araddr,
    output reg         m_axi_arvalid,
    input  wire        m_axi_arready,

    // AXI read-data channel.
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rlast,
    input  wire        m_axi_rvalid,
    output reg         m_axi_rready,

    output reg         busy,
    output reg         done,
    output reg         pass,
    output reg         fail,
    output reg  [2:0]  fail_code,
    output reg  [31:0] fail_address,
    output reg  [31:0] fail_expected,
    output reg  [31:0] fail_actual,
    output reg  [2:0]  current_pattern,
    output reg  [7:0]  current_region,
    output wire [31:0] current_address
);

    localparam [3:0] STATE_IDLE       = 4'd0;
    localparam [3:0] STATE_WRITE_SEND = 4'd1;
    localparam [3:0] STATE_WRITE_RESP = 4'd2;
    localparam [3:0] STATE_READ_ADDR  = 4'd3;
    localparam [3:0] STATE_READ_DATA  = 4'd4;
    localparam [3:0] STATE_FINISHED   = 4'd5;

    // Failure codes visible in simulation and Signal Tap:
    // 1 = AXI write response error
    // 2 = AXI read response error
    // 3 = read data mismatch
    // 4 = missing RLAST on a single-beat read
    localparam [2:0] FAIL_WRITE_RESP = 3'd1;
    localparam [2:0] FAIL_READ_RESP  = 3'd2;
    localparam [2:0] FAIL_DATA       = 3'd3;
    localparam [2:0] FAIL_RLAST      = 3'd4;

    reg [3:0]  state;
    reg [31:0] word_index;
    reg [31:0] region_base;
    reg        aw_accepted;
    reg        w_accepted;

    wire aw_handshake;
    wire w_handshake;
    wire [31:0] next_word_address;
    wire [31:0] next_region_base;

    assign aw_handshake = m_axi_awvalid && m_axi_awready;
    assign w_handshake  = m_axi_wvalid  && m_axi_wready;

    assign next_word_address = region_base +
                               ((word_index + 32'd1) << 2);
    assign next_region_base  = region_base + REGION_STRIDE;

    assign current_address = ((state == STATE_READ_ADDR) ||
                              (state == STATE_READ_DATA)) ?
                             m_axi_araddr : m_axi_awaddr;

    function [31:0] make_pattern;
        input [31:0] address_value;
        input [2:0]  pattern_number;
        begin
            case (pattern_number)
                3'd0: make_pattern = 32'h0000_0000;
                3'd1: make_pattern = 32'hffff_ffff;
                3'd2: make_pattern = 32'haaaa_aaaa;
                3'd3: make_pattern = 32'h5555_5555;
                3'd4: make_pattern = address_value ^ 32'ha5a5_5a5a;
                3'd5: make_pattern = {address_value[15:0],
                                      address_value[31:16]} ^
                                     32'h3cc3_c33c;
                default: make_pattern = 32'h0000_0000;
            endcase
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state            <= STATE_IDLE;
            word_index       <= 32'd0;
            region_base      <= 32'd0;
            aw_accepted      <= 1'b0;
            w_accepted       <= 1'b0;

            m_axi_awaddr     <= 32'd0;
            m_axi_awvalid    <= 1'b0;
            m_axi_wdata      <= 32'd0;
            m_axi_wstrb      <= 4'b1111;
            m_axi_wvalid     <= 1'b0;
            m_axi_bready     <= 1'b0;
            m_axi_araddr     <= 32'd0;
            m_axi_arvalid    <= 1'b0;
            m_axi_rready     <= 1'b0;

            busy             <= 1'b0;
            done             <= 1'b0;
            pass             <= 1'b0;
            fail             <= 1'b0;
            fail_code        <= 3'd0;
            fail_address     <= 32'd0;
            fail_expected    <= 32'd0;
            fail_actual      <= 32'd0;
            current_pattern  <= 3'd0;
            current_region   <= 8'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (start) begin
                        word_index      <= 32'd0;
                        region_base     <= 32'd0;
                        current_pattern <= 3'd0;
                        current_region  <= 8'd0;
                        busy            <= 1'b1;
                        done            <= 1'b0;
                        pass            <= 1'b0;
                        fail            <= 1'b0;
                        fail_code       <= 3'd0;

                        m_axi_awaddr    <= 32'd0;
                        m_axi_wdata     <= make_pattern(32'd0, 3'd0);
                        m_axi_wstrb     <= 4'b1111;
                        m_axi_awvalid   <= 1'b1;
                        m_axi_wvalid    <= 1'b1;
                        aw_accepted     <= 1'b0;
                        w_accepted      <= 1'b0;
                        state           <= STATE_WRITE_SEND;
                    end
                end

                STATE_WRITE_SEND: begin
                    if (aw_handshake) begin
                        m_axi_awvalid <= 1'b0;
                        aw_accepted   <= 1'b1;
                    end

                    if (w_handshake) begin
                        m_axi_wvalid <= 1'b0;
                        w_accepted   <= 1'b1;
                    end

                    // AW and W are independent AXI channels.  Proceed only
                    // after both have completed their own handshake.
                    if ((aw_accepted || aw_handshake) &&
                        (w_accepted  || w_handshake)) begin
                        m_axi_bready <= 1'b1;
                        state        <= STATE_WRITE_RESP;
                    end
                end

                STATE_WRITE_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;

                        if (m_axi_bresp != 2'b00) begin
                            busy          <= 1'b0;
                            done          <= 1'b1;
                            fail          <= 1'b1;
                            fail_code     <= FAIL_WRITE_RESP;
                            fail_address  <= m_axi_awaddr;
                            fail_expected <= 32'd0;
                            fail_actual   <= {30'd0, m_axi_bresp};
                            state         <= STATE_FINISHED;
                        end else if (word_index == WORDS_PER_REGION - 1) begin
                            // The complete region has been written.  Read it
                            // back from its first address.
                            word_index    <= 32'd0;
                            m_axi_araddr  <= region_base;
                            m_axi_arvalid <= 1'b1;
                            state         <= STATE_READ_ADDR;
                        end else begin
                            word_index    <= word_index + 32'd1;
                            m_axi_awaddr  <= next_word_address;
                            m_axi_wdata   <= make_pattern(next_word_address,
                                                          current_pattern);
                            m_axi_awvalid <= 1'b1;
                            m_axi_wvalid  <= 1'b1;
                            aw_accepted   <= 1'b0;
                            w_accepted    <= 1'b0;
                            state         <= STATE_WRITE_SEND;
                        end
                    end
                end

                STATE_READ_ADDR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state         <= STATE_READ_DATA;
                    end
                end

                STATE_READ_DATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        m_axi_rready <= 1'b0;

                        if (m_axi_rresp != 2'b00) begin
                            busy          <= 1'b0;
                            done          <= 1'b1;
                            fail          <= 1'b1;
                            fail_code     <= FAIL_READ_RESP;
                            fail_address  <= m_axi_araddr;
                            fail_expected <= make_pattern(m_axi_araddr,
                                                          current_pattern);
                            fail_actual   <= {30'd0, m_axi_rresp};
                            state         <= STATE_FINISHED;
                        end else if (!m_axi_rlast) begin
                            busy          <= 1'b0;
                            done          <= 1'b1;
                            fail          <= 1'b1;
                            fail_code     <= FAIL_RLAST;
                            fail_address  <= m_axi_araddr;
                            fail_expected <= 32'd1;
                            fail_actual   <= 32'd0;
                            state         <= STATE_FINISHED;
                        end else if (m_axi_rdata !=
                                     make_pattern(m_axi_araddr,
                                                  current_pattern)) begin
                            busy          <= 1'b0;
                            done          <= 1'b1;
                            fail          <= 1'b1;
                            fail_code     <= FAIL_DATA;
                            fail_address  <= m_axi_araddr;
                            fail_expected <= make_pattern(m_axi_araddr,
                                                          current_pattern);
                            fail_actual   <= m_axi_rdata;
                            state         <= STATE_FINISHED;
                        end else if (word_index == WORDS_PER_REGION - 1) begin
                            if (current_region == REGION_COUNT - 1) begin
                                if (current_pattern == PATTERN_COUNT - 1) begin
                                    busy  <= 1'b0;
                                    done  <= 1'b1;
                                    pass  <= 1'b1;
                                    state <= STATE_FINISHED;
                                end else begin
                                    // Start the next pattern at region zero.
                                    current_pattern <= current_pattern + 1'b1;
                                    current_region  <= 8'd0;
                                    region_base     <= 32'd0;
                                    word_index      <= 32'd0;
                                    m_axi_awaddr    <= 32'd0;
                                    m_axi_wdata     <= make_pattern(
                                                        32'd0,
                                                        current_pattern + 1'b1);
                                    m_axi_awvalid   <= 1'b1;
                                    m_axi_wvalid    <= 1'b1;
                                    aw_accepted     <= 1'b0;
                                    w_accepted      <= 1'b0;
                                    state           <= STATE_WRITE_SEND;
                                end
                            end else begin
                                // Test the next widely separated SDRAM region.
                                current_region <= current_region + 1'b1;
                                region_base    <= next_region_base;
                                word_index     <= 32'd0;
                                m_axi_awaddr   <= next_region_base;
                                m_axi_wdata    <= make_pattern(next_region_base,
                                                               current_pattern);
                                m_axi_awvalid  <= 1'b1;
                                m_axi_wvalid   <= 1'b1;
                                aw_accepted    <= 1'b0;
                                w_accepted     <= 1'b0;
                                state          <= STATE_WRITE_SEND;
                            end
                        end else begin
                            word_index    <= word_index + 32'd1;
                            m_axi_araddr  <= next_word_address;
                            m_axi_arvalid <= 1'b1;
                            state         <= STATE_READ_ADDR;
                        end
                    end
                end

                STATE_FINISHED: begin
                    // Result remains visible until the board is reset.
                    busy <= 1'b0;
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
