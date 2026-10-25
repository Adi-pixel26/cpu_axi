module data_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 64) (
    input                       clk, wr_en,
    input  [2:0]                funct3,
    input  [ADDR_WIDTH-1:0]     wr_addr, wr_data,
    output reg [DATA_WIDTH-1:0] rd_data_mem
);

reg [DATA_WIDTH-1:0] data_ram [0:MEM_SIZE-1];

integer i;
initial begin
    for (i = 0; i < MEM_SIZE; i = i + 1)
        data_ram[i] = 32'h00000000;
end

wire [29:0] word_addr   = wr_addr[ADDR_WIDTH-1:2] % MEM_SIZE;
wire [1:0]  byte_offset = wr_addr[1:0];

// STORE
always @(posedge clk) begin
    if (wr_en) begin
        case (funct3)
            3'b000: begin // SB
                case (byte_offset)
                    2'b00: data_ram[word_addr][7:0]   <= wr_data[7:0];
                    2'b01: data_ram[word_addr][15:8]  <= wr_data[7:0];
                    2'b10: data_ram[word_addr][23:16] <= wr_data[7:0];
                    2'b11: data_ram[word_addr][31:24] <= wr_data[7:0];
                endcase
            end
            3'b001: begin // SH
                case (byte_offset)
                    2'b00: data_ram[word_addr][15:0]  <= wr_data[15:0];
                    2'b10: data_ram[word_addr][31:16] <= wr_data[15:0];
                    default: data_ram[word_addr][15:0] <= wr_data[15:0];
                endcase
            end
            default: data_ram[word_addr] <= wr_data; // SW
        endcase
    end
end

// LOAD
wire [31:0] raw = data_ram[word_addr];

always @(*) begin
    case (funct3)
        3'b000: begin // LB
            case (byte_offset)
                2'b00: rd_data_mem = {{24{raw[7]}},  raw[7:0]};
                2'b01: rd_data_mem = {{24{raw[15]}}, raw[15:8]};
                2'b10: rd_data_mem = {{24{raw[23]}}, raw[23:16]};
                2'b11: rd_data_mem = {{24{raw[31]}}, raw[31:24]};
                default: rd_data_mem = raw;
            endcase
        end
        3'b001: begin // LH
            case (byte_offset)
                2'b00: rd_data_mem = {{16{raw[15]}}, raw[15:0]};
                2'b10: rd_data_mem = {{16{raw[31]}}, raw[31:16]};
                default: rd_data_mem = {{16{raw[15]}}, raw[15:0]};
            endcase
        end
        3'b010: rd_data_mem = raw; // LW
        3'b100: begin // LBU
            case (byte_offset)
                2'b00: rd_data_mem = {24'b0, raw[7:0]};
                2'b01: rd_data_mem = {24'b0, raw[15:8]};
                2'b10: rd_data_mem = {24'b0, raw[23:16]};
                2'b11: rd_data_mem = {24'b0, raw[31:24]};
                default: rd_data_mem = raw;
            endcase
        end
        3'b101: begin // LHU
            case (byte_offset)
                2'b00: rd_data_mem = {16'b0, raw[15:0]};
                2'b10: rd_data_mem = {16'b0, raw[31:16]};
                default: rd_data_mem = {16'b0, raw[15:0]};
            endcase
        end
        default: rd_data_mem = raw;
    endcase
end

endmodule