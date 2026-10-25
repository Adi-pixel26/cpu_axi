module axi_master (
    input  wire        ACLK,
    input  wire        ARESETn,   // Active-low reset

    // CPU Interface write 
    input  wire        cpu_write_req,  // Trigger signal from CPU
    input  wire [31:0] cpu_address,    // Target address
    input  wire [31:0] cpu_data,       // Data payload
    output reg         cpu_write_done, // High for 1 cycle when transaction completes
    output reg         cpu_write_error,

	 //CPU INTERFACE read
	 input wire         cpu_read_req,
	 output reg [31:0]  cpu_read_data,
	 output reg         cpu_read_done,
	 output reg         cpu_read_error,
	 
	 
    // 1. AXI Write Address Channel (AW)
    output reg  [31:0] AWADDR,
    output reg         AWVALID,
    input  wire        AWREADY,

    // 2. AXI Write Data Channel (W)
    output reg  [31:0] WDATA,
    output reg  [3:0]  WSTRB,   
    output reg         WVALID,
    input  wire        WREADY,

    // 3. AXI Write Response Channel (B)
    input  wire [1:0]  BRESP,   
    input  wire        BVALID,
    output reg         BREADY,
    
    // (Read channels omitted for brevity, but declared in hardware)
    output reg  [31:0] ARADDR,
    output reg         ARVALID,
    input  wire        ARREADY,
    input  wire [31:0] RDATA,
    input  wire [1:0]  RRESP,
    input  wire        RVALID,
    output reg         RREADY
);

    // FSM States
    parameter IDLE            = 3'b000;
    parameter WRITE_ADDR_DATA = 3'b001;
    parameter WRITE_RESP      = 3'b010;
    parameter READ_ADDR       = 3'b011;
    parameter READ_DATA       = 3'b100;
   

    reg [2:0] state;

    always @(posedge ACLK) begin
        if (ARESETn == 0) begin
            // Mandatory AXI reset rule: VALID signals must be driven LOW
            AWVALID <= 0;
            WVALID  <= 0;
            ARVALID <= 0;
            
            // Clear internal state
            state <= IDLE;
            BREADY <= 0;
				RREADY<=0;
				cpu_read_done<=0;
            cpu_read_error <= 0;
            cpu_write_done <= 0;
            cpu_write_error <= 0;
            cpu_read_data <= 0;
            
        end else begin
            case (state)
                
                IDLE: begin
                    // Ensure done flag is only high for one cycle
                    cpu_write_done <= 0;
                    cpu_read_done <= 0;
                    cpu_write_error <= 0;
                    cpu_read_error <= 0;
                    
                    if (cpu_write_req == 1) begin
                        // Latch CPU inputs onto AXI buses
                        AWADDR <= cpu_address;
                        WDATA  <= cpu_data;
                        WSTRB  <= 4'b1111; // Enable all 4 bytes
                        
                        // Assert VALID signals to initiate handshake
                        AWVALID <= 1;
                        WVALID  <= 1;
                        
                        state <= WRITE_ADDR_DATA;
                    end
						  else if(cpu_read_req==1)begin
						  //initiate read transaction
						  ARADDR<=cpu_address;
						  ARVALID<=1;
						  state<=READ_ADDR;
						  end
                end

                WRITE_ADDR_DATA: begin
                   //adress handshake
						 //if the slave input awready is 1,it has captures the adress
						 //and then we drop awvald output to 0 so we dont accidentaly send the adress twice
						 if(AWREADY ==1 && AWVALID==1)begin
						 AWVALID<=0;
						 end
						 
						 //data handshake 
						 //if slave asserts WREADY drop WVALID on ththe clock edge
						 if(WREADY==1 && WVALID==1)begin
						 WVALID<=0;
                end
					 
					 //check if the entire state is finished ,adress and data have been succesfullreceived by the slave or not
					 if((AWREADY==1 || AWVALID == 0) && (WREADY==1 || WVALID ==0))begin
					 //then we are redy to receive the success receipt
					 BREADY<=1;
					 state<=WRITE_RESP;
					 end
					 end

                WRITE_RESP: begin
                    // Assert BREADY to tell slave we are ready for the response
                    BREADY <= 1;
                    if( BVALID==1 && BREADY==1)begin
						  BREADY<=0;
						  cpu_write_done<=1;
						  cpu_write_error <= (BRESP != 2'b00);
						  state<=IDLE;
						  end
                  
                end
					 //READ TRANSACTION LOGIC
					 
					 READ_ADDR:begin
					 //read adress handshake
					 if(ARREADY==1 && ARVALID==1)begin
					 ARVALID<=0;
					 RREADY<=1;//READINESS OF TE SIGNAL TO ACCEPT INCOMING DATA
					 state<=READ_DATA;
					 end
					 end
					 READ_DATA:begin
					 //read data handshake
					 if(RVALID==1 && RREADY==1)begin
					 cpu_read_data<=RDATA;
						  cpu_read_error <= (RRESP != 2'b00);
					 RREADY<=0;
					 cpu_read_done<=1;
					 state<=IDLE;
					 end
					 end
					 
            endcase
        end
    end

endmodule
