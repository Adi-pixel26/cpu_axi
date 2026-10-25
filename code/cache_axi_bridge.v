// cache_axi_bridge.v
//
// Converts the arbiter's ready/valid word-memory channel into the pulse/done
// request interface used by axi_master.v.  Address and write data are held
// stable until the AXI transaction completes.

module cache_axi_bridge (
    input  wire        clk,
    input  wire        reset,

    // Unified cache-memory side.
    input  wire        mem_req_valid,
    output wire        mem_req_ready,
    input  wire        mem_req_write,
    input  wire [31:0] mem_req_addr,
    input  wire [31:0] mem_req_wdata,

    output reg         mem_rsp_valid,
    output reg  [31:0] mem_rsp_rdata,
    output reg         mem_rsp_error,

    // axi_master CPU-side request interface.
    output reg         axi_cpu_write_req,
    output reg         axi_cpu_read_req,
    output reg  [31:0] axi_cpu_address,
    output reg  [31:0] axi_cpu_wdata,

    input  wire        axi_cpu_write_done,
    input  wire        axi_cpu_write_error,
    input  wire        axi_cpu_read_done,
    input  wire        axi_cpu_read_error,
    input  wire [31:0] axi_cpu_rdata
);

    localparam STATE_IDLE       = 2'd0;
    localparam STATE_WAIT_READ  = 2'd1;
    localparam STATE_WAIT_WRITE = 2'd2;

    reg [1:0] state;

    assign mem_req_ready = (state == STATE_IDLE);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state               <= STATE_IDLE;
            axi_cpu_write_req   <= 1'b0;
            axi_cpu_read_req    <= 1'b0;
            axi_cpu_address     <= 32'd0;
            axi_cpu_wdata       <= 32'd0;
            mem_rsp_valid       <= 1'b0;
            mem_rsp_rdata       <= 32'd0;
            mem_rsp_error       <= 1'b0;
        end else begin
            // Requests and responses are one-clock pulses.
            axi_cpu_write_req <= 1'b0;
            axi_cpu_read_req  <= 1'b0;
            mem_rsp_valid     <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    if (mem_req_valid && mem_req_ready) begin
                        axi_cpu_address <= mem_req_addr;
                        axi_cpu_wdata   <= mem_req_wdata;

                        if (mem_req_write) begin
                            axi_cpu_write_req <= 1'b1;
                            state             <= STATE_WAIT_WRITE;
                        end else begin
                            axi_cpu_read_req <= 1'b1;
                            state            <= STATE_WAIT_READ;
                        end
                    end
                end

                STATE_WAIT_READ: begin
                    if (axi_cpu_read_done) begin
                        mem_rsp_valid <= 1'b1;
                        mem_rsp_rdata <= axi_cpu_rdata;
                        mem_rsp_error <= axi_cpu_read_error;
                        state         <= STATE_IDLE;
                    end
                end

                STATE_WAIT_WRITE: begin
                    if (axi_cpu_write_done) begin
                        mem_rsp_valid <= 1'b1;
                        mem_rsp_rdata <= 32'd0;
                        mem_rsp_error <= axi_cpu_write_error;
                        state         <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
