// cache_memory_arbiter.v
//
// Arbitrates the I-cache and D-cache lower-memory ports onto one unified
// 32-bit request/response channel.  Only one transaction is outstanding.
// D-cache has priority so that a load, store miss, or dirty writeback cannot
// be starved by continuous instruction refills.

module cache_memory_arbiter (
    input  wire        clk,
    input  wire        reset,

    // I-cache lower-memory interface (read-only).
    input  wire        i_req_valid,
    output wire        i_req_ready,
    input  wire [31:0] i_req_addr,
    output reg         i_rsp_valid,
    output reg  [31:0] i_rsp_rdata,
    output reg         i_rsp_error,

    // D-cache lower-memory interface.
    input  wire        d_req_valid,
    output wire        d_req_ready,
    input  wire        d_req_write,
    input  wire [31:0] d_req_addr,
    input  wire [31:0] d_req_wdata,
    output reg         d_rsp_valid,
    output reg  [31:0] d_rsp_rdata,
    output reg         d_rsp_error,

    // Unified word-memory request/response interface.
    output wire        mem_req_valid,
    input  wire        mem_req_ready,
    output wire        mem_req_write,
    output wire [31:0] mem_req_addr,
    output wire [31:0] mem_req_wdata,
    input  wire        mem_rsp_valid,
    input  wire [31:0] mem_rsp_rdata,
    input  wire        mem_rsp_error
);

    localparam STATE_IDLE = 1'b0;
    localparam STATE_WAIT = 1'b1;

    localparam OWNER_I = 1'b0;
    localparam OWNER_D = 1'b1;

    reg state;
    reg owner;

    wire grant_d;
    wire grant_i;
    wire request_accepted;

    assign grant_d = (state == STATE_IDLE) && d_req_valid;
    assign grant_i = (state == STATE_IDLE) && !d_req_valid && i_req_valid;

    assign mem_req_valid = grant_d || grant_i;
    assign mem_req_write = grant_d ? d_req_write : 1'b0;
    assign mem_req_addr  = grant_d ? d_req_addr  : i_req_addr;
    assign mem_req_wdata = grant_d ? d_req_wdata : 32'd0;

    assign d_req_ready = grant_d && mem_req_ready;
    assign i_req_ready = grant_i && mem_req_ready;

    assign request_accepted = mem_req_valid && mem_req_ready;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= STATE_IDLE;
            owner       <= OWNER_I;

            i_rsp_valid <= 1'b0;
            i_rsp_rdata <= 32'd0;
            i_rsp_error <= 1'b0;

            d_rsp_valid <= 1'b0;
            d_rsp_rdata <= 32'd0;
            d_rsp_error <= 1'b0;
        end else begin
            // Responses are one-clock pulses.  Each cache is already in its
            // wait state after its request has been accepted.
            i_rsp_valid <= 1'b0;
            d_rsp_valid <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    if (request_accepted) begin
                        owner <= grant_d ? OWNER_D : OWNER_I;
                        state <= STATE_WAIT;
                    end
                end

                STATE_WAIT: begin
                    if (mem_rsp_valid) begin
                        if (owner == OWNER_D) begin
                            d_rsp_valid <= 1'b1;
                            d_rsp_rdata <= mem_rsp_rdata;
                            d_rsp_error <= mem_rsp_error;
                        end else begin
                            i_rsp_valid <= 1'b1;
                            i_rsp_rdata <= mem_rsp_rdata;
                            i_rsp_error <= mem_rsp_error;
                        end

                        state <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
