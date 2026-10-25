// riscv_cpu.v - single-cycle RISC-V CPU Processor

module riscv_cpu (
    input         clk, reset,
    input         ICacheStall, DCacheStall,
    output [31:0] PC,
    input  [31:0] Instr, // This is actually InstrF from the memory
    output        MemWrite, MemRead,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] Result,
    output [ 2:0] funct3,
    output [31:0] PCW, ALUResultW, WriteDataW
);

wire        ALUSrcD, RegWriteD, JalrD, JumpD, BranchD;
wire [1:0]  ResultSrcD, ImmSrcD;
wire [4:0]  ALUControlD;
wire        MemWriteD, MemReadD;

wire [31:0] InstrD;

// Hazard Unit Wires
wire StallF, StallD, FlushD, FlushE;
wire [1:0] ForwardAE, ForwardBE;

// Wires from datapath for Hazard Unit
wire [4:0] Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW;
wire RegWriteE, RegWriteM, RegWriteW;
wire [1:0] ResultSrcE;
wire PCSrcE;

// Controller now lives entirely in the Decode Stage!
controller c (
    .op(InstrD[6:0]),
    .funct3(InstrD[14:12]),
    .funct7b5(InstrD[30]),
	 .funct7b1(InstrD[25]),
    .ResultSrc(ResultSrcD),
    .MemWrite(MemWriteD),
    .MemRead(MemReadD),
    .Branch(BranchD),
    .ALUSrc(ALUSrcD),
    .RegWrite(RegWriteD),
    .Jump(JumpD),
    .Jalr(JalrD),
    .ImmSrc(ImmSrcD),
    .ALUControl(ALUControlD)
);

// Hazard Unit (The Brain)
hazard_unit hu (
    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdM(RdM), .RdW(RdW),
    .RegWriteM(RegWriteM), .RegWriteW(RegWriteW),
    .Rs1D(Rs1D), .Rs2D(Rs2D), .RdE(RdE), .ResultSrcE(ResultSrcE),
    .PCSrcE(PCSrcE),
    .ICacheStall(ICacheStall), .DCacheStall(DCacheStall),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
    .StallF(StallF), .StallD(StallD), .FlushD(FlushD), .FlushE(FlushE)
);

datapath    dp  (
    .clk(clk), .reset(reset),
    
    // Control Signals IN
    .ResultSrcD(ResultSrcD), .MemWriteD(MemWriteD), .MemReadD(MemReadD), .BranchD(BranchD), .JumpD(JumpD), .JalrD(JalrD),
    .ALUSrcD(ALUSrcD), .RegWriteD(RegWriteD), .ImmSrcD(ImmSrcD), .ALUControlD(ALUControlD),
    
    // Hazard Unit IN
    .StallF(StallF), .StallD(StallD), .FlushD(FlushD), .FlushE(FlushE),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
    .ICacheStall(ICacheStall), .DCacheStall(DCacheStall),

    // Memory IN/OUT
    .PCF(PC), .InstrF(Instr),
    .MemWriteM_out(MemWrite), .MemReadM_out(MemRead),
    .Mem_WrAddr(Mem_WrAddr), .Mem_WrData(Mem_WrData),
    .ReadDataM(ReadData),
    
    // Controller OUT
    .InstrD(InstrD),
    
    // Hazard Unit OUT
    .Rs1D(Rs1D), .Rs2D(Rs2D), .Rs1E(Rs1E), .Rs2E(Rs2E), .RdE(RdE), .RdM(RdM), .RdW(RdW),
    .RegWriteE_out(RegWriteE), .RegWriteM_out(RegWriteM), .RegWriteW_out(RegWriteW),
    .ResultSrcE_out(ResultSrcE), .PCSrcE_out(PCSrcE),
    
    // Grader OUT
    .funct3M_out(funct3),
    .ResultW(Result), .PCW(PCW), .ALUResultW(ALUResultW), .WriteDataW(WriteDataW)
);

endmodule
