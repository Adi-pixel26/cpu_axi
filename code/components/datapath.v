// datapath.v
module datapath (
    input         clk, reset,
    
    // Control Signals from Controller (Decode Stage)
    input [1:0]   ResultSrcD,
    input         MemWriteD, MemReadD,
    input         BranchD, JumpD, JalrD,
    input         ALUSrcD, RegWriteD,
    input [1:0]   ImmSrcD,
    input [4:0]   ALUControlD,
    
    // Hazard Unit Signals (Will be driven later)
    input         StallF, StallD, FlushD, FlushE,
    input [1:0]   ForwardAE, ForwardBE,
    input         ICacheStall, DCacheStall,

    // Memory Ports
    output [31:0] PCF,
    input  [31:0] InstrF,
    output        MemWriteM_out, MemReadM_out,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadDataM,
    
    // To Controller
    output [31:0] InstrD,
    
    // To Hazard Unit
    output [4:0]  Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW,
    output        RegWriteE_out, RegWriteM_out, RegWriteW_out,
    output [1:0]  ResultSrcE_out,
    output        PCSrcE_out, // Added for Hazard Unit flushes!
    
    // Grader Ports
    output [2:0]  funct3M_out, // Added for data_mem
    output [31:0] ResultW, PCW, ALUResultW, WriteDataW
);

// ==========================================
// --- WIRES ---
// ==========================================
// Fetch
wire [31:0] PCNext, PCPlus4F, PCJalr;
// Decode
wire [31:0] PCD, PCPlus4D, ImmExtD, RD1, RD2;
// Execute
wire        RegWriteE, MemWriteE, MemReadE, JumpE, BranchE, ALUSrcE, JalrE;
wire [4:0]  ALUControlE;
wire [1:0]  ResultSrcE;
wire [2:0]  funct3E;
wire [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E;
wire [31:0] SrcAE, SrcBE, WriteDataE, NormalALUResultE, ALUResultE, PCTargetE;
wire [31:0] ForwardedA, JalrSumE, JalrTargetE;
wire        ZeroE, LessThanE, LessThanUnsignedE, TakeBranch;
wire        PCSrcE;
wire        IsDivisionE, IsRemainderE, SignedDivisionE;
wire        DividerStart, DividerBusy, DividerResultValid, DividerResultReady;
wire        DivisionHold;
wire [31:0] DividerQuotient, DividerRemainder;
wire        RegWriteEToM, MemWriteEToM, MemReadEToM;
// Memory
wire        RegWriteM, MemWriteM, MemReadM;
wire [1:0]  ResultSrcM;
wire [2:0]  funct3M;
wire [31:0] ALUResultM, WriteDataM, PCPlus4M, PCM;
// Writeback
wire        RegWriteW;
wire [1:0]  ResultSrcW;
wire [31:0] ReadDataW, PCPlus4W;

// A blocking cache transaction freezes every pipeline stage. Load-use
// stalls still use the existing F/D hold plus E-stage bubble behavior.
wire PipelineEnable = !(ICacheStall | DCacheStall);
wire StallFWithDivision = StallF | DivisionHold;
wire StallDWithDivision = StallD | DivisionHold;


// ==========================================
// 1. FETCH STAGE
// ==========================================
mux2 #(32)     pcmux(PCPlus4F, PCTargetE, PCSrcE, PCNext);
// JALR needs only rs1 + immediate. Keep the PC path out of the general ALU's
// multiply/result mux; RISC-V also requires the target's low bit to be zero.
mux2 #(32)     jalrmux(PCNext, JalrTargetE, JalrE, PCJalr);

reset_ff #(32) pcreg(clk, reset, StallFWithDivision, PCJalr, PCF);
adder          pcadd4(PCF, 32'd4, PCPlus4F);

// --- PIPELINE REGISTER F/D ---
pl_reg_fd pl_fd (
    .clk(clk), .en(StallDWithDivision), .clr(reset | FlushD),
    .InstrF(InstrF), .PCF(PCF), .PCPlus4F(PCPlus4F),
    .InstrD(InstrD), .PCD(PCD), .PCPlus4D(PCPlus4D)
);


// ==========================================
// 2. DECODE STAGE
// ==========================================
assign Rs1D = InstrD[19:15];
assign Rs2D = InstrD[24:20];
wire [4:0] RdD = InstrD[11:7];

reg_file       rf (clk, RegWriteW, Rs1D, Rs2D, RdW, ResultW, RD1, RD2);
wire [31:0] NormalImmExtD;
imm_extend     ext (InstrD[31:7], ImmSrcD, NormalImmExtD);
// LUI and AUIPC Bypass imm_extend entirely!
assign ImmExtD = (ResultSrcD == 2'b11) ? {InstrD[31:12], 12'b0} : NormalImmExtD;

// --- PIPELINE REGISTER D/E ---
wire op5E;
pl_reg_de pl_de (
    .clk(clk), .reset(reset), .en(PipelineEnable && !DivisionHold), .clr(FlushE),
    .RegWriteD(RegWriteD), .MemWriteD(MemWriteD), .MemReadD(MemReadD), .JumpD(JumpD), .BranchD(BranchD), .ALUSrcD(ALUSrcD), .JalrD(JalrD),
    .ALUControlD(ALUControlD), .ResultSrcD(ResultSrcD), .funct3D(InstrD[14:12]), .op5D(InstrD[5]),
    .RD1(RD1), .RD2(RD2), .PCD(PCD), .ImmExtD(ImmExtD), .PCPlus4D(PCPlus4D),
    .Rs1D(Rs1D), .Rs2D(Rs2D), .RdD(RdD),

    .RegWriteE(RegWriteE), .MemWriteE(MemWriteE), .MemReadE(MemReadE), .JumpE(JumpE), .BranchE(BranchE), .ALUSrcE(ALUSrcE), .JalrE(JalrE),
    .ALUControlE(ALUControlE), .ResultSrcE(ResultSrcE), .funct3E(funct3E), .op5E(op5E),
    .RD1E(RD1E), .RD2E(RD2E), .PCE(PCE), .ImmExtE(ImmExtE), .PCPlus4E(PCPlus4E),
    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdE(RdE)
);


// ==========================================
// 3. EXECUTE STAGE
// ==========================================
// Forwarding Muxes (Ready for Hazard Unit)
mux3 #(32)     fa_mux(RD1E, ResultW, ALUResultM, ForwardAE, ForwardedA);
mux3 #(32)     fb_mux(RD2E, ResultW, ALUResultM, ForwardBE, WriteDataE);

adder          jalradd(ForwardedA, ImmExtE, JalrSumE);
assign JalrTargetE = {JalrSumE[31:1], 1'b0};

// A Mux (For LUI and AUIPC)
assign SrcAE = (ResultSrcE == 2'b11) ? (op5E ? 32'd0 : PCE) : ForwardedA;

mux2 #(32)     srcbmux(WriteDataE, ImmExtE, ALUSrcE, SrcBE);
alu            alu (SrcAE, SrcBE, ALUControlE, NormalALUResultE, ZeroE, LessThanE, LessThanUnsignedE);

assign IsDivisionE = (ALUControlE == 5'b01110) ||
                     (ALUControlE == 5'b01111) ||
                     (ALUControlE == 5'b10000) ||
                     (ALUControlE == 5'b10001);

assign IsRemainderE = (ALUControlE == 5'b10000) ||
                      (ALUControlE == 5'b10001);

assign SignedDivisionE = (ALUControlE == 5'b01110) ||
                         (ALUControlE == 5'b10000);

assign DividerStart = IsDivisionE && !DividerBusy && !DividerResultValid;
assign DivisionHold = IsDivisionE && !DividerResultValid;
assign DividerResultReady = DividerResultValid && IsDivisionE && PipelineEnable;

rv32_divider divider (
    .clk          (clk),
    .reset        (reset),
    .start        (DividerStart),
    .signed_mode  (SignedDivisionE),
    .dividend     (SrcAE),
    .divisor      (SrcBE),
    .busy         (DividerBusy),
    .result_valid (DividerResultValid),
    .result_ready (DividerResultReady),
    .quotient     (DividerQuotient),
    .remainder    (DividerRemainder)
);

assign ALUResultE = IsDivisionE
                  ? (IsRemainderE ? DividerRemainder : DividerQuotient)
                  : NormalALUResultE;

// Keep the divide in Execute and send bubbles into Memory while it runs.
// This lets older Memory/Writeback instructions finish exactly once.
assign RegWriteEToM = RegWriteE && !DivisionHold;
assign MemWriteEToM = MemWriteE && !DivisionHold;
assign MemReadEToM  = MemReadE  && !DivisionHold;

// Branch Math
adder          pcaddbranch(PCE, ImmExtE, PCTargetE);
assign TakeBranch = (funct3E == 3'b000) ? ZeroE :							
                    (funct3E == 3'b001) ? ~ZeroE :							
                    (funct3E == 3'b100) ? LessThanE :            
                    (funct3E == 3'b101) ? ~LessThanE :            
                    (funct3E == 3'b110) ? LessThanUnsignedE :     
                    (funct3E == 3'b111) ? ~LessThanUnsignedE :    
                    1'b0;
assign PCSrcE = (BranchE & TakeBranch) | JumpE | JalrE;

// --- PIPELINE REGISTER E/M ---
pl_reg_em pl_em (
    .clk(clk), .reset(reset), .en(PipelineEnable),
    .RegWriteE(RegWriteEToM), .MemWriteE(MemWriteEToM), .MemReadE(MemReadEToM), .ResultSrcE(ResultSrcE),
    .ALUResultE(ALUResultE), .WriteDataE(WriteDataE), .PCPlus4E(PCPlus4E), .PCE(PCE), .funct3E(funct3E),
    .RdE(RdE),

    .RegWriteM(RegWriteM), .MemWriteM(MemWriteM), .MemReadM(MemReadM), .ResultSrcM(ResultSrcM),
    .ALUResultM(ALUResultM), .WriteDataM(WriteDataM), .PCPlus4M(PCPlus4M), .PCM(PCM), .funct3M(funct3M),
    .RdM(RdM)
);


// ==========================================
// 4. MEMORY STAGE
// ==========================================
assign Mem_WrAddr = ALUResultM;
assign Mem_WrData = WriteDataM;
assign MemWriteM_out = MemWriteM;
assign MemReadM_out = MemReadM;
assign funct3M_out = funct3M;

// --- PIPELINE REGISTER M/W ---
pl_reg_mw pl_mw (
    .clk(clk), .reset(reset), .en(PipelineEnable),
    .RegWriteM(RegWriteM), .ResultSrcM(ResultSrcM),
    .ALUResultM(ALUResultM), .ReadDataM(ReadDataM), .PCPlus4M(PCPlus4M), .PCM(PCM), .WriteDataM(WriteDataM),
    .RdM(RdM),

    .RegWriteW(RegWriteW), .ResultSrcW(ResultSrcW),
    .ALUResultW(ALUResultW), .ReadDataW(ReadDataW), .PCPlus4W(PCPlus4W), .PCW(PCW), .WriteDataW(WriteDataW),
    .RdW(RdW)
);


// ==========================================
// 5. WRITEBACK STAGE
// ==========================================
assign ResultW = (ResultSrcW == 2'b00) ? ALUResultW :
                 (ResultSrcW == 2'b01) ? ReadDataW :
                 (ResultSrcW == 2'b10) ? PCPlus4W :
                 (ResultSrcW == 2'b11) ? ALUResultW : 32'd0;

// Outputting values for Hazard Unit
assign RegWriteE_out = RegWriteE;
assign RegWriteM_out = RegWriteM;
assign RegWriteW_out = RegWriteW;
assign ResultSrcE_out = ResultSrcE;
assign PCSrcE_out = PCSrcE;

endmodule
