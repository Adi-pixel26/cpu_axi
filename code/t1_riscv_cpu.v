// t1_riscv_cpu.v - Top Module to test riscv_cpu

module t1_riscv_cpu (
    input         clk, reset,
    input         Ext_MemWrite,
    input  [31:0] Ext_WriteData, Ext_DataAdr,
    output        MemWrite,
    output [31:0] WriteData, DataAdr, ReadData,
    output [31:0] PC, Result
);

wire [31:0] Instr;
wire [31:0] DataAdr_rv32, WriteData_rv32;
wire        MemWrite_rv32;
wire        MemRead_rv32;
wire [2:0]  funct3;
wire [31:0] PCW, ALUResultW, WriteDataW;

riscv_cpu rvcpu (
    .clk(clk), .reset(reset),
    .ICacheStall(1'b0), .DCacheStall(1'b0),
    .PC(PC), .Instr(Instr),
    .MemWrite(MemWrite_rv32), .MemRead(MemRead_rv32),
    .Mem_WrAddr(DataAdr_rv32), .Mem_WrData(WriteData_rv32),
    .ReadData(ReadData), .Result(Result), .funct3(funct3),
    .PCW(PCW), .ALUResultW(ALUResultW), .WriteDataW(WriteDataW)
);
instr_mem instrmem (PC, Instr);
data_mem  datamem  (clk, MemWrite, funct3, DataAdr, WriteData, ReadData);

assign MemWrite  = (Ext_MemWrite && reset) ? 1'b1 : MemWrite_rv32;
assign WriteData = (Ext_MemWrite && reset) ? Ext_WriteData : WriteData_rv32;
assign DataAdr   = reset ? Ext_DataAdr : DataAdr_rv32;  // ← NO offset, raw ALU result

endmodule
