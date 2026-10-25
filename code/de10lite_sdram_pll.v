// de10lite_sdram_pll.v
//
// 50-MHz MAX 10 PLL for the SDRAM subsystem.  system_clk is the clock used
// by the controller and AXI logic.  sdram_clk has the same frequency with a
// -3-ns phase shift for the clock sent to the external SDRAM device.

module de10lite_sdram_pll (
    input  wire inclk0,
    input  wire areset,
    output wire system_clk,
    output wire sdram_clk,
    output wire locked
);

    wire [1:0] inclk_bus;
    wire [4:0] clk_bus;

    assign inclk_bus = {1'b0, inclk0};
    assign system_clk = clk_bus[0];
    assign sdram_clk  = clk_bus[1];

    altpll #(
        .bandwidth_type         ("AUTO"),
        .clk0_divide_by         (1),
        .clk0_duty_cycle        (50),
        .clk0_multiply_by       (1),
        .clk0_phase_shift       ("0"),
        .clk1_divide_by         (1),
        .clk1_duty_cycle        (50),
        .clk1_multiply_by       (1),
        .clk1_phase_shift       ("-3000"),
        .compensate_clock       ("CLK0"),
        .inclk0_input_frequency (20000),
        .intended_device_family ("MAX 10"),
        .lpm_type               ("altpll"),
        .operation_mode         ("NORMAL"),
        .pll_type               ("AUTO"),
        .port_areset            ("PORT_USED"),
        .port_clk0              ("PORT_USED"),
        .port_clk1              ("PORT_USED"),
        .port_inclk0            ("PORT_USED"),
        .port_inclk1            ("PORT_UNUSED"),
        .port_locked            ("PORT_USED"),
        .width_clock            (5)
    ) pll_inst (
        .areset (areset),
        .inclk  (inclk_bus),
        .clk    (clk_bus),
        .locked (locked)
    );

endmodule
