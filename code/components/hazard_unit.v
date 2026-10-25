// hazard_unit.v
module hazard_unit (
    // Data Forwarding Inputs
    input [4:0] Rs1E, Rs2E,
    input [4:0] RdM, RdW,
    input       RegWriteM, RegWriteW,

    // Load-Use Stall Inputs
    input [4:0] Rs1D, Rs2D, RdE,
    input [1:0] ResultSrcE,

    // Control Hazard Inputs
    input       PCSrcE,

    // Blocking cache wait inputs
    input       ICacheStall, DCacheStall,

    // Outputs
    output reg [1:0] ForwardAE, ForwardBE,
    output           StallF, StallD, FlushD, FlushE
);

    // ==========================================
    // 1. DATA FORWARDING (Solve Data Hazards)
    // ==========================================
    always @(*) begin
        // Forwarding for Source A
        if (((Rs1E == RdM) && RegWriteM) && (Rs1E != 0)) begin
            ForwardAE = 2'b10; // Forward from Memory stage (ALUResultM)
        end else if (((Rs1E == RdW) && RegWriteW) && (Rs1E != 0)) begin
            ForwardAE = 2'b01; // Forward from Writeback stage (ResultW)
        end else begin
            ForwardAE = 2'b00; // No forwarding
        end

        // Forwarding for Source B
        if (((Rs2E == RdM) && RegWriteM) && (Rs2E != 0)) begin
            ForwardBE = 2'b10; // Forward from Memory stage
        end else if (((Rs2E == RdW) && RegWriteW) && (Rs2E != 0)) begin
            ForwardBE = 2'b01; // Forward from Writeback stage
        end else begin
            ForwardBE = 2'b00; // No forwarding
        end
    end

    // ==========================================
    // 2. LOAD-USE STALLS
    // ==========================================
    // If the instruction in Execute is a Load (ResultSrcE == 2'b01)
    // and its destination (RdE) matches the current source registers in Decode
    wire lwStall = (ResultSrcE == 2'b01) && ((Rs1D == RdE) || (Rs2D == RdE));

    // ==========================================
    // 3. CONTROL HAZARDS (Branches/Jumps)
    // ==========================================
    // If a branch is taken, PCSrcE goes high. We must flush Decode and Execute!

    wire cacheStall = ICacheStall | DCacheStall;

    assign StallF = lwStall | cacheStall;
    assign StallD = lwStall | cacheStall;
    
    // We flush Execute if there is a Load-Use Stall OR a Control Hazard
    // Cache waits hold the pipeline registers; they do not insert a bubble.
    assign FlushE = lwStall | PCSrcE;
    
    // We flush Decode ONLY on Control Hazards
    assign FlushD = PCSrcE;

endmodule
