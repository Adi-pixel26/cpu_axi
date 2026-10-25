// load_store_adapter.v
//
// Converts the RV32I byte/halfword/word memory operation in the CPU's
// Memory stage to the aligned 32-bit word interface used by the D-cache.
// The D-cache always returns one aligned raw word.  This block performs
// the byte selection and signed/unsigned extension required by loads.

module load_store_adapter (
    input  wire [31:0] address,
    input  wire [2:0]  funct3,
    input  wire [31:0] store_data,
    input  wire [31:0] raw_load_data,

    output reg  [31:0] aligned_store_data,
    output reg  [3:0]  store_strobe,
    output reg  [31:0] formatted_load_data,
    output wire        misaligned
);

    wire [4:0] byte_shift;
    wire [31:0] shifted_load_data;

    assign byte_shift = {address[1:0], 3'b000};
    assign shifted_load_data = raw_load_data >> byte_shift;

    /*
     * RV32I requires naturally aligned halfword and word accesses unless
     * the implementation provides explicit misaligned-access support.
     * The current CPU has no exception unit, so this is exported for the
     * future trap controller and for simulation diagnostics.
     */
    assign misaligned =
        ((funct3[1:0] == 2'b01) && address[0]) ||
        ((funct3[1:0] == 2'b10) && (|address[1:0]));

    /* Align CPU store data to the addressed byte lanes. */
    always @(*) begin
        aligned_store_data = store_data;
        store_strobe       = 4'b0000;

        case (funct3)
            3'b000: begin // SB
                case (address[1:0])
                    2'b00: begin
                        aligned_store_data = {24'b0, store_data[7:0]};
                        store_strobe       = 4'b0001;
                    end
                    2'b01: begin
                        aligned_store_data = {16'b0, store_data[7:0], 8'b0};
                        store_strobe       = 4'b0010;
                    end
                    2'b10: begin
                        aligned_store_data = {8'b0, store_data[7:0], 16'b0};
                        store_strobe       = 4'b0100;
                    end
                    default: begin
                        aligned_store_data = {store_data[7:0], 24'b0};
                        store_strobe       = 4'b1000;
                    end
                endcase
            end

            3'b001: begin // SH
                if (address[1] == 1'b0) begin
                    aligned_store_data = {16'b0, store_data[15:0]};
                    store_strobe       = 4'b0011;
                end else begin
                    aligned_store_data = {store_data[15:0], 16'b0};
                    store_strobe       = 4'b1100;
                end
            end

            3'b010: begin // SW
                aligned_store_data = store_data;
                store_strobe       = 4'b1111;
            end

            default: begin
                aligned_store_data = store_data;
                store_strobe       = 4'b0000;
            end
        endcase
    end

    /* Select the addressed byte/halfword and apply RV32I extension. */
    always @(*) begin
        case (funct3)
            3'b000: // LB
                formatted_load_data =
                    {{24{shifted_load_data[7]}}, shifted_load_data[7:0]};

            3'b001: // LH
                formatted_load_data =
                    {{16{shifted_load_data[15]}}, shifted_load_data[15:0]};

            3'b010: // LW
                formatted_load_data = raw_load_data;

            3'b100: // LBU
                formatted_load_data = {24'b0, shifted_load_data[7:0]};

            3'b101: // LHU
                formatted_load_data = {16'b0, shifted_load_data[15:0]};

            default:
                formatted_load_data = raw_load_data;
        endcase
    end

endmodule
