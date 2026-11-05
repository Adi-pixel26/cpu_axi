// First local MMIO peripheral.
// Address 0x04000000 holds six CPU-controlled LED bits.
//
// A CPU store instruction to this address updates user_leds.
// A CPU load instruction from this address returns user_leds.

module fpga_mmio_peripherals (
    input  wire        clk,
    input  wire        reset,

    input  wire        mmio_valid,
    input  wire        mmio_write,
    input  wire [31:0] mmio_addr,
    input  wire [31:0] mmio_wdata,
    input  wire [3:0]  mmio_wstrb,

    output reg  [31:0] mmio_rdata,
    output reg  [5:0]  user_leds
);

    localparam [31:0] MMIO_LED_ADDR = 32'h0400_0000;

    // Store: CPU writes the LED device register.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            user_leds <= 6'b000000;
        end else if (mmio_valid &&
                     mmio_write &&
                     (mmio_addr == MMIO_LED_ADDR)) begin
            if (mmio_wstrb[0])
                user_leds <= mmio_wdata[5:0];
        end
    end

    // Load: CPU reads the LED device register.
    always @(*) begin
        mmio_rdata = 32'd0;

        if (mmio_valid && !mmio_write) begin
            case (mmio_addr)
                MMIO_LED_ADDR: mmio_rdata = {26'd0, user_leds};
                default:       mmio_rdata = 32'd0;
            endcase
        end
    end

endmodule