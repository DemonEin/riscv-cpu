localparam PACKET_STATE_POWERED = 0;
localparam PACKET_STATE_IDLE = 1;
localparam PACKET_STATE_READING = 2;
localparam PACKET_STATE_READ_COMPLETE = 3;
localparam PACKET_STATE_DONE = 4;
localparam PACKET_STATE_AWAIT_END_OF_PACKET = 5;
localparam PACKET_STATE_SYNCING = 6;

localparam TRANSACTION_NONE = 0;
localparam TRANSACTION_SETUP = 1;
localparam TRANSACTION_IN = 2;
localparam TRANSACTION_OUT = 3;

localparam PENDING_SEND_NONE = 0;
localparam PENDING_SEND_ACK = 1;
localparam PENDING_SEND_NAK = 2;

localparam SEND_SYNC = 8'b00101010;

localparam EOP_NEED_SE0_0 = 0;
localparam EOP_NEED_SE0_1 = 1;
localparam EOP_NEED_J = 2;

module usb(clock48, usb_d_p, usb_d_n, usb_pullup, got_usb_packet, packet_buffer_address, packet_buffer_read_value, packet_buffer_write_value, write_to_packet_buffer, usb_packet_ready);
    input clock48;
    input [31:0] packet_buffer_read_value;
    input usb_packet_ready;

    inout usb_d_p, usb_d_n;

    output usb_pullup;
    assign usb_pullup = 1;
    output reg [$clog2(USB_PACKET_BUFFER_SIZE / 4) - 1:0] packet_buffer_address = 0;
    output reg write_to_packet_buffer;
    output reg [31:0] packet_buffer_write_value;
    output reg got_usb_packet;

    reg [$clog2(32):0] bits_to_read, next_bits_to_read;
    reg [$clog2(USB_PACKET_BUFFER_SIZE / 4) - 1:0] next_packet_buffer_address;

    reg [3:0] packet_state = PACKET_STATE_POWERED, next_packet_state;
    reg [3:0] transaction_state = TRANSACTION_STATE_IDLE, next_transaction_state;
    reg [2:0] eop_state;

    reg [3:0] pending_send;

    reg [6:0] device_address = 0;

    wire data_ready = data_ready_counter == 3;
    reg previous_data, next_previous_data;

    reg [2:0] send_consecutive_data_ones;
    reg [3:0] send_sync_index;
    wire read_complete = bits_to_read == 0;
    // bits are sent least-significant bit first

    // needs to hold one reset time, TODO could be smaller
    reg [31:0] reset_counter = 0;

    always @* begin
        next_packet_state = packet_state;
        write_to_packet_buffer = 0;
        next_packet_buffer_address = packet_buffer_address;
        packet_buffer_write_value = read_bits[63:32];
        got_usb_packet = 0;
        next_data_ready_counter = data_ready_counter;

        if (data_ready) begin
            next_previous_data = data;
        end else begin
            next_previous_data = previous_data;
        end

        if (data_ready && !skip_bit) begin
            next_bits_to_read = bits_to_read - 1;
        end else begin
            next_bits_to_read = bits_to_read;
        end

        case (packet_state)
            PACKET_STATE_POWERED: begin
                // TODO actually only needs to be 2.5 microseconds
                if (reset_counter > 48000 * 9) begin
                    next_packet_state = STATE_IDLE;
                end
            end
            PACKET_STATE_IDLE: begin
                if (data_k) begin
                    next_packet_state = STATE_SYNCING;
                    next_previous_data = 1;
                    next_bits_to_read = 8;
                    next_data_ready_counter = 2;
                end
            end
            PACKET_STATE_SYNCING: begin
                next_data_ready_counter = data_ready_counter + 1;
                if (read_complete) begin
                    if (read_bits[63:56] == 8'b10000000) begin
                        next_packet_state = PACKET_STATE_READING_PID;
                            next_bits_to_read = 32;
                            next_packet_buffer_address = 0;
                        end else begin
                            next_packet_state = STATE_IGNORE_PACKET;
                        end
                    end else begin
                        `ifdef simulation
                            $stop;
                        `endif
                    end
                end
            end
            PACKET_STATE_READING_PID: begin
                next_data_ready_counter = data_ready_counter + 1;
                if (read_complete) begin
                    if (read_bits[59:56] == ~read_bits[63:60) begin // check PID check
                        case (transaction_state)
                            TRANSACTION_STATE_AWAIT_DATA: begin
                                if (read_bits[59:56] == PID_DATA) begin
                                    next_packet_state = PACKET_STATE_READING_DATA;
                                    next_bits_to_read = 64;
                                end else begin
                                    next_packet_state = STATE_IGNORE_PACKET;
                                end
                            end
                            TRANSACTION_STATE_IDLE:
                                case (read_bits[59:56])
                                    PID_SETUP: begin
                                        next_bits_to_read = 16;
                                        next_current_transaction = TRANSACTION_SETUP;
                                        next_packet_state = STATE_READING_TOKEN;
                                        next_transaction_state = TRANSACTION_STATE_AWAIT_DATA;
                                    end
                                    default: begin
                                        next_packet_state = PACKET_STATE_IGNORE_PACKET;
                                    end
                                endcase
                        endcase
                    end else
                        next_packet_state = PACKET_STATE_AWAIT_END_OF_PACKET;
                end
            end
            PACKET_STATE_READING_TOKEN: begin
                next_data_ready_counter = data_ready_counter + 1;
                if (read_complete) begin
                    if (read_bits[54:48] == device_address && read_bits[58:55] == 0) begin
                        next_transaction_state = TRANSACTION_STATE_AWAIT_DATA;
                        next_packet_state = PACKET_STATE_AWAIT_END_OF_PACKET; // TODO ignore if not receiving EOP immediately?
                    end else
                        next_current_transaction = TRANSACTION_NONE;
                        next_packet_state = STATE_IGNORE_PACKET;
                    end
                end
            PACKET_STATE_READING_DATA: begin
                next_data_ready_counter = data_ready_counter + 1;
                if (read_complete) begin
                    if (current_transaction = TRANSACTION_SETUP) begin
                        case (read_bits[15:8]) // bRequest value
                            BREQUEST_CLEAR_FEATURE: begin
                            end
                            BREQUEST_GET_CONFIGURATION: begin
                            end
                            BREQUEST_GET_DESCRIPTOR: begin
                            end
                            BREQUEST_GET_INTERFACE: begin
                            end
                            BREQUEST_GET_STATUS: begin
                            end
                            BREQUEST_SET_ADDRESS: begin
                                next_device_address = read_bits[22:16];
                            end
                            BREQUEST_SET_CONFIGURATION: begin
                            end
                            BREQUEST_SET_DESCRIPTOR: begin
                            end
                            BREQUEST_SET_FEATURE: begin
                            end
                            BREQUEST_SET_INTERFACE: begin
                            end
                            BREQUEST_SYNCH_FRAME: begin
                            end
                        endcase
                    end

                    next_packet_state = PACKET_STATE_WAIT_FOR_END_OF_PACKET;
                end
            /*
            STATE_READING: begin
                next_data_ready_counter = data_ready_counter + 1;
                if (data_ready && se0) begin
                    // end of packet
                    got_usb_packet = 1;
                    next_packet_state = STATE_READ_COMPLETE;
                    write_to_packet_buffer = 1;
                    packet_buffer_write_value = read_bits >> bits_to_read;
                end else if (read_complete) begin
                    write_to_packet_buffer = 1;

                    if (packet_buffer_address == 8'hFF) begin
                        got_usb_packet = 1;
                        next_packet_state = STATE_READ_COMPLETE;
                    end
                    next_packet_buffer_address = packet_buffer_address + 1;
                    next_bits_to_read = 32;
                end
            end
            */
            PACKET_STATE_AWAIT_END_OF_PACKET: begin
                // TODO implement timeout
                next_data_ready_counter = data_ready_counter + 1;
                if (data_ready && se0) begin
                    // end of packet
                    case (pending_send)
                        PENDING_SEND_ACK: begin
                            next_packet_state = PACKET_STATE_SEND_SYNC;
                            send_bits = PID_ACK;
                            send_bits_length = 8;
                        end
                        default:
                            next_packet_state = PACKET_STATE_IDLE;
                    endcase
                end
            end
            PACKET_STATE_SEND_SYNC: begin
                next_data_ready_counter = data_ready_counter + 1;
                if (data_ready) begin

                    usb_d_p = SEND_SYNC[send_sync_index];
                    usb_d_n = ~SEND_SYNC[send_sync_index];

                    if (send_sync_index == 7) begin
                        next_packet_state <= PACKET_STATE_SEND;
                        next_send_previous_output = 0;
                        next_send_sync_index = 0;
                    end else begin
                        next_send_sync_index = send_sync_index + 1;
                    end
                end
            end
            PACKET_STATE_SEND: begin
                next_data_ready_counter = data_ready_counter + 1;
                if (data_ready)
                    // send a bits
                    if (!send_skip_bit)
                    usb_d_p = data;
                    usb_d_p = ~data;
                //
                end 
            end
        endcase
    end


    always @(posedge clock48) begin
        if (se0) begin
            reset_counter <= reset_counter + 1;
        end else begin
            reset_counter <= 0;
        end

        packet_state <= next_packet_state;
        data_ready_counter <= next_data_ready_counter;
        packet_buffer_address <= next_packet_buffer_address;
        bits_to_read <= next_bits_to_read;
        previous_data <= next_previous_data;
        device_address <= next_device_address;
    end
endmodule

    // decoding and sending
    // interface
    reg [63:0] read_write_buffer; // needs to be 64 bits to fit all data from a setup 
                                  // transaction
    reg [5:0] read_bits_count;
    reg [5:0] write_bits_count;

    wire differential_1 = usb_d_p && !usb_d_n;
    wire differential_0 = !usb_d_p && usb_d_n;
    wire se0 = !usb_d_p && !usb_d_n;
    wire data_j = differential_1;
    wire data_k = differential_0;
    wire idle = usb_d_p && !usb_d_n; // equivalent to differential_1 and data_j
    // this is the undecoded bit sent over the wire
    wire data = data_j;

    wire nzri_decoded_data = !(data ^ previous_data); // nzri decoded, but not bit-stuffing decoded

    task start_read_write()
                
    end task

    reg read_write_clock; // 12 mhz but reset sometimes



    // something like "at the posedge of read_write_enable, reset the
    // encode/decode state"
    // could also do that reset when setting read_write_enable to false
    //
    //


    reg write_enable;
    wire read_write_enable = read_enable | write_enable;

    always @(posedge read_write_enable) begin
        previous_data <= 1; // TODO check this value
        consecutive_nzri_data_ones <= 0;
        read_write_clock_counter <= 2; // warning, I don't think this can be 3
    end

    always @(posedge clock48) begin
        if (read_write_enable) begin
            read_write_clock_counter <= read_write_clock_counter + 1;
        end
    end

    wire read_write_clock = read_write_clock_counter[1] == 3;

    reg [2:0] consecutive_nzri_data_ones = 0;
    wire skip_bit = consecutive_nzri_data_ones >= 6;

    always @(posedge read_write_clock) begin
        if (read_write_bits_count > 0) begin
            if (!skip_bit) begin
                read_write_buffer <= { nzri_decoded_data, read_write_buffer[62:1] };
                read_write_bits_count <= read_bits_count - 1;

                if (read_bits_count == 1) begin
                    write_enable <= 1;
                end
            end if

            if (nzri_decoded_data == 1) begin
                consecutive_nzri_data_ones <= consecutive_nzri_data_ones + 1;
            end else begin
                consecutive_nzri_data_ones <= 0;
            end
        end

        previous_data <= data;
    end

    always @* begin
        if (read_write_bits_count > 0 && write_enable && !skip_bit) begin
            usb_d_p = !(read_write_buffer[0] ^ previous_data);
            usb_d_n = !usb_d_p;
        end
    end
