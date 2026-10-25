// alu_decoder.v - RV32I + RV32M multiplication decoder

module alu_decoder (
    input            opb5,
    input      [2:0] funct3,
    input            funct7b5,
    input      [1:0] ALUOp,
    input            funct7b1,
    output reg [4:0] ALUControl
);

always @(*) begin
    // Default prevents unintended latch inference.
    ALUControl = 5'b00000;

    // RV32M multiplication instructions:
    // opcode = 0110011
    // funct7 = 0000001
    if ((ALUOp == 2'b10) && opb5 && funct7b1) begin
        case (funct3)
            3'b000: ALUControl = 5'b01010; // MUL
            3'b001: ALUControl = 5'b01011; // MULH
            3'b010: ALUControl = 5'b01100; // MULHSU
            3'b011: ALUControl = 5'b01101; // MULHU

            3'b100: ALUControl = 5'b01110; // DIV
				3'b101: ALUControl = 5'b01111; // DIVU
				3'b110: ALUControl = 5'b10000; // REM
				3'b111: ALUControl = 5'b10001; // REMU
				
            default: ALUControl = 5'b00000;
        endcase
    end else begin
        case (ALUOp)
            2'b00: begin
                ALUControl = 5'b00000; // ADD for loads/stores
            end

            2'b01: begin
                ALUControl = 5'b00001; // SUB for branches
            end

            default: begin
                case (funct3)
                    3'b000: begin
                        if (funct7b5 && opb5)
                            ALUControl = 5'b00001; // SUB
                        else
                            ALUControl = 5'b00000; // ADD / ADDI
                    end

                    3'b001: ALUControl = 5'b00111; // SLL / SLLI
                    3'b010: ALUControl = 5'b00101; // SLT / SLTI
                    3'b011: ALUControl = 5'b00110; // SLTU / SLTIU
                    3'b100: ALUControl = 5'b00100; // XOR / XORI

                    3'b101: begin
                        if (funct7b5)
                            ALUControl = 5'b01001; // SRA / SRAI
                        else
                            ALUControl = 5'b01000; // SRL / SRLI
                    end

                    3'b110: ALUControl = 5'b00011; // OR / ORI
                    3'b111: ALUControl = 5'b00010; // AND / ANDI

                    default: ALUControl = 5'b00000;
                endcase
            end
        endcase
    end
end

endmodule
