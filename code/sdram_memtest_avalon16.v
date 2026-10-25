// sdram_memtest_avalon16.v
//
// Synthesizable memory tester for the 16-bit Avalon-side interface of the
// DE10-Lite SDRAM controller.  This block is an Avalon-MM master.  It writes
// a pattern to every tested halfword and then reads the same addresses back.
//
// The SDRAM controller generated in this project exposes active-low read,
// write, and byte-enable signals, so this tester uses the same convention.
// Address 0 is the first 16-bit SDRAM word, address 1 is the next word, etc.

module sdram_memtest_avalon16 #(
    parameter ADDR_WIDTH = 25,
    // Quick default: 64K halfwords = 128 KiB.  After the quick test passes,
    // set TEST_WORDS to 33554432 to cover the complete 64 MiB device.
    parameter TEST_WORDS = 65536
) (
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  start,

    output reg  [ADDR_WIDTH-1:0] avm_address,
    output reg  [1:0]            avm_byteenable_n,
    output reg                   avm_chipselect,
    output reg  [15:0]           avm_writedata,
    output reg                   avm_read_n,
    output reg                   avm_write_n,
    input  wire [15:0]           avm_readdata,
    input  wire                  avm_readdatavalid,
    input  wire                  avm_waitrequest,

    output reg                   busy,
    output reg                   done,
    output reg                   pass,
    output reg                   fail,
    output reg  [2:0]            current_pattern,
    output reg  [ADDR_WIDTH-1:0] fail_address,
    output reg  [15:0]           fail_expected,
    output reg  [15:0]           fail_actual
);

    localparam STATE_IDLE       = 3'd0;
    localparam STATE_WRITE      = 3'd1;
    localparam STATE_READ_REQ   = 3'd2;
    localparam STATE_READ_WAIT  = 3'd3;
    localparam STATE_FINISHED   = 3'd4;

    localparam LAST_PATTERN = 3'd5;

    reg [2:0] state;
    reg [ADDR_WIDTH-1:0] word_index;

    function [15:0] make_pattern;
        input [ADDR_WIDTH-1:0] address_value;
        input [2:0] pattern_number;
        begin
            case (pattern_number)
                3'd0: make_pattern = 16'h0000;
                3'd1: make_pattern = 16'hffff;
                3'd2: make_pattern = 16'haaaa;
                3'd3: make_pattern = 16'h5555;
                3'd4: make_pattern = address_value[15:0] ^ 16'ha5a5;
                3'd5: make_pattern = ~(address_value[15:0] ^ 16'h5a5a);
                default: make_pattern = 16'h0000;
            endcase
        end
    endfunction

    always @(*) begin
        avm_address      = word_index;
        avm_byteenable_n = 2'b00;
        avm_chipselect   = 1'b0;
        avm_writedata    = make_pattern(word_index, current_pattern);
        avm_read_n       = 1'b1;
        avm_write_n      = 1'b1;

        case (state)
            STATE_WRITE: begin
                avm_chipselect = 1'b1;
                avm_write_n    = 1'b0;
            end

            STATE_READ_REQ: begin
                avm_chipselect = 1'b1;
                avm_read_n     = 1'b0;
            end

            default: begin
                avm_chipselect = 1'b0;
            end
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state           <= STATE_IDLE;
            word_index      <= {ADDR_WIDTH{1'b0}};
            current_pattern <= 3'd0;
            busy            <= 1'b0;
            done            <= 1'b0;
            pass            <= 1'b0;
            fail            <= 1'b0;
            fail_address    <= {ADDR_WIDTH{1'b0}};
            fail_expected   <= 16'd0;
            fail_actual     <= 16'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (start) begin
                        word_index      <= {ADDR_WIDTH{1'b0}};
                        current_pattern <= 3'd0;
                        busy            <= 1'b1;
                        done            <= 1'b0;
                        pass            <= 1'b0;
                        fail            <= 1'b0;
                        state           <= STATE_WRITE;
                    end
                end

                STATE_WRITE: begin
                    // Hold every command signal stable while waitrequest is 1.
                    if (!avm_waitrequest) begin
                        if (word_index == TEST_WORDS - 1) begin
                            word_index <= {ADDR_WIDTH{1'b0}};
                            state      <= STATE_READ_REQ;
                        end else begin
                            word_index <= word_index + 1'b1;
                        end
                    end
                end

                STATE_READ_REQ: begin
                    // After the read command is accepted, wait for the
                    // independently returned readdatavalid pulse.
                    if (!avm_waitrequest)
                        state <= STATE_READ_WAIT;
                end

                STATE_READ_WAIT: begin
                    if (avm_readdatavalid) begin
                        if (avm_readdata !=
                            make_pattern(word_index, current_pattern)) begin
                            fail          <= 1'b1;
                            pass          <= 1'b0;
                            busy          <= 1'b0;
                            done          <= 1'b1;
                            fail_address  <= word_index;
                            fail_expected <=
                                make_pattern(word_index, current_pattern);
                            fail_actual   <= avm_readdata;
                            state         <= STATE_FINISHED;
                        end else if (word_index == TEST_WORDS - 1) begin
                            if (current_pattern == LAST_PATTERN) begin
                                pass  <= 1'b1;
                                busy  <= 1'b0;
                                done  <= 1'b1;
                                state <= STATE_FINISHED;
                            end else begin
                                current_pattern <= current_pattern + 1'b1;
                                word_index      <= {ADDR_WIDTH{1'b0}};
                                state           <= STATE_WRITE;
                            end
                        end else begin
                            word_index <= word_index + 1'b1;
                            state      <= STATE_READ_REQ;
                        end
                    end
                end

                STATE_FINISHED: begin
                    // Keep the result visible until start is removed.  This
                    // also makes a push-button start safe to use on hardware.
                    if (!start)
                        state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
