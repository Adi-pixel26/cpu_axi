module vga_controller( // FIXED: module spelling
    input wire clk_25mhz,
    input wire reset,
    input wire [11:0] pixel_data,

    output reg [3:0] vga_red, // FIXED: changed vfa_red to vga_red
    output reg [3:0] vga_green,
    output reg [3:0] vga_blue,

    output reg vga_hsync,
    output reg vga_vsync,
    output wire fifo_rd_en
);

    parameter H_SYNC_CYC = 96;
    parameter H_BACK_PORCH = 48;
    parameter H_ACTIVE_VIDEO = 640;
    parameter H_FRONT_PORCH = 16;
    parameter H_TOTAL = 800;

    parameter V_SYNC_CYC = 2;
    parameter V_BACK_PORCH = 33;
    parameter V_ACTIVE_VIDEO = 480; 
    parameter V_FRONT_PORCH = 10;
    parameter V_TOTAL = 525;

    reg [9:0] hcount;
    reg [9:0] vcount;

    always@(posedge clk_25mhz )begin
        if(reset)begin
            hcount <= 0;
        end
        else if(hcount == 799)begin
            hcount <= 0;
        end
        else begin
            hcount <= hcount + 1;
        end
    end

    always@(posedge clk_25mhz)begin
        if(reset)
            vcount <= 0;
        else if(hcount == 799)begin
            if(vcount == 524)
                vcount <= 0;
            else
                vcount <= vcount + 1;
        end
    end

    assign fifo_rd_en = (hcount < H_ACTIVE_VIDEO && vcount < V_ACTIVE_VIDEO) ? 1'b1 : 1'b0;
    
    wire hsync_raw = ~((hcount >= (H_ACTIVE_VIDEO + H_FRONT_PORCH)) && (hcount < (H_ACTIVE_VIDEO + H_FRONT_PORCH + H_SYNC_CYC)));
    wire vsync_raw = ~((vcount >= (V_ACTIVE_VIDEO + V_FRONT_PORCH)) && (vcount < (V_ACTIVE_VIDEO + V_FRONT_PORCH + V_SYNC_CYC)));

    reg active_delay;

    always@(posedge clk_25mhz)begin
        if(reset)begin
            active_delay <= 0;
            vga_hsync <= 1'b1;
            vga_vsync <= 1'b1;
        end
        else begin
            // FIXED: Added missing begin/end block and assigned the raw sync signals to the registers
            active_delay <= (hcount < H_ACTIVE_VIDEO && vcount < V_ACTIVE_VIDEO) ? 1'b1 : 1'b0;
            vga_hsync    <= hsync_raw;
            vga_vsync    <= vsync_raw;
        end
    end

    always@(posedge clk_25mhz)begin
        if(reset)begin
            vga_red   <= 0;
            vga_green <= 0;
            vga_blue  <= 0;
        end
        else if(active_delay)begin
            vga_red   <= pixel_data[11:8];
            vga_green <= pixel_data[7:4];
            vga_blue  <= pixel_data[3:0];
        end
        else begin
            vga_red   <= 0;
            vga_green <= 0;
            vga_blue  <= 0;
        end
    end

endmodule