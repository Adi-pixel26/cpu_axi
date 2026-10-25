	component sdram_system_1 is
		port (
			clk_clk          : in    std_logic                     := 'X';             -- clk
			reset_reset_n    : in    std_logic                     := 'X';             -- reset_n
			sdram_wire_addr  : out   std_logic_vector(12 downto 0);                    -- addr
			sdram_wire_ba    : out   std_logic_vector(1 downto 0);                     -- ba
			sdram_wire_cas_n : out   std_logic;                                        -- cas_n
			sdram_wire_cke   : out   std_logic;                                        -- cke
			sdram_wire_cs_n  : out   std_logic;                                        -- cs_n
			sdram_wire_dq    : inout std_logic_vector(15 downto 0) := (others => 'X'); -- dq
			sdram_wire_dqm   : out   std_logic_vector(1 downto 0);                     -- dqm
			sdram_wire_ras_n : out   std_logic;                                        -- ras_n
			sdram_wire_we_n  : out   std_logic;                                        -- we_n
			cpu_axi_awid     : in    std_logic_vector(0 downto 0)  := (others => 'X'); -- awid
			cpu_axi_awaddr   : in    std_logic_vector(31 downto 0) := (others => 'X'); -- awaddr
			cpu_axi_awlen    : in    std_logic_vector(7 downto 0)  := (others => 'X'); -- awlen
			cpu_axi_awsize   : in    std_logic_vector(2 downto 0)  := (others => 'X'); -- awsize
			cpu_axi_awburst  : in    std_logic_vector(1 downto 0)  := (others => 'X'); -- awburst
			cpu_axi_awlock   : in    std_logic_vector(0 downto 0)  := (others => 'X'); -- awlock
			cpu_axi_awcache  : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- awcache
			cpu_axi_awprot   : in    std_logic_vector(2 downto 0)  := (others => 'X'); -- awprot
			cpu_axi_awqos    : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- awqos
			cpu_axi_awregion : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- awregion
			cpu_axi_awvalid  : in    std_logic                     := 'X';             -- awvalid
			cpu_axi_awready  : out   std_logic;                                        -- awready
			cpu_axi_wdata    : in    std_logic_vector(31 downto 0) := (others => 'X'); -- wdata
			cpu_axi_wstrb    : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- wstrb
			cpu_axi_wlast    : in    std_logic                     := 'X';             -- wlast
			cpu_axi_wvalid   : in    std_logic                     := 'X';             -- wvalid
			cpu_axi_wready   : out   std_logic;                                        -- wready
			cpu_axi_bid      : out   std_logic_vector(0 downto 0);                     -- bid
			cpu_axi_bresp    : out   std_logic_vector(1 downto 0);                     -- bresp
			cpu_axi_bvalid   : out   std_logic;                                        -- bvalid
			cpu_axi_bready   : in    std_logic                     := 'X';             -- bready
			cpu_axi_arid     : in    std_logic_vector(0 downto 0)  := (others => 'X'); -- arid
			cpu_axi_araddr   : in    std_logic_vector(31 downto 0) := (others => 'X'); -- araddr
			cpu_axi_arlen    : in    std_logic_vector(7 downto 0)  := (others => 'X'); -- arlen
			cpu_axi_arsize   : in    std_logic_vector(2 downto 0)  := (others => 'X'); -- arsize
			cpu_axi_arburst  : in    std_logic_vector(1 downto 0)  := (others => 'X'); -- arburst
			cpu_axi_arlock   : in    std_logic_vector(0 downto 0)  := (others => 'X'); -- arlock
			cpu_axi_arcache  : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- arcache
			cpu_axi_arprot   : in    std_logic_vector(2 downto 0)  := (others => 'X'); -- arprot
			cpu_axi_arqos    : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- arqos
			cpu_axi_arregion : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- arregion
			cpu_axi_arvalid  : in    std_logic                     := 'X';             -- arvalid
			cpu_axi_arready  : out   std_logic;                                        -- arready
			cpu_axi_rid      : out   std_logic_vector(0 downto 0);                     -- rid
			cpu_axi_rdata    : out   std_logic_vector(31 downto 0);                    -- rdata
			cpu_axi_rresp    : out   std_logic_vector(1 downto 0);                     -- rresp
			cpu_axi_rlast    : out   std_logic;                                        -- rlast
			cpu_axi_rvalid   : out   std_logic;                                        -- rvalid
			cpu_axi_rready   : in    std_logic                     := 'X'              -- rready
		);
	end component sdram_system_1;

	u0 : component sdram_system_1
		port map (
			clk_clk          => CONNECTED_TO_clk_clk,          --        clk.clk
			reset_reset_n    => CONNECTED_TO_reset_reset_n,    --      reset.reset_n
			sdram_wire_addr  => CONNECTED_TO_sdram_wire_addr,  -- sdram_wire.addr
			sdram_wire_ba    => CONNECTED_TO_sdram_wire_ba,    --           .ba
			sdram_wire_cas_n => CONNECTED_TO_sdram_wire_cas_n, --           .cas_n
			sdram_wire_cke   => CONNECTED_TO_sdram_wire_cke,   --           .cke
			sdram_wire_cs_n  => CONNECTED_TO_sdram_wire_cs_n,  --           .cs_n
			sdram_wire_dq    => CONNECTED_TO_sdram_wire_dq,    --           .dq
			sdram_wire_dqm   => CONNECTED_TO_sdram_wire_dqm,   --           .dqm
			sdram_wire_ras_n => CONNECTED_TO_sdram_wire_ras_n, --           .ras_n
			sdram_wire_we_n  => CONNECTED_TO_sdram_wire_we_n,  --           .we_n
			cpu_axi_awid     => CONNECTED_TO_cpu_axi_awid,     --    cpu_axi.awid
			cpu_axi_awaddr   => CONNECTED_TO_cpu_axi_awaddr,   --           .awaddr
			cpu_axi_awlen    => CONNECTED_TO_cpu_axi_awlen,    --           .awlen
			cpu_axi_awsize   => CONNECTED_TO_cpu_axi_awsize,   --           .awsize
			cpu_axi_awburst  => CONNECTED_TO_cpu_axi_awburst,  --           .awburst
			cpu_axi_awlock   => CONNECTED_TO_cpu_axi_awlock,   --           .awlock
			cpu_axi_awcache  => CONNECTED_TO_cpu_axi_awcache,  --           .awcache
			cpu_axi_awprot   => CONNECTED_TO_cpu_axi_awprot,   --           .awprot
			cpu_axi_awqos    => CONNECTED_TO_cpu_axi_awqos,    --           .awqos
			cpu_axi_awregion => CONNECTED_TO_cpu_axi_awregion, --           .awregion
			cpu_axi_awvalid  => CONNECTED_TO_cpu_axi_awvalid,  --           .awvalid
			cpu_axi_awready  => CONNECTED_TO_cpu_axi_awready,  --           .awready
			cpu_axi_wdata    => CONNECTED_TO_cpu_axi_wdata,    --           .wdata
			cpu_axi_wstrb    => CONNECTED_TO_cpu_axi_wstrb,    --           .wstrb
			cpu_axi_wlast    => CONNECTED_TO_cpu_axi_wlast,    --           .wlast
			cpu_axi_wvalid   => CONNECTED_TO_cpu_axi_wvalid,   --           .wvalid
			cpu_axi_wready   => CONNECTED_TO_cpu_axi_wready,   --           .wready
			cpu_axi_bid      => CONNECTED_TO_cpu_axi_bid,      --           .bid
			cpu_axi_bresp    => CONNECTED_TO_cpu_axi_bresp,    --           .bresp
			cpu_axi_bvalid   => CONNECTED_TO_cpu_axi_bvalid,   --           .bvalid
			cpu_axi_bready   => CONNECTED_TO_cpu_axi_bready,   --           .bready
			cpu_axi_arid     => CONNECTED_TO_cpu_axi_arid,     --           .arid
			cpu_axi_araddr   => CONNECTED_TO_cpu_axi_araddr,   --           .araddr
			cpu_axi_arlen    => CONNECTED_TO_cpu_axi_arlen,    --           .arlen
			cpu_axi_arsize   => CONNECTED_TO_cpu_axi_arsize,   --           .arsize
			cpu_axi_arburst  => CONNECTED_TO_cpu_axi_arburst,  --           .arburst
			cpu_axi_arlock   => CONNECTED_TO_cpu_axi_arlock,   --           .arlock
			cpu_axi_arcache  => CONNECTED_TO_cpu_axi_arcache,  --           .arcache
			cpu_axi_arprot   => CONNECTED_TO_cpu_axi_arprot,   --           .arprot
			cpu_axi_arqos    => CONNECTED_TO_cpu_axi_arqos,    --           .arqos
			cpu_axi_arregion => CONNECTED_TO_cpu_axi_arregion, --           .arregion
			cpu_axi_arvalid  => CONNECTED_TO_cpu_axi_arvalid,  --           .arvalid
			cpu_axi_arready  => CONNECTED_TO_cpu_axi_arready,  --           .arready
			cpu_axi_rid      => CONNECTED_TO_cpu_axi_rid,      --           .rid
			cpu_axi_rdata    => CONNECTED_TO_cpu_axi_rdata,    --           .rdata
			cpu_axi_rresp    => CONNECTED_TO_cpu_axi_rresp,    --           .rresp
			cpu_axi_rlast    => CONNECTED_TO_cpu_axi_rlast,    --           .rlast
			cpu_axi_rvalid   => CONNECTED_TO_cpu_axi_rvalid,   --           .rvalid
			cpu_axi_rready   => CONNECTED_TO_cpu_axi_rready    --           .rready
		);

