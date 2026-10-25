module axi_slave_memory (
    input  wire        ACLK,
    input  wire        ARESETn,

    // 1. AXI Write Address Channel (AW)
    input  wire [31:0] AWADDR,
    input  wire        AWVALID,
    output reg         AWREADY,

    // 2. AXI Write Data Channel (W)
    input  wire [31:0] WDATA,
    input  wire [3:0]  WSTRB,
    input  wire        WVALID,
    output reg         WREADY,

    // 3. AXI Write Response Channel (B)
    output reg  [1:0]  BRESP,
    output reg         BVALID,
    input  wire        BREADY,

    // 4. AXI Read Address Channel (AR)
    input  wire [31:0] ARADDR,
    input  wire        ARVALID,
    output reg         ARREADY,

    // 5. AXI Read Data Channel (R)
    output reg  [31:0] RDATA,
    output reg  [1:0]  RRESP,
    output reg         RVALID,
    input  wire        RREADY
);

    // =========================================================================
    // THE ACTUAL PHYSICAL MEMORY
    // We are creating 1024 words of memory (4 Kilobytes). 
    // This will hold BOTH your instructions and your data!
    // =========================================================================
    reg [31:0] RAM [0:1023];

    // Load your eYantra test code into the RAM when the FPGA turns on
    initial begin
        $readmemh("basic_test.hex", RAM);
    end

    // =========================================================================
    // AXI SLAVE STATE MACHINE
    // =========================================================================
    parameter IDLE       = 2'b00;
    parameter WRITE_RESP = 2'b01;
    parameter READ_RESP  = 2'b10;

    reg [1:0] state;

    always @(posedge ACLK) begin
        if (ARESETn == 0) begin
            state   <= IDLE;
            AWREADY <= 0;
            WREADY  <= 0;
            BVALID  <= 0;
            ARREADY <= 0;
            RVALID  <= 0;
            BRESP   <= 2'b00; // OKAY response
            RRESP   <= 2'b00; // OKAY response
        end else begin
            case (state)
                IDLE: begin
                    // Clear response signals
                    BVALID <= 0;
                    RVALID <= 0;

                    // As you read in the manual, defaulting READY to 1 makes the bus faster!
                    AWREADY <= 1;
                    WREADY  <= 1;
                    ARREADY <= 1;

                    // ---------------------------------------------------
                    // HANDLE WRITE REQUESTS
                    // ---------------------------------------------------
                    if (AWVALID == 1 && WVALID == 1) begin
                        // Master wants to write. We instantly accept it.
                        AWREADY <= 0;
                        WREADY  <= 0;
                        ARREADY <= 0;
                        
                        // Save the data into RAM! (Using word addressing: shift right by 2)
                        // Note: A real memory would use WSTRB here, but we are keeping it simple
                        RAM[AWADDR[11:2]] <= WDATA;
                        
                        state <= WRITE_RESP;
                    end 
                    
                    // ---------------------------------------------------
                    // HANDLE READ REQUESTS
                    // ---------------------------------------------------
                    else if (ARVALID == 1) begin
                        // Master wants to read. We instantly accept the address.
                        AWREADY <= 0;
                        WREADY  <= 0;
                        ARREADY <= 0;
                        
                        // Fetch the data from RAM and put it on the wire!
                        RDATA <= RAM[ARADDR[11:2]];
                        
                        state <= READ_RESP;
                    end
                end

                WRITE_RESP: begin
                    // Tell the master the write was successful
                    BVALID <= 1;
                    
                    if (BREADY == 1 && BVALID == 1) begin
                        // Master took our receipt. Transaction over.
                        BVALID <= 0;
                        state  <= IDLE;
                    end
                end

                READ_RESP: begin
                    // Tell the master the data is ready on the wire
                    RVALID <= 1;
                    
                    if (RREADY == 1 && RVALID == 1) begin
                        // Master took the data. Transaction over.
                        RVALID <= 0;
                        state  <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule