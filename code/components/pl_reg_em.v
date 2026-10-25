module pl_reg_em (
    input clk, reset, en,
    
    // 1. Control Signals IN (Execute Stage)
    input       RegWriteE, MemWriteE, MemReadE,
    input [1:0] ResultSrcE,
    
    // 2. Data Signals IN (Execute Stage)
    input [31:0] ALUResultE, WriteDataE, PCPlus4E, PCE, // Added PCE for grader
    input [2:0] funct3E, // Added for memory size
    
    // 3. Register Address IN (Execute Stage)
    input [4:0] RdE,

    // --------------------------------------------------------

    // 1. Control Signals OUT (Memory Stage)
    output reg       RegWriteM, MemWriteM, MemReadM,
    output reg [1:0] ResultSrcM,
    
    // 2. Data Signals OUT (Memory Stage)
    output reg [31:0] ALUResultM, WriteDataM, PCPlus4M, PCM, // Added PCM for grader
    output reg [2:0] funct3M, // Added for memory size
    
    // 3. Register Address OUT (Memory Stage)
    output reg [4:0] RdM
);

    always @(posedge clk) begin
      if (reset) begin
        RegWriteM  <= 1'b0;
        MemWriteM  <= 1'b0;
        MemReadM   <= 1'b0;
        ResultSrcM <= 2'b00;
        ALUResultM <= 32'd0;
        WriteDataM <= 32'd0;
        PCPlus4M   <= 32'd0;
        PCM        <= 32'd0;
        funct3M    <= 3'd0;
        RdM        <= 5'd0;
      end else if (en) begin
        RegWriteM  <= RegWriteE;
        MemWriteM  <= MemWriteE;
        MemReadM   <= MemReadE;
        ResultSrcM <= ResultSrcE;

        ALUResultM <= ALUResultE;
        WriteDataM <= WriteDataE; // The forwarded data going to Data Memory
        PCPlus4M   <= PCPlus4E;
        PCM        <= PCE;        // Added for Grader
        funct3M    <= funct3E;

        RdM        <= RdE;
      end
    end

endmodule
