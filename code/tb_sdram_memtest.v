`timescale 1ns/1ps

// This self-checking test verifies the tester's Avalon handshake/state
// machine.  The memory below is an Avalon behavioral slave; it is not an
// electrical SDRAM timing model.  Physical SDRAM verification must be run on
// the DE10-Lite or with the SDRAM vendor's simulation model.
module tb_sdram_memtest;

    localparam ADDR_WIDTH = 10;
    localparam TEST_WORDS = 256;

    reg clk;
    reg reset;
    reg start;

    wire [ADDR_WIDTH-1:0] address;
    wire [1:0]            byteenable_n;
    wire                  chipselect;
    wire [15:0]           writedata;
    wire                  read_n;
    wire                  write_n;
    reg  [15:0]           readdata;
    reg                   readdatavalid;
    wire                  waitrequest;

    wire                  busy;
    wire                  done;
    wire                  pass;
    wire                  fail;
    wire [2:0]            current_pattern;
    wire [ADDR_WIDTH-1:0] fail_address;
    wire [15:0]           fail_expected;
    wire [15:0]           fail_actual;

    reg [15:0] memory [0:TEST_WORDS-1];
    reg [ADDR_WIDTH-1:0] pending_read_address;
    reg [2:0] read_delay;
    reg read_pending;
    reg [7:0] cycle_count;

    integer i;

    // Insert regular wait states to prove that the master holds its command.
    assign waitrequest = chipselect &&
                         ((cycle_count[2:0] == 3'd2) ||
                          (cycle_count[2:0] == 3'd5));

    sdram_memtest_avalon16 #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .TEST_WORDS(TEST_WORDS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .avm_address(address),
        .avm_byteenable_n(byteenable_n),
        .avm_chipselect(chipselect),
        .avm_writedata(writedata),
        .avm_read_n(read_n),
        .avm_write_n(write_n),
        .avm_readdata(readdata),
        .avm_readdatavalid(readdatavalid),
        .avm_waitrequest(waitrequest),
        .busy(busy),
        .done(done),
        .pass(pass),
        .fail(fail),
        .current_pattern(current_pattern),
        .fail_address(fail_address),
        .fail_expected(fail_expected),
        .fail_actual(fail_actual)
    );

    always #10 clk = ~clk; // 50 MHz

    // Small Avalon memory model with a three-cycle read response.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            readdata            <= 16'd0;
            readdatavalid       <= 1'b0;
            pending_read_address <= {ADDR_WIDTH{1'b0}};
            read_delay          <= 3'd0;
            read_pending        <= 1'b0;
            cycle_count         <= 8'd0;
        end else begin
            cycle_count   <= cycle_count + 1'b1;
            readdatavalid <= 1'b0;

            if (chipselect && !write_n && !waitrequest) begin
                if (!byteenable_n[0])
                    memory[address][7:0] <= writedata[7:0];
                if (!byteenable_n[1])
                    memory[address][15:8] <= writedata[15:8];
            end

            if (chipselect && !read_n && !waitrequest) begin
                pending_read_address <= address;
                read_delay           <= 3'd3;
                read_pending         <= 1'b1;
            end

            if (read_pending) begin
                if (read_delay == 3'd1) begin
                    readdata      <= memory[pending_read_address];
                    readdatavalid <= 1'b1;
                    read_pending  <= 1'b0;
                    read_delay    <= 3'd0;
                end else begin
                    read_delay <= read_delay - 1'b1;
                end
            end
        end
    end

    initial begin
        clk   = 1'b0;
        reset = 1'b1;
        start = 1'b0;

        for (i = 0; i < TEST_WORDS; i = i + 1)
            memory[i] = 16'hxxxx;

        $dumpfile("tb_sdram_memtest.vcd");
        $dumpvars(0, tb_sdram_memtest);

        repeat (5) @(posedge clk);
        reset <= 1'b0;
        repeat (2) @(posedge clk);
        start <= 1'b1;

        wait (done);
        @(posedge clk);

        if (pass && !fail) begin
            $display("PASS: Avalon SDRAM memory tester completed all patterns");
        end else begin
            $display("FAIL: addr=%h expected=%h actual=%h",
                     fail_address, fail_expected, fail_actual);
            $stop;
        end

        start <= 1'b0;
        repeat (5) @(posedge clk);
        $finish;
    end

    initial begin
        #5000000;
        $display("FAIL: SDRAM tester simulation timed out");
        $stop;
    end

endmodule
