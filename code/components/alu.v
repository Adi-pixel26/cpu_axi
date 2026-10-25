module alu #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [4:0]       alu_ctrl,

    output reg  [WIDTH-1:0] alu_out,
    output wire             zero,
    output wire             lt,
    output wire             ltu
);

    // Extend operands before multiplying so no product bits are lost.
    wire signed [32:0] a_signed_ext   = {a[31], a};
    wire signed [32:0] b_signed_ext   = {b[31], b};
    wire signed [32:0] b_unsigned_signed_ext = {1'b0, b};
    wire        [32:0] a_unsigned_ext = {1'b0, a};
    wire        [32:0] b_unsigned_ext = {1'b0, b};

    wire signed [65:0] product_ss =
        a_signed_ext * b_signed_ext;

    wire signed [65:0] product_su =
        a_signed_ext * b_unsigned_signed_ext;

    wire [65:0] product_uu =
        a_unsigned_ext * b_unsigned_ext;

    always @(*) begin
        case (alu_ctrl)
            5'b00000: alu_out = a + b;
            5'b00001: alu_out = a + ~b + 1'b1;
            5'b00010: alu_out = a & b;
            5'b00011: alu_out = a | b;
            5'b00100: alu_out = a ^ b;

            5'b00101: alu_out =
                ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;

            5'b00110: alu_out =
                (a < b) ? 32'd1 : 32'd0;

            5'b00111: alu_out = a << b[4:0];
            5'b01000: alu_out = a >> b[4:0];
            5'b01001: alu_out = $signed(a) >>> b[4:0];

            5'b01010: alu_out = product_uu[31:0];  // MUL
            5'b01011: alu_out = product_ss[63:32]; // MULH
            5'b01100: alu_out = product_su[63:32]; // MULHSU
            5'b01101: alu_out = product_uu[63:32]; // MULHU

            default: alu_out = 32'd0;
        endcase
    end

    assign zero = (a == b);
    assign lt   = ($signed(a) < $signed(b));
    assign ltu  = (a < b);

endmodule
