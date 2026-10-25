module rv32_divider (
    input  wire        clk,
    input  wire        reset,

    input  wire        start,
    input  wire        signed_mode,
    input  wire [31:0] dividend,
    input  wire [31:0] divisor,

    output reg         busy,
    output reg         result_valid,
    input  wire        result_ready,
    output reg  [31:0] quotient,
    output reg  [31:0] remainder
);

    reg [31:0] divisor_magnitude;
    reg [31:0] quotient_work;
    reg [32:0] remainder_work;
    reg [5:0]  iteration;
    reg        quotient_negative;
    reg        remainder_negative;

    wire [32:0] shifted_remainder;
    wire        subtract_divisor;
    wire [32:0] remainder_next;
    wire [31:0] quotient_next;

    assign shifted_remainder = {
        remainder_work[31:0], quotient_work[31]
    };

    assign subtract_divisor =
        shifted_remainder >= {1'b0, divisor_magnitude};

    assign remainder_next = subtract_divisor
        ? shifted_remainder - {1'b0, divisor_magnitude}
        : shifted_remainder;

    assign quotient_next = {
        quotient_work[30:0], subtract_divisor
    };

    always @(posedge clk) begin
        if (reset) begin
            busy               <= 1'b0;
            result_valid       <= 1'b0;
            quotient           <= 32'd0;
            remainder          <= 32'd0;
            divisor_magnitude  <= 32'd0;
            quotient_work      <= 32'd0;
            remainder_work     <= 33'd0;
            iteration          <= 6'd0;
            quotient_negative  <= 1'b0;
            remainder_negative <= 1'b0;
        end else begin
            // Hold a completed result until the pipeline accepts it.
            if (result_valid && result_ready)
                result_valid <= 1'b0;

            if (start && !busy && !result_valid) begin
                // RISC-V defines a result rather than an exception here.
                if (divisor == 32'd0) begin
                    busy         <= 1'b0;
                    result_valid <= 1'b1;
                    quotient     <= 32'hffff_ffff;
                    remainder    <= dividend;
                end else if (signed_mode &&
                             (dividend == 32'h8000_0000) &&
                             (divisor  == 32'hffff_ffff)) begin
                    // Signed overflow: INT_MIN / -1.
                    busy         <= 1'b0;
                    result_valid <= 1'b1;
                    quotient     <= 32'h8000_0000;
                    remainder    <= 32'd0;
                end else begin
                    busy         <= 1'b1;
                    result_valid <= 1'b0;
                    iteration    <= 6'd0;
                    remainder_work <= 33'd0;

                    quotient_negative <=
                        signed_mode && (dividend[31] ^ divisor[31]);
                    remainder_negative <=
                        signed_mode && dividend[31];

                    quotient_work <= (signed_mode && dividend[31])
                        ? (~dividend + 1'b1)
                        : dividend;

                    divisor_magnitude <= (signed_mode && divisor[31])
                        ? (~divisor + 1'b1)
                        : divisor;
                end
            end else if (busy) begin
                remainder_work <= remainder_next;
                quotient_work  <= quotient_next;

                if (iteration == 6'd31) begin
                    busy         <= 1'b0;
                    result_valid <= 1'b1;

                    quotient <= quotient_negative
                        ? (~quotient_next + 1'b1)
                        : quotient_next;

                    remainder <= remainder_negative
                        ? (~remainder_next[31:0] + 1'b1)
                        : remainder_next[31:0];
                end else begin
                    iteration <= iteration + 1'b1;
                end
            end
        end
    end

endmodule
