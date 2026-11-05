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
    
    /*
     * A blocking cache wait must freeze the pipeline as one atomic state.
     * Do not clear Decode/Execute while the PC is stalled: doing so erases a
     * resolved branch/JAL/JALR before its target can be written into the PC.
     * Once the cache response arrives, cacheStall falls and the redirect plus
     * both flushes commit together on that clock edge.
     *
     * The same rule applies to a load-use bubble.  The load must first be
     * allowed to advance from Execute into Memory; only then may Execute be
     * cleared while Fetch/Decode remain held for the dependency.
     */
    assign FlushE = !cacheStall && (lwStall | PCSrcE);

    // Decode is flushed only when a control redirect can update the PC.
    assign FlushD = !cacheStall && PCSrcE;

endmodule
