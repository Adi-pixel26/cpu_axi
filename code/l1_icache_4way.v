//Capacity:      16 KiB
//Ways:          4
//Line size:     32 bytes
//Sets:          128
//Words/line:    8
//Replacement:   Tree pseudo-LRU
//Write policy:  Read-only
module l1_icache_4way(
    input wire clk,
    input wire reset,

    /*
     * Assert only when the CPU pipeline has been stopped.
     * Used later for FENCE.I.
     */
     input wire invalidate_all,
     /*
     * CPU instruction-fetch interface.
     */
     input wire cpu_req_valid,
     output wire cpu_req_ready,
     input wire [31:0] cpu_req_addr,

     output wire cpu_rsp_valid,
     input wire cpu_rsp_ready,
     output wire[31:0] cpu_rsp_instr,
     output wire cpu_rsp_error,

      /*
     * Lower-memory interface.
     *
     * This sends eight 32-bit read requests to fetch one
     * 32-byte cache line.
     */

     output wire mem_req_valid,
     input wire mem_req_ready,
     output wire [31:0] mem_req_addr,
     
     input wire mem_rsp_valid,
     input wire [31:0] mem_rsp_rdata,
     input wire mem_rsp_error
    
);
/*
     * Address division:
     *
     * [31:12] = tag
     * [11:5]  = set
     * [4:2]   = word in cache line
     * [1:0]   = byte offset
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

    reg [2:0] plru_mem [0:127];
    /*
     * Registered M10K/BRAM outputs.
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

     /*
     * Saved CPU request.
     */
    reg [19:0] request_tag;
    reg [6:0]  request_set;
    reg [2:0]  request_word;
    
    /*
     * Cache-line refill state.
     */
    reg [1:0]   refill_way;
    reg [2:0]   refill_beat;
    reg [255:0] refill_line;

    reg [31:0] response_instruction;
    reg        response_error;

    reg [2:0] state;

    localparam STATE_IDLE       = 3'd0;
    localparam STATE_LOOKUP     = 3'd1;
    localparam STATE_READ_REQ   = 3'd2;
    localparam STATE_READ_WAIT  = 3'd3;
    localparam STATE_RESPONSE   = 3'd4;

    integer i;
    /*
     * Return the pseudo-LRU replacement way.
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
     * Mark a cache way as recently used.
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
     * Select a 32-bit instruction from a 256-bit cache line.
     */
    function [31:0] select_word;
        input [255:0] cache_line;
        input [2:0]   word_number;

        begin
            select_word = cache_line >> (word_number * 32);
        end
    endfunction
/*
     * Insert a 32-bit SDRAM response into the refill line.
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


     wire hit_way0;
    wire hit_way1;
    wire hit_way2;
    wire hit_way3;
    wire cache_hit;

    assign hit_way0 = valid_q0 && tag_q0 == request_tag;

    assign hit_way1 = valid_q1 && tag_q1 == request_tag;

    assign hit_way2 = valid_q2 && tag_q2 == request_tag;

    assign hit_way3 = valid_q3 && tag_q3 == request_tag;

    assign cache_hit = hit_way0 || hit_way1 || hit_way2 || hit_way3;
    wire [1:0] hit_way;
    wire [255:0] hit_line;

    assign hit_way =
        hit_way0 ? 2'd0 :
        hit_way1 ? 2'd1 :
        hit_way2 ? 2'd2 :
                   2'd3;

    assign hit_line =
        hit_way0 ? data_q0 :
        hit_way1 ? data_q1 :
        hit_way2 ? data_q2 :
                   data_q3;
/*
     * Use an invalid way before replacing a valid way.
     */
    wire [1:0] selected_refill_way;

    assign selected_refill_way =
        !valid_q0 ? 2'd0 :
        !valid_q1 ? 2'd1 :
        !valid_q2 ? 2'd2 :
        !valid_q3 ? 2'd3 :
        plru_get_victim(plru_mem[request_set]);

    /*
     * The refill line including the currently arriving word.
     */
    wire [255:0] refill_line_next;

    assign refill_line_next =
        insert_word(
            refill_line,
            refill_beat,
            mem_rsp_rdata
        );

    assign cpu_req_ready =
        state == STATE_IDLE;

    assign cpu_rsp_valid =
        state == STATE_RESPONSE;

    assign cpu_rsp_instr =
        response_instruction;

    assign cpu_rsp_error =
        response_error;

    assign mem_req_valid =
        state == STATE_READ_REQ;

    /*
     * Start from the aligned 32-byte line address, then select
     * one of its eight 32-bit words.
     */
    assign mem_req_addr ={request_tag, request_set, 5'b00000} + {27'd0, refill_beat, 2'b00};

    always @(posedge clk or posedge reset)begin
        if(reset)begin
            state<=STATE_IDLE;
             request_tag          <= 20'd0;
            request_set          <= 7'd0;
            request_word         <= 3'd0;
            refill_way           <= 2'd0;
            refill_beat          <= 3'd0;
            refill_line          <= 256'd0;
            response_instruction <= 32'd0;
            response_error       <= 1'b0;

            valid_q0 <= 1'b0;
            valid_q1 <= 1'b0;
            valid_q2 <= 1'b0;
            valid_q3 <= 1'b0;
            /*
             * Do not reset data RAM or tag RAM.
             * Clearing valid bits is sufficient.
             */
            for (i = 0; i < 128; i = i + 1) begin
                valid_way0[i] <= 1'b0;
                valid_way1[i] <= 1'b0;
                valid_way2[i] <= 1'b0;
                valid_way3[i] <= 1'b0;

                plru_mem[i] <= 3'b000;
            end
        end
        else if(invalidate_all)begin
            /*
             * Stop the pipeline before asserting this input.
             */
            state <= STATE_IDLE;

            for (i = 0; i < 128; i = i + 1) begin
                valid_way0[i] <= 1'b0;
                valid_way1[i] <= 1'b0;
                valid_way2[i] <= 1'b0;
                valid_way3[i] <= 1'b0;

                plru_mem[i] <= 3'b000;
            end
        end
     
    else begin
        case (state)
        STATE_IDLE: begin
            response_error <=1'b0;

            if(cpu_req_valid && cpu_req_ready) begin
                request_tag  <= cpu_req_addr[31:12];
                request_set  <= cpu_req_addr[11:5];
                request_word <= cpu_req_addr[4:2];

                /*
                         * Synchronous read from all four ways.
                         */
                        tag_q0 <= tag_way0[cpu_req_addr[11:5]];

                        tag_q1 <=  tag_way1[cpu_req_addr[11:5]];

                        tag_q2 <= tag_way2[cpu_req_addr[11:5]];

                        tag_q3 <=  tag_way3[cpu_req_addr[11:5]];

                        data_q0 <=  data_way0[cpu_req_addr[11:5]];

                        data_q1 <= data_way1[cpu_req_addr[11:5]];

                        data_q2 <= data_way2[cpu_req_addr[11:5]];

                        data_q3 <= data_way3[cpu_req_addr[11:5]];

                        valid_q0 <= valid_way0[cpu_req_addr[11:5]];

                        valid_q1 <=  valid_way1[cpu_req_addr[11:5]];

                        valid_q2 <= valid_way2[cpu_req_addr[11:5]];

                        valid_q3 <= valid_way3[cpu_req_addr[11:5]];

                        state<=STATE_LOOKUP;
            end
        end
        STATE_LOOKUP: begin
            if(cache_hit) begin
                response_instruction<=select_word(hit_line, request_word);
                response_error<=1'b0;

                plru_mem[request_set]<=plru_mark_used(plru_mem[request_set],hit_way);

                state<=STATE_RESPONSE;
            end
            else begin
                refill_way<=selected_refill_way;
                refill_beat<=3'd0;
                refill_line<=256'd0;

                state<=STATE_READ_REQ;
            end
        end
       STATE_READ_REQ:begin
                    /*
                     * Hold mem_req_valid and address until the
                     * arbiter accepts the request.
                     */
                    if (mem_req_valid && mem_req_ready)
                        state <= STATE_READ_WAIT;
                end
        STATE_READ_WAIT:begin
             if (mem_rsp_valid) begin
                        if (mem_rsp_error) begin
                            response_instruction <= 32'd0;
                            response_error       <= 1'b1;
                            state <= STATE_RESPONSE;
                        end 
                        else begin
                            refill_line<=refill_line_next;

                            if(refill_beat == 3'd7) begin
                                case (refill_way)
                                    2'd0: begin
                                        tag_way0[request_set]
                                            <= request_tag;

                                        data_way0[request_set]
                                            <= refill_line_next;

                                        valid_way0[request_set]
                                            <= 1'b1;
                                    end

                                    2'd1: begin
                                        tag_way1[request_set]
                                            <= request_tag;

                                        data_way1[request_set]
                                            <= refill_line_next;

                                        valid_way1[request_set]
                                            <= 1'b1;
                                    end

                                    2'd2: begin
                                        tag_way2[request_set]
                                            <= request_tag;

                                        data_way2[request_set]
                                            <= refill_line_next;

                                        valid_way2[request_set]
                                            <= 1'b1;
                                    end

                                    2'd3: begin
                                        tag_way3[request_set]
                                            <= request_tag;

                                        data_way3[request_set]
                                            <= refill_line_next;

                                        valid_way3[request_set]
                                            <= 1'b1;
                                    end
                                endcase
                                plru_mem[request_set] <=
                                    plru_mark_used(
                                        plru_mem[request_set],
                                        refill_way
                                    );

                                response_instruction <=
                                    select_word(
                                        refill_line_next,
                                        request_word
                                    );
                                  response_error <= 1'b0;
                                state <= STATE_RESPONSE;
                            end else begin
                                refill_beat <= refill_beat + 1'b1;
                                state <= STATE_READ_REQ;
                            end
                        end
                    end
                end   
                 STATE_RESPONSE: begin
                    if (cpu_rsp_valid && cpu_rsp_ready)
                        state <= STATE_IDLE;
                end
                default: begin
                    state <= STATE_IDLE;
                end
        endcase
    end
    end
endmodule

                
