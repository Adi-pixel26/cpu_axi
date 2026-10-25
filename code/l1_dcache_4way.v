module l1_dcache_4way (
    input  wire        clk,
    input  wire        reset,

    /*
     * CPU request interface.
     *
     * cpu_req_wdata and cpu_req_wstrb must already be aligned
     * to the addressed 32-bit word.
     */
    input  wire        cpu_req_valid,
    output wire        cpu_req_ready,
    input  wire [31:0] cpu_req_addr,
    input  wire        cpu_req_write,
    input  wire [31:0] cpu_req_wdata,
    input  wire [3:0]  cpu_req_wstrb,

    /*
     * CPU response.
     * Loads return the raw aligned 32-bit word.
     * LB/LH/LBU/LHU formatting is performed later in the datapath.
     */
    output wire        cpu_rsp_valid,
    input  wire        cpu_rsp_ready,
    output wire [31:0] cpu_rsp_rdata,
    output wire        cpu_rsp_error,

    /*
     * Flush interface.
     *
     * Assert flush_req for one clock when flush_ready is high.
     * The cache writes dirty lines to memory and invalidates all
     * cache entries.
     */
    input  wire        flush_req,
    output wire        flush_ready,
    output wire        flush_busy,
    output reg         flush_done,
    output reg         flush_error,

    /*
     * Lower-memory interface.
     *
     * A cache-line transfer is performed as eight individual
     * 32-bit memory transactions.
     */
    output wire        mem_req_valid,
    input  wire        mem_req_ready,
    output wire        mem_req_write,
    output wire [31:0] mem_req_addr,
    output wire [31:0] mem_req_wdata,

    input  wire        mem_rsp_valid,
    input  wire [31:0] mem_rsp_rdata,
    input  wire        mem_rsp_error
);

    /*
     * Cache geometry:
     *
     * Capacity    = 16 KiB
     * Ways        = 4
     * Line size   = 32 bytes
     * Sets        = 128
     * Words/line  = 8
     *
     * Address:
     *   [31:12] tag
     *   [11:5]  set
     *   [4:2]   word
     *   [1:0]   byte
     */

    reg [19:0] tag_way0 [0:127];
    reg [19:0] tag_way1 [0:127];
    reg [19:0] tag_way2 [0:127];
    reg [19:0] tag_way3 [0:127];

    reg [255:0] data_way0 [0:127];
    reg [255:0] data_way1 [0:127];
    reg [255:0] data_way2 [0:127];
    reg [255:0] data_way3 [0:127];

    reg valid_way0 [0:127];
    reg valid_way1 [0:127];
    reg valid_way2 [0:127];
    reg valid_way3 [0:127];

    reg dirty_way0 [0:127];
    reg dirty_way1 [0:127];
    reg dirty_way2 [0:127];
    reg dirty_way3 [0:127];

    reg [2:0] plru_mem [0:127];

    /*
     * Registered cache-array outputs.
     */
    reg [19:0] tag_q0;
    reg [19:0] tag_q1;
    reg [19:0] tag_q2;
    reg [19:0] tag_q3;

    reg [255:0] data_q0;
    reg [255:0] data_q1;
    reg [255:0] data_q2;
    reg [255:0] data_q3;

    reg valid_q0;
    reg valid_q1;
    reg valid_q2;
    reg valid_q3;

    reg dirty_q0;
    reg dirty_q1;
    reg dirty_q2;
    reg dirty_q3;

    /*
     * Saved processor request.
     */
    reg [19:0] request_tag;
    reg [6:0]  request_set;
    reg [2:0]  request_word;
    reg        request_write;
    reg [31:0] request_wdata;
    reg [3:0]  request_wstrb;

    /*
     * Selected replacement line.
     */
    reg [1:0]   victim_way;
    reg [19:0]  victim_tag;
    reg [255:0] victim_line;

    /*
     * Cache-line transfer state.
     */
    reg [2:0]   transfer_beat;
    reg [255:0] refill_line;

    /*
     * CPU response registers.
     */
    reg [31:0] response_data;
    reg        response_error;

    /*
     * Flush state.
     */
    reg [6:0]   flush_set;
    reg [1:0]   flush_way;

    reg [19:0]  flush_tag_q;
    reg [255:0] flush_line_q;
    reg         flush_valid_q;
    reg         flush_dirty_q;

    /*
     * Main state machine.
     */
    reg [3:0] state;

    localparam STATE_IDLE          = 4'd0;
    localparam STATE_LOOKUP        = 4'd1;
    localparam STATE_WB_REQ        = 4'd2;
    localparam STATE_WB_WAIT       = 4'd3;
    localparam STATE_REFILL_REQ    = 4'd4;
    localparam STATE_REFILL_WAIT   = 4'd5;
    localparam STATE_RESPONSE      = 4'd6;

    localparam STATE_FLUSH_READ    = 4'd7;
    localparam STATE_FLUSH_CHECK   = 4'd8;
    localparam STATE_FLUSH_WB_REQ  = 4'd9;
    localparam STATE_FLUSH_WB_WAIT = 4'd10;
    localparam STATE_FLUSH_CAPTURE = 4'd11;

    integer i;

    /*
     * One synchronous read address is shared by the normal lookup and flush
     * paths.  Keeping every tag/data-array read in this single clocked block
     * lets Quartus infer FPGA block RAM instead of implementing the cache as
     * tens of thousands of flip-flops.
     */
    wire [6:0] array_read_set;

    assign array_read_set =
        state == STATE_FLUSH_READ ? flush_set : cpu_req_addr[11:5];

    always @(posedge clk) begin
        tag_q0  <= tag_way0[array_read_set];
        tag_q1  <= tag_way1[array_read_set];
        tag_q2  <= tag_way2[array_read_set];
        tag_q3  <= tag_way3[array_read_set];

        data_q0 <= data_way0[array_read_set];
        data_q1 <= data_way1[array_read_set];
        data_q2 <= data_way2[array_read_set];
        data_q3 <= data_way3[array_read_set];
    end

    /*
     * Tree pseudo-LRU replacement selection.
     */
    function [1:0] plru_get_victim;
        input [2:0] value;

        begin
            if (value[2] == 1'b0) begin
                if (value[1] == 1'b0)
                    plru_get_victim = 2'd0;
                else
                    plru_get_victim = 2'd1;
            end else begin
                if (value[0] == 1'b0)
                    plru_get_victim = 2'd2;
                else
                    plru_get_victim = 2'd3;
            end
        end
    endfunction

    /*
     * Mark one way as recently used.
     */
    function [2:0] plru_mark_used;
        input [2:0] value;
        input [1:0] used_way;

        reg [2:0] next_value;

        begin
            next_value = value;

            case (used_way)
                2'd0: begin
                    next_value[2] = 1'b1;
                    next_value[1] = 1'b1;
                end

                2'd1: begin
                    next_value[2] = 1'b1;
                    next_value[1] = 1'b0;
                end

                2'd2: begin
                    next_value[2] = 1'b0;
                    next_value[0] = 1'b1;
                end

                2'd3: begin
                    next_value[2] = 1'b0;
                    next_value[0] = 1'b0;
                end
            endcase

            plru_mark_used = next_value;
        end
    endfunction

    /*
     * Select a 32-bit word from a cache line.
     */
    function [31:0] select_word;
        input [255:0] cache_line;
        input [2:0]   word_number;

        begin
            select_word = cache_line[word_number * 32 +: 32];
        end
    endfunction

    /*
     * Insert one memory word into a cache line.
     */
    function [255:0] insert_word;
        input [255:0] cache_line;
        input [2:0]   word_number;
        input [31:0]  word_data;

        reg [255:0] result;

        begin
            result = cache_line;
            result[word_number * 32 +: 32] = word_data;
            insert_word = result;
        end
    endfunction

    /*
     * Apply processor byte enables to one word in a cache line.
     */
    function [255:0] merge_store;
        input [255:0] cache_line;
        input [2:0]   word_number;
        input [31:0]  store_data;
        input [3:0]   byte_enable;

        reg [255:0] result;
        integer base;

        begin
            result = cache_line;
            base = word_number * 32;

            if (byte_enable[0])
                result[base +: 8] =
                    store_data[7:0];

            if (byte_enable[1])
                result[base + 8 +: 8] =
                    store_data[15:8];

            if (byte_enable[2])
                result[base + 16 +: 8] =
                    store_data[23:16];

            if (byte_enable[3])
                result[base + 24 +: 8] =
                    store_data[31:24];

            merge_store = result;
        end
    endfunction

    /*
     * Cache hit checks.
     */
    wire hit_way0;
    wire hit_way1;
    wire hit_way2;
    wire hit_way3;
    wire cache_hit;

    assign hit_way0 =
        valid_q0 && tag_q0 == request_tag;

    assign hit_way1 =
        valid_q1 && tag_q1 == request_tag;

    assign hit_way2 =
        valid_q2 && tag_q2 == request_tag;

    assign hit_way3 =
        valid_q3 && tag_q3 == request_tag;

    assign cache_hit =
        hit_way0 ||
        hit_way1 ||
        hit_way2 ||
        hit_way3;

    wire [1:0] hit_way;

    assign hit_way =
        hit_way0 ? 2'd0 :
        hit_way1 ? 2'd1 :
        hit_way2 ? 2'd2 :
                   2'd3;

    wire [255:0] hit_line;

    assign hit_line =
        hit_way0 ? data_q0 :
        hit_way1 ? data_q1 :
        hit_way2 ? data_q2 :
                   data_q3;

    /*
     * Select an invalid way before using pseudo-LRU.
     */
    wire [1:0] replacement_way;

    assign replacement_way =
        !valid_q0 ? 2'd0 :
        !valid_q1 ? 2'd1 :
        !valid_q2 ? 2'd2 :
        !valid_q3 ? 2'd3 :
        plru_get_victim(plru_mem[request_set]);

    wire replacement_valid;
    wire replacement_dirty;
    wire [19:0] replacement_tag;
    wire [255:0] replacement_line;

    assign replacement_valid =
        replacement_way == 2'd0 ? valid_q0 :
        replacement_way == 2'd1 ? valid_q1 :
        replacement_way == 2'd2 ? valid_q2 :
                                  valid_q3;

    assign replacement_dirty =
        replacement_way == 2'd0 ? dirty_q0 :
        replacement_way == 2'd1 ? dirty_q1 :
        replacement_way == 2'd2 ? dirty_q2 :
                                  dirty_q3;

    assign replacement_tag =
        replacement_way == 2'd0 ? tag_q0 :
        replacement_way == 2'd1 ? tag_q1 :
        replacement_way == 2'd2 ? tag_q2 :
                                  tag_q3;

    assign replacement_line =
        replacement_way == 2'd0 ? data_q0 :
        replacement_way == 2'd1 ? data_q1 :
        replacement_way == 2'd2 ? data_q2 :
                                  data_q3;

    wire [255:0] store_hit_line;

    assign store_hit_line =
        merge_store(
            hit_line,
            request_word,
            request_wdata,
            request_wstrb
        );

    wire [255:0] refill_line_next;

    assign refill_line_next =
        insert_word(
            refill_line,
            transfer_beat,
            mem_rsp_rdata
        );

    wire [255:0] installed_line;

    assign installed_line =
        request_write ?
        merge_store(
            refill_line_next,
            request_word,
            request_wdata,
            request_wstrb
        ) :
        refill_line_next;

    /*
     * CPU interface outputs.
     */
    assign cpu_req_ready =
        state == STATE_IDLE && !flush_req;

    assign cpu_rsp_valid =
        state == STATE_RESPONSE;

    assign cpu_rsp_rdata =
        response_data;

    assign cpu_rsp_error =
        response_error;

    /*
     * Flush interface outputs.
     */
    assign flush_ready =
        state == STATE_IDLE;

    assign flush_busy =
        state == STATE_FLUSH_READ ||
        state == STATE_FLUSH_CAPTURE ||
        state == STATE_FLUSH_CHECK ||
        state == STATE_FLUSH_WB_REQ ||
        state == STATE_FLUSH_WB_WAIT;

    /*
     * Lower-memory request generation.
     */
    assign mem_req_valid =
        state == STATE_WB_REQ ||
        state == STATE_REFILL_REQ ||
        state == STATE_FLUSH_WB_REQ;

    assign mem_req_write =
        state == STATE_WB_REQ ||
        state == STATE_FLUSH_WB_REQ;

    assign mem_req_addr =
        state == STATE_WB_REQ ?
            ({victim_tag, request_set, 5'b00000}
             + {27'd0, transfer_beat, 2'b00}) :

        state == STATE_FLUSH_WB_REQ ?
            ({flush_tag_q, flush_set, 5'b00000}
             + {27'd0, transfer_beat, 2'b00}) :

            ({request_tag, request_set, 5'b00000}
             + {27'd0, transfer_beat, 2'b00});

    assign mem_req_wdata =
        state == STATE_FLUSH_WB_REQ ?
            select_word(flush_line_q, transfer_beat) :
            select_word(victim_line, transfer_beat);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state          <= STATE_IDLE;

            request_tag    <= 20'd0;
            request_set    <= 7'd0;
            request_word   <= 3'd0;
            request_write  <= 1'b0;
            request_wdata  <= 32'd0;
            request_wstrb  <= 4'd0;

            victim_way     <= 2'd0;
            victim_tag     <= 20'd0;
            victim_line    <= 256'd0;

            transfer_beat  <= 3'd0;
            refill_line    <= 256'd0;

            response_data  <= 32'd0;
            response_error <= 1'b0;

            flush_set      <= 7'd0;
            flush_way      <= 2'd0;
            flush_tag_q    <= 20'd0;
            flush_line_q   <= 256'd0;
            flush_valid_q  <= 1'b0;
            flush_dirty_q  <= 1'b0;
            flush_done     <= 1'b0;
            flush_error    <= 1'b0;

            valid_q0 <= 1'b0;
            valid_q1 <= 1'b0;
            valid_q2 <= 1'b0;
            valid_q3 <= 1'b0;

            dirty_q0 <= 1'b0;
            dirty_q1 <= 1'b0;
            dirty_q2 <= 1'b0;
            dirty_q3 <= 1'b0;

            /*
             * Do not reset tag or data arrays.
             * Valid bits prevent uninitialized data from being used.
             */
            for (i = 0; i < 128; i = i + 1) begin
                valid_way0[i] <= 1'b0;
                valid_way1[i] <= 1'b0;
                valid_way2[i] <= 1'b0;
                valid_way3[i] <= 1'b0;

                dirty_way0[i] <= 1'b0;
                dirty_way1[i] <= 1'b0;
                dirty_way2[i] <= 1'b0;
                dirty_way3[i] <= 1'b0;

                plru_mem[i] <= 3'b000;
            end
        end else begin
            case (state)
                /*
                 * =====================================================
                 * Normal CPU request path
                 * =====================================================
                 */
                STATE_IDLE: begin
                    response_error <= 1'b0;
                    flush_done     <= 1'b0;
                    flush_error    <= 1'b0;

                    if (flush_req) begin
                        flush_set     <= 7'd0;
                        flush_way     <= 2'd0;
                        transfer_beat <= 3'd0;
                        state         <= STATE_FLUSH_READ;

                    end else if (cpu_req_valid &&
                                 cpu_req_ready) begin
                        request_tag   <= cpu_req_addr[31:12];
                        request_set   <= cpu_req_addr[11:5];
                        request_word  <= cpu_req_addr[4:2];
                        request_write <= cpu_req_write;
                        request_wdata <= cpu_req_wdata;
                        request_wstrb <= cpu_req_wstrb;

                        valid_q0 <=
                            valid_way0[cpu_req_addr[11:5]];

                        valid_q1 <=
                            valid_way1[cpu_req_addr[11:5]];

                        valid_q2 <=
                            valid_way2[cpu_req_addr[11:5]];

                        valid_q3 <=
                            valid_way3[cpu_req_addr[11:5]];

                        dirty_q0 <=
                            dirty_way0[cpu_req_addr[11:5]];

                        dirty_q1 <=
                            dirty_way1[cpu_req_addr[11:5]];

                        dirty_q2 <=
                            dirty_way2[cpu_req_addr[11:5]];

                        dirty_q3 <=
                            dirty_way3[cpu_req_addr[11:5]];

                        state <= STATE_LOOKUP;
                    end
                end

                STATE_LOOKUP: begin
                    if (cache_hit) begin
                        plru_mem[request_set] <=
                            plru_mark_used(
                                plru_mem[request_set],
                                hit_way
                            );

                        if (request_write) begin
                            case (hit_way)
                                2'd0: begin
                                    data_way0[request_set]
                                        <= store_hit_line;

                                    dirty_way0[request_set]
                                        <= 1'b1;
                                end

                                2'd1: begin
                                    data_way1[request_set]
                                        <= store_hit_line;

                                    dirty_way1[request_set]
                                        <= 1'b1;
                                end

                                2'd2: begin
                                    data_way2[request_set]
                                        <= store_hit_line;

                                    dirty_way2[request_set]
                                        <= 1'b1;
                                end

                                2'd3: begin
                                    data_way3[request_set]
                                        <= store_hit_line;

                                    dirty_way3[request_set]
                                        <= 1'b1;
                                end
                            endcase

                            response_data <= 32'd0;
                        end else begin
                            response_data <=
                                select_word(
                                    hit_line,
                                    request_word
                                );
                        end

                        response_error <= 1'b0;
                        state <= STATE_RESPONSE;

                    end else begin
                        victim_way  <= replacement_way;
                        victim_tag  <= replacement_tag;
                        victim_line <= replacement_line;

                        transfer_beat <= 3'd0;
                        refill_line   <= 256'd0;

                        if (replacement_valid &&
                            replacement_dirty)
                            state <= STATE_WB_REQ;
                        else
                            state <= STATE_REFILL_REQ;
                    end
                end

                /*
                 * Write back a dirty victim line.
                 */
                STATE_WB_REQ: begin
                    if (mem_req_valid && mem_req_ready)
                        state <= STATE_WB_WAIT;
                end

                STATE_WB_WAIT: begin
                    if (mem_rsp_valid) begin
                        if (mem_rsp_error) begin
                            response_data  <= 32'd0;
                            response_error <= 1'b1;
                            state <= STATE_RESPONSE;

                        end else if (transfer_beat == 3'd7) begin
                            transfer_beat <= 3'd0;
                            state <= STATE_REFILL_REQ;

                        end else begin
                            transfer_beat <= transfer_beat + 1'b1;
                            state <= STATE_WB_REQ;
                        end
                    end
                end

                /*
                 * Read the requested line from lower memory.
                 */
                STATE_REFILL_REQ: begin
                    if (mem_req_valid && mem_req_ready)
                        state <= STATE_REFILL_WAIT;
                end

                STATE_REFILL_WAIT: begin
                    if (mem_rsp_valid) begin
                        if (mem_rsp_error) begin
                            response_data  <= 32'd0;
                            response_error <= 1'b1;
                            state <= STATE_RESPONSE;
                        end else begin
                            refill_line <= refill_line_next;

                            if (transfer_beat == 3'd7) begin
                                case (victim_way)
                                    2'd0: begin
                                        tag_way0[request_set]
                                            <= request_tag;

                                        data_way0[request_set]
                                            <= installed_line;

                                        valid_way0[request_set]
                                            <= 1'b1;

                                        dirty_way0[request_set]
                                            <= request_write;
                                    end

                                    2'd1: begin
                                        tag_way1[request_set]
                                            <= request_tag;

                                        data_way1[request_set]
                                            <= installed_line;

                                        valid_way1[request_set]
                                            <= 1'b1;

                                        dirty_way1[request_set]
                                            <= request_write;
                                    end

                                    2'd2: begin
                                        tag_way2[request_set]
                                            <= request_tag;

                                        data_way2[request_set]
                                            <= installed_line;

                                        valid_way2[request_set]
                                            <= 1'b1;

                                        dirty_way2[request_set]
                                            <= request_write;
                                    end

                                    2'd3: begin
                                        tag_way3[request_set]
                                            <= request_tag;

                                        data_way3[request_set]
                                            <= installed_line;

                                        valid_way3[request_set]
                                            <= 1'b1;

                                        dirty_way3[request_set]
                                            <= request_write;
                                    end
                                endcase

                                plru_mem[request_set] <=
                                    plru_mark_used(
                                        plru_mem[request_set],
                                        victim_way
                                    );

                                if (request_write)
                                    response_data <= 32'd0;
                                else
                                    response_data <=
                                        select_word(
                                            refill_line_next,
                                            request_word
                                        );

                                response_error <= 1'b0;
                                state <= STATE_RESPONSE;
                            end else begin
                                transfer_beat <= transfer_beat + 1'b1;
                                state <= STATE_REFILL_REQ;
                            end
                        end
                    end
                end

                STATE_RESPONSE: begin
                    if (cpu_rsp_valid && cpu_rsp_ready)
                        state <= STATE_IDLE;
                end

                /*
                 * =====================================================
                 * Complete D-cache flush
                 * =====================================================
                 */

                STATE_FLUSH_READ: begin
                    case (flush_way)
                        2'd0: begin
                            flush_valid_q <= valid_way0[flush_set];
                            flush_dirty_q <= dirty_way0[flush_set];
                        end

                        2'd1: begin
                            flush_valid_q <= valid_way1[flush_set];
                            flush_dirty_q <= dirty_way1[flush_set];
                        end

                        2'd2: begin
                            flush_valid_q <= valid_way2[flush_set];
                            flush_dirty_q <= dirty_way2[flush_set];
                        end

                        2'd3: begin
                            flush_valid_q <= valid_way3[flush_set];
                            flush_dirty_q <= dirty_way3[flush_set];
                        end
                    endcase

                    state <= STATE_FLUSH_CAPTURE;
                end

                /*
                 * The block-RAM data requested in STATE_FLUSH_READ is now
                 * present on the tag_q and data_q registers.  Capture the
                 * selected way before
                 * checking whether it requires a writeback.
                 */
                STATE_FLUSH_CAPTURE: begin
                    case (flush_way)
                        2'd0: begin
                            flush_tag_q  <= tag_q0;
                            flush_line_q <= data_q0;
                        end

                        2'd1: begin
                            flush_tag_q  <= tag_q1;
                            flush_line_q <= data_q1;
                        end

                        2'd2: begin
                            flush_tag_q  <= tag_q2;
                            flush_line_q <= data_q2;
                        end

                        default: begin
                            flush_tag_q  <= tag_q3;
                            flush_line_q <= data_q3;
                        end
                    endcase

                    state <= STATE_FLUSH_CHECK;
                end

                STATE_FLUSH_CHECK: begin
                    if (flush_valid_q && flush_dirty_q) begin
                        transfer_beat <= 3'd0;
                        state <= STATE_FLUSH_WB_REQ;
                    end else begin
                        case (flush_way)
                            2'd0: begin
                                valid_way0[flush_set] <= 1'b0;
                                dirty_way0[flush_set] <= 1'b0;
                            end

                            2'd1: begin
                                valid_way1[flush_set] <= 1'b0;
                                dirty_way1[flush_set] <= 1'b0;
                            end

                            2'd2: begin
                                valid_way2[flush_set] <= 1'b0;
                                dirty_way2[flush_set] <= 1'b0;
                            end

                            2'd3: begin
                                valid_way3[flush_set] <= 1'b0;
                                dirty_way3[flush_set] <= 1'b0;
                            end
                        endcase

                        if (flush_way == 2'd3) begin
                            plru_mem[flush_set] <= 3'b000;

                            if (flush_set == 7'd127) begin
                                flush_done <= 1'b1;
                                state <= STATE_IDLE;
                            end else begin
                                flush_set <= flush_set + 1'b1;
                                flush_way <= 2'd0;
                                state <= STATE_FLUSH_READ;
                            end
                        end else begin
                            flush_way <= flush_way + 1'b1;
                            state <= STATE_FLUSH_READ;
                        end
                    end
                end

                STATE_FLUSH_WB_REQ: begin
                    if (mem_req_valid && mem_req_ready)
                        state <= STATE_FLUSH_WB_WAIT;
                end

                STATE_FLUSH_WB_WAIT: begin
                    if (mem_rsp_valid) begin
                        if (mem_rsp_error) begin
                            flush_error <= 1'b1;
                            flush_done  <= 1'b1;
                            state <= STATE_IDLE;

                        end else if (transfer_beat == 3'd7) begin
                            case (flush_way)
                                2'd0: begin
                                    valid_way0[flush_set] <= 1'b0;
                                    dirty_way0[flush_set] <= 1'b0;
                                end

                                2'd1: begin
                                    valid_way1[flush_set] <= 1'b0;
                                    dirty_way1[flush_set] <= 1'b0;
                                end

                                2'd2: begin
                                    valid_way2[flush_set] <= 1'b0;
                                    dirty_way2[flush_set] <= 1'b0;
                                end

                                2'd3: begin
                                    valid_way3[flush_set] <= 1'b0;
                                    dirty_way3[flush_set] <= 1'b0;
                                end
                            endcase

                            transfer_beat <= 3'd0;

                            if (flush_way == 2'd3) begin
                                plru_mem[flush_set] <= 3'b000;

                                if (flush_set == 7'd127) begin
                                    flush_done <= 1'b1;
                                    state <= STATE_IDLE;
                                end else begin
                                    flush_set <= flush_set + 1'b1;
                                    flush_way <= 2'd0;
                                    state <= STATE_FLUSH_READ;
                                end
                            end else begin
                                flush_way <= flush_way + 1'b1;
                                state <= STATE_FLUSH_READ;
                            end
                        end else begin
                            transfer_beat <= transfer_beat + 1'b1;
                            state <= STATE_FLUSH_WB_REQ;
                        end
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
