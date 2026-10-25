// controller.v - controller for RISC-V CPU

module controller (
    input [6:0]  op,
    input [2:0]  funct3,
    input        funct7b5,
	 input        funct7b1,
    // (Zero, LessThan, LessThanUnsigned removed because they are in Execute stage now!)
    output       [1:0] ResultSrc,
    output       MemWrite, MemRead,
    output       Branch, ALUSrc,
    output       RegWrite, Jump, Jalr,
    output [1:0] ImmSrc,
    output [4:0] ALUControl
);

wire [1:0] ALUOp;

// A load is the only base RV32I instruction that reads data memory.
assign MemRead = (op == 7'b0000011);

main_decoder    md (op, ResultSrc, MemWrite, Branch,
                    ALUSrc, RegWrite, Jump, Jalr , ImmSrc, ALUOp);

alu_decoder     ad (op[5], funct3, funct7b5, ALUOp,funct7b1, ALUControl);

// PCSrc and TakeBranch math has been physically moved to datapath.v 
// so it can happen safely in the Execute stage!

endmodule
