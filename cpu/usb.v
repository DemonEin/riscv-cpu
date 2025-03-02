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
    reg next_packet_ready;

    reg [$clog2(32):0] bits_to_read, next_bits_to_read;
    reg [$clog2(1024/4) - 1:0] buffer_write_index = 0, next_buffer_write_index;

    reg [3:0] state = STATE_POWERED, next_state;
    reg [2:0] eop_state;

    wire differential_1 = usb_d_p && !usb_d_n;
    wire differential_0 = !usb_d_p && usb_d_n;
    wire se0 = !usb_d_p && !usb_d_n;
    wire data_j = differential_1;
    wire data_k = differential_0;
    wire idle = usb_d_p && !usb_d_n; // equivalent to differential_1 and data_j
    // this is the undecoded bit sent over the wire
    wire data = data_j;

    reg [1:0] data_ready_counter = 0, next_data_ready_counter;
    wire data_ready = data_ready_counter == 3;
    reg previous_data, next_previous_data;

    wire read_complete = bits_to_read == 0;
    reg [2:0] consecutive_nzri_data_ones = 0;
    wire skip_bit = consecutive_nzri_data_ones >= 6;
    wire nzri_decoded_data = !(data ^ previous_data); // nzri decoded, but not bit-stuffing decoded
    wire decoded_data = nzri_decoded_data; // only defined when !skip_bit
    // bits are sent least-significant bit first
    reg [31:0] read_bits; // these are the last 32 decoded bits
    reg [31:0] bits_to_write;

    reg write_to_packet_buffer;

    // needs to hold one reset time, TODO could be smaller
    reg [31:0] reset_counter = 0;

    always @* begin
        next_state = state;
        write_to_packet_buffer = 0;
        next_buffer_write_index = buffer_write_index;
        next_packet_ready = packet_ready;
        bits_to_write = read_bits;

        if (data_ready) begin
            next_previous_data = data;
        end else begin
            next_previous_data = previous_data;
        end

        if (data_ready && !skip_bit) begin
            next_previous_data = data;
            next_bits_to_read = bits_to_read - 1;
        end else begin
            next_bits_to_read = bits_to_read;
        end

        case (state)
            STATE_POWERED: begin
                // TODO actually only needs to be 2.5 microseconds
                if (reset_counter > 48000 * 9) begin
                    next_state = STATE_RESET;
                end
            end
            STATE_RESET: begin
                if (data_k) begin
                    next_state = STATE_SYNCING;
                    next_previous_data = 1;
                    next_bits_to_read = 8;
                    next_data_ready_counter = 2;
                end
            end
            STATE_SYNCING: begin
                next_data_ready_counter = data_ready_counter + 1;
                if (read_complete) begin
                    if (read_bits[31:24] == 8'b10000000) begin
                        if (!top.core.control_status_registers.mip_meip) begin
                            next_state = STATE_READING;
                            next_bits_to_read = 32;
                            next_buffer_write_index = 0;
                        end else begin
                            next_state = STATE_IGNORE_PACKET;
                        end
                    end else begin
                        `ifdef simulation
                            $stop;
                        `endif
                    end
                end
            end
            STATE_READING: begin
                next_data_ready_counter = data_ready_counter + 1;
                if (data_ready && se0) begin
                    // end of packet
                    next_state = STATE_READ_COMPLETE;
                    write_to_packet_buffer = 1;
                    bits_to_write = read_bits >> bits_to_read;
                end else if (read_complete) begin
                    write_to_packet_buffer = 1;

                    if (buffer_write_index == 8'hFF) begin
                        next_packet_ready = 1;
                        next_state = STATE_READ_COMPLETE;
                    end
                    next_buffer_write_index = buffer_write_index + 1;
                    next_bits_to_read = 32;
                end
            end
            STATE_READ_COMPLETE: begin
            end
            STATE_IGNORE_PACKET: begin
            end
        endcase
    end

    always @(posedge clock48) begin
        if (se0) begin
            reset_counter <= reset_counter + 1;
        end else begin
            reset_counter <= 0;
        end

        if (data_ready) begin
            if (!skip_bit) begin
                read_bits <= { decoded_data, read_bits[31: 1] };
            end

            if (nzri_decoded_data == 1) begin
                consecutive_nzri_data_ones <= consecutive_nzri_data_ones + 1;
            end else begin
                consecutive_nzri_data_ones <= 0;
            end
        end

        state <= next_state;
        data_ready_counter <= next_data_ready_counter;
        buffer_write_index <= next_buffer_write_index;
        packet_ready <= next_packet_ready;
        bits_to_read <= next_bits_to_read;
        buffer_write_index <= next_buffer_write_index;
        packet_ready <= next_packet_ready;
        previous_data <= next_previous_data;

        if (write_to_packet_buffer) begin
            top.usb_packet_buffer[buffer_write_index] <= bits_to_write;
        end
    end
endmodule
