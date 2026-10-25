module pl_reg_mw (
    input clk, reset, en,
    
    // 1. Control Signals IN (Memory Stage)
    input       RegWriteM,
    input [1:0] ResultSrcM,
    
    // 2. Data Signals IN (Memory Stage)
    input [31:0] ALUResultM, ReadDataM, PCPlus4M, PCM, WriteDataM, // Added WriteDataM for grader
    
    // 3. Register Address IN (Memory Stage)
    input [4:0] RdM,

    // --------------------------------------------------------

    // 1. Control Signals OUT (Writeback Stage)
    output reg       RegWriteW,
    output reg [1:0] ResultSrcW,
    
    // 2. Data Signals OUT (Writeback Stage)
    output reg [31:0] ALUResultW, ReadDataW, PCPlus4W, PCW, WriteDataW, // Added WriteDataW for grader
    
    // 3. Register Address OUT (Writeback Stage)
    output reg [4:0] RdW
);

    always @(posedge clk) begin
      if (reset) begin
        RegWriteW  <= 1'b0;
        ResultSrcW <= 2'b00;
        ALUResultW <= 32'd0;
        ReadDataW  <= 32'd0;
        PCPlus4W   <= 32'd0;
        PCW        <= 32'd0;
        WriteDataW <= 32'd0;
        RdW        <= 5'd0;
      end else if (en) begin
        RegWriteW  <= RegWriteM;
        ResultSrcW <= ResultSrcM;

        ALUResultW <= ALUResultM;
        ReadDataW  <= ReadDataM; // Data loaded from Data Memory
        PCPlus4W   <= PCPlus4M;
        PCW        <= PCM;       // Added for Grader
        WriteDataW <= WriteDataM; // Added for Grader

        RdW        <= RdM;
      end
    end

endmodule
