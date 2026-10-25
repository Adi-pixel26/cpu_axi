module pl_reg_de (
    input clk, reset, en, clr,
    
    // 1. Control Signals IN (Decode Stage)
    input       RegWriteD, MemWriteD, MemReadD, JumpD, BranchD, ALUSrcD, JalrD,
    input [4:0] ALUControlD,
    input [1:0] ResultSrcD, 
    input [2:0] funct3D, // ADDED FOR BRANCHING
    
    // 2. Data Signals IN (Decode Stage)
    input [31:0] RD1, RD2, PCD, ImmExtD, PCPlus4D,
    input op5D, // Added for LUI/AUIPC
    
    // 3. Register Addresses IN (Decode Stage)
    input [4:0] Rs1D, Rs2D, RdD,

    // --------------------------------------------------------

    // 1. Control Signals OUT (Execute Stage)
    output reg       RegWriteE, MemWriteE, MemReadE, JumpE, BranchE, ALUSrcE, JalrE,
    output reg [4:0] ALUControlE,
    output reg [1:0] ResultSrcE,
    output reg [2:0] funct3E, // ADDED FOR BRANCHING
    
    // 2. Data Signals OUT (Execute Stage)
    output reg [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E,
    output reg op5E, // Added for LUI/AUIPC
    
    // 3. Register Addresses OUT (Execute Stage)
    output reg [4:0] Rs1E, Rs2E, RdE
);

    always @(posedge clk) begin
        if (reset || clr) begin
            RegWriteE   <= 0;
            MemWriteE   <= 0;
            MemReadE    <= 0;
            JumpE       <= 0;
            BranchE     <= 0;
            ALUSrcE     <= 0;
            JalrE       <= 0;
            ALUControlE <= 0;
            ResultSrcE  <= 0;
            funct3E     <= 0;

            RD1E        <= 0;
            RD2E        <= 0;
            PCE         <= 0;
            ImmExtE     <= 0;
            PCPlus4E    <= 0;
            op5E        <= 0;

            Rs1E        <= 0;
            Rs2E        <= 0;
            RdE         <= 0;
        end else if (en) begin
            RegWriteE   <= RegWriteD;
            MemWriteE   <= MemWriteD;
            MemReadE    <= MemReadD;
            JumpE       <= JumpD;
            BranchE     <= BranchD;
            ALUSrcE     <= ALUSrcD;
            JalrE       <= JalrD;
            ALUControlE <= ALUControlD;
            ResultSrcE  <= ResultSrcD;
            funct3E     <= funct3D;

            RD1E        <= RD1;
            RD2E        <= RD2;
            PCE         <= PCD;
            ImmExtE     <= ImmExtD;
            PCPlus4E    <= PCPlus4D;
            op5E        <= op5D;

            Rs1E        <= Rs1D;
            Rs2E        <= Rs2D;
            RdE         <= RdD;
        end
    end

endmodule
