localparam STATE_POWERED = 0;
localparam STATE_RESET = 1;
localparam STATE_READING = 2;
localparam STATE_READ_COMPLETE = 3;
localparam STATE_DONE = 4;
localparam STATE_IGNORE_PACKET = 5;
localparam STATE_SYNCING = 6;

localparam EOP_NEED_SE0_0 = 0;
localparam EOP_NEED_SE0_1 = 1;
localparam EOP_NEED_J = 2;

module usb(clock48, usb_d_p, usb_d_n, usb_pullup, packet_ready);
    input clock48;

    inout usb_d_p, usb_d_n;

    output usb_pullup;
    assign usb_pullup = 1;

    output reg packet_ready = 0;

    reg [31:0] packet_buffer[1024/4];
    reg [$clog2(32):0] bits_to_read;
    reg [31:0] read_bits;
    reg [$clog2(1024/4) - 1:0] buffer_write_index = 0;

    reg [3:0] state = STATE_POWERED;
    reg [2:0] eop_state;

    wire differential_1 = usb_d_p && !usb_d_n;
    wire differential_0 = !usb_d_p && usb_d_n;
    wire se0 = !usb_d_p && !usb_d_n;
    wire data_j = differential_1;
    wire data_k = differential_0;
    wire idle = usb_d_p && !usb_d_n; // equivalent to differential_1 and data_j
    wire data = data_j;

    reg [1:0] data_ready_counter = 0;
    wire data_ready = data_ready_counter == 3;
    reg previous_data;

    // needs to hold one reset time, TODO could be smaller
    reg [31:0] reset_counter = 0;

    always @(posedge clock48) begin
        if (se0) begin
            reset_counter <= reset_counter + 1;
        end else begin
            reset_counter <= 0;
        end

        case (state)
            STATE_POWERED: begin
                // TODO actually only needs to be 2.5 microseconds
                if (reset_counter > 48000 * 9) begin
                    state <= STATE_RESET;
                end
            end

            STATE_RESET: begin
                if (data_k) begin
                    state <= STATE_SYNCING;
                    previous_data = 1;
                    
                    bits_to_read = 8;
                    data_ready_counter <= 2;
                end
            end
            STATE_SYNCING: begin
                data_ready_counter <= data_ready_counter + 1;
                if (data_ready) begin
                    read_bits = read_bits << 1;
                    read_bits[0] = !(data ^ previous_data);
                    previous_data = data;
                    bits_to_read = bits_to_read - 1;
                end
                if (bits_to_read == 0) begin
                    if (read_bits[7:0] == 8'b1) begin
                        state <= STATE_READING;
                        bits_to_read = 32;
                    end else begin
                        $display("got invalid sync");
                        $stop;
                    end
                end
            end
            STATE_READING: begin
                data_ready_counter <= data_ready_counter + 1;
                if (data_ready) begin
                    read_bits = read_bits << 1;
                    read_bits[0] = !(data ^ previous_data);
                    previous_data = data;
                    bits_to_read = bits_to_read - 1;
                end
                if (bits_to_read == 0) begin
                    packet_buffer[buffer_write_index] = read_bits;

                    bits_to_read = 32;
                    if (buffer_write_index == 8'hFF) begin
                        packet_ready <= 1;
                        state <= STATE_READ_COMPLETE;
                    end
                    buffer_write_index <= buffer_write_index + 1;
                end
            end
            STATE_READ_COMPLETE: begin
            end
            STATE_IGNORE_PACKET: begin
                case (eop_state)
                    EOP_NEED_SE0_0: begin
                        if (se0) begin
                            eop_state <= EOP_NEED_SE0_1;
                        end
                    end
                    EOP_NEED_SE0_1: begin
                        if (se0) begin
                            eop_state <= EOP_NEED_J;
                        end else begin
                            eop_state <= EOP_NEED_SE0_0;
                        end
                    end
                    EOP_NEED_J: begin
                        if (data_j) begin
                            state <= STATE_DONE;
                        end else begin
                            eop_state <= EOP_NEED_SE0_0;
                        end
                    end
                endcase
            end
        endcase
    end
    
endmodule
