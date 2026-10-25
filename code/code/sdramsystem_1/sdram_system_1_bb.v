
module sdram_system_1 (
	clk_clk,
	reset_reset_n,
	sdram_wire_addr,
	sdram_wire_ba,
	sdram_wire_cas_n,
	sdram_wire_cke,
	sdram_wire_cs_n,
	sdram_wire_dq,
	sdram_wire_dqm,
	sdram_wire_ras_n,
	sdram_wire_we_n,
	cpu_axi_awid,
	cpu_axi_awaddr,
	cpu_axi_awlen,
	cpu_axi_awsize,
	cpu_axi_awburst,
	cpu_axi_awlock,
	cpu_axi_awcache,
	cpu_axi_awprot,
	cpu_axi_awqos,
	cpu_axi_awregion,
	cpu_axi_awvalid,
	cpu_axi_awready,
	cpu_axi_wdata,
	cpu_axi_wstrb,
	cpu_axi_wlast,
	cpu_axi_wvalid,
	cpu_axi_wready,
	cpu_axi_bid,
	cpu_axi_bresp,
	cpu_axi_bvalid,
	cpu_axi_bready,
	cpu_axi_arid,
	cpu_axi_araddr,
	cpu_axi_arlen,
	cpu_axi_arsize,
	cpu_axi_arburst,
	cpu_axi_arlock,
	cpu_axi_arcache,
	cpu_axi_arprot,
	cpu_axi_arqos,
	cpu_axi_arregion,
	cpu_axi_arvalid,
	cpu_axi_arready,
	cpu_axi_rid,
	cpu_axi_rdata,
	cpu_axi_rresp,
	cpu_axi_rlast,
	cpu_axi_rvalid,
	cpu_axi_rready);	

	input		clk_clk;
	input		reset_reset_n;
	output	[12:0]	sdram_wire_addr;
	output	[1:0]	sdram_wire_ba;
	output		sdram_wire_cas_n;
	output		sdram_wire_cke;
	output		sdram_wire_cs_n;
	inout	[15:0]	sdram_wire_dq;
	output	[1:0]	sdram_wire_dqm;
	output		sdram_wire_ras_n;
	output		sdram_wire_we_n;
	input	[0:0]	cpu_axi_awid;
	input	[31:0]	cpu_axi_awaddr;
	input	[7:0]	cpu_axi_awlen;
	input	[2:0]	cpu_axi_awsize;
	input	[1:0]	cpu_axi_awburst;
	input	[0:0]	cpu_axi_awlock;
	input	[3:0]	cpu_axi_awcache;
	input	[2:0]	cpu_axi_awprot;
	input	[3:0]	cpu_axi_awqos;
	input	[3:0]	cpu_axi_awregion;
	input		cpu_axi_awvalid;
	output		cpu_axi_awready;
	input	[31:0]	cpu_axi_wdata;
	input	[3:0]	cpu_axi_wstrb;
	input		cpu_axi_wlast;
	input		cpu_axi_wvalid;
	output		cpu_axi_wready;
	output	[0:0]	cpu_axi_bid;
	output	[1:0]	cpu_axi_bresp;
	output		cpu_axi_bvalid;
	input		cpu_axi_bready;
	input	[0:0]	cpu_axi_arid;
	input	[31:0]	cpu_axi_araddr;
	input	[7:0]	cpu_axi_arlen;
	input	[2:0]	cpu_axi_arsize;
	input	[1:0]	cpu_axi_arburst;
	input	[0:0]	cpu_axi_arlock;
	input	[3:0]	cpu_axi_arcache;
	input	[2:0]	cpu_axi_arprot;
	input	[3:0]	cpu_axi_arqos;
	input	[3:0]	cpu_axi_arregion;
	input		cpu_axi_arvalid;
	output		cpu_axi_arready;
	output	[0:0]	cpu_axi_rid;
	output	[31:0]	cpu_axi_rdata;
	output	[1:0]	cpu_axi_rresp;
	output		cpu_axi_rlast;
	output		cpu_axi_rvalid;
	input		cpu_axi_rready;
endmodule
