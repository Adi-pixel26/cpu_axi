	component sdram_system is
		port (
			reset_reset_n : in std_logic := 'X'  -- reset_n
		);
	end component sdram_system;

	u0 : component sdram_system
		port map (
			reset_reset_n => CONNECTED_TO_reset_reset_n  -- reset.reset_n
		);

