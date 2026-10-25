// sdram_model_16_sim.v
//
// Small behavioral model of the 16-bit SDR SDRAM command interface used by
// sdram_system_1.  It is for RTL simulation only.  It implements ACTIVE,
// READ, WRITE and PRECHARGE commands and fixed CAS latency 3.  Timing
// violations and refresh retention are intentionally not modeled.
//
// Storage is direct-mapped and sparse.  It is sufficient for the provided
// tests, which write and read one region before moving to another region.

`timescale 1ns/1ps

module sdram_model_16_sim #(
    parameter integer CAS_LATENCY  = 3,
    parameter integer STORAGE_WORDS = 65536,
    parameter integer INDEX_BITS    = 16
) (
    input  wire        clk,
    input  wire        cke,
    input  wire        cs_n,
    input  wire        ras_n,
    input  wire        cas_n,
    input  wire        we_n,
    input  wire [12:0] addr,
    input  wire [1:0]  ba,
    inout  wire [15:0] dq,
    input  wire [1:0]  dqm
);

    reg [15:0] mem_data [0:STORAGE_WORDS-1];
    reg [8:0]  mem_tag  [0:STORAGE_WORDS-1];
    reg        mem_valid[0:STORAGE_WORDS-1];

    reg [12:0] open_row [0:3];
    reg        open_valid[0:3];

    reg [15:0] read_data_pipe [0:CAS_LATENCY-1];
    reg        read_valid_pipe[0:CAS_LATENCY-1];

    reg [15:0] dq_out;
    reg        dq_oe;
    reg [15:0] loaded_data;

    integer i;
    integer bank_index;

    assign dq = dq_oe ? dq_out : 16'hzzzz;

    function [24:0] make_linear_address;
        input [1:0]  bank_value;
        input [12:0] row_value;
        input [9:0]  column_value;
        begin
            // Inverse of the generated controller's mapping:
            // bank={avalon_address[24],avalon_address[10]},
            // row=avalon_address[23:11], column=avalon_address[9:0].
            make_linear_address = {bank_value[1], row_value,
                                   bank_value[0], column_value};
        end
    endfunction

    function [15:0] load_halfword;
        input [24:0] halfword_address;
        integer index_value;
        begin
            index_value = halfword_address[INDEX_BITS-1:0];
            if (mem_valid[index_value] &&
                (mem_tag[index_value] == halfword_address[24:16]))
                load_halfword = mem_data[index_value];
            else
                load_halfword = 16'h0000;
        end
    endfunction

    task store_halfword;
        input [24:0] halfword_address;
        input [15:0] value;
        input [1:0]  byte_mask;
        integer index_value;
        begin
            index_value = halfword_address[INDEX_BITS-1:0];

            if (!mem_valid[index_value] ||
                (mem_tag[index_value] != halfword_address[24:16]))
                mem_data[index_value] = 16'h0000;

            mem_valid[index_value] = 1'b1;
            mem_tag[index_value]   = halfword_address[24:16];

            // SDRAM DQM is active high: 1 masks that byte.
            if (!byte_mask[0])
                mem_data[index_value][7:0] = value[7:0];
            if (!byte_mask[1])
                mem_data[index_value][15:8] = value[15:8];
        end
    endtask

    // Convenient preload hook used by the CPU/Qsys integration testbench.
    task write_word;
        input [31:0] byte_address;
        input [31:0] value;
        begin
            store_halfword(byte_address[25:1], value[15:0], 2'b00);
            store_halfword(byte_address[25:1] + 25'd1,
                           value[31:16], 2'b00);
        end
    endtask

    initial begin
        dq_out = 16'd0;
        dq_oe  = 1'b0;

        for (i = 0; i < STORAGE_WORDS; i = i + 1) begin
            mem_data[i]  = 16'd0;
            mem_tag[i]   = 9'd0;
            mem_valid[i] = 1'b0;
        end

        for (i = 0; i < 4; i = i + 1) begin
            open_row[i]   = 13'd0;
            open_valid[i] = 1'b0;
        end

        for (i = 0; i < CAS_LATENCY; i = i + 1) begin
            read_data_pipe[i]  = 16'd0;
            read_valid_pipe[i] = 1'b0;
        end
    end

    // Capture SDRAM commands on their rising clock edge.
    always @(posedge clk) begin
        for (i = CAS_LATENCY - 1; i > 0; i = i - 1) begin
            read_data_pipe[i]  <= read_data_pipe[i-1];
            read_valid_pipe[i] <= read_valid_pipe[i-1];
        end
        read_data_pipe[0]  <= 16'd0;
        read_valid_pipe[0] <= 1'b0;

        if (cke && !cs_n) begin
            bank_index = ba;

            case ({ras_n, cas_n, we_n})
                3'b011: begin // ACTIVE
                    open_row[bank_index]   <= addr;
                    open_valid[bank_index] <= 1'b1;
                end

                3'b101: begin // READ
                    if (open_valid[bank_index]) begin
                        loaded_data = load_halfword(
                            make_linear_address(ba, open_row[bank_index],
                                                addr[9:0]));
                        if (dqm[0])
                            loaded_data[7:0] = 8'h00;
                        if (dqm[1])
                            loaded_data[15:8] = 8'h00;

                        read_data_pipe[0]  <= loaded_data;
                        read_valid_pipe[0] <= 1'b1;
                    end
                end

                3'b100: begin // WRITE
                    if (open_valid[bank_index])
                        store_halfword(
                            make_linear_address(ba, open_row[bank_index],
                                                addr[9:0]),
                            dq, dqm);
                end

                3'b010: begin // PRECHARGE
                    if (addr[10]) begin
                        open_valid[0] <= 1'b0;
                        open_valid[1] <= 1'b0;
                        open_valid[2] <= 1'b0;
                        open_valid[3] <= 1'b0;
                    end else begin
                        open_valid[bank_index] <= 1'b0;
                    end
                end

                default: begin
                    // NOP, AUTO REFRESH and MODE REGISTER SET do not need
                    // additional behavior for this functional model.
                end
            endcase
        end
    end

    // Put read data on DQ half a cycle before the controller samples it.
    always @(negedge clk) begin
        if (read_valid_pipe[CAS_LATENCY-1]) begin
            dq_out <= read_data_pipe[CAS_LATENCY-1];
            dq_oe  <= 1'b1;
        end else begin
            dq_oe <= 1'b0;
        end
    end

endmodule
