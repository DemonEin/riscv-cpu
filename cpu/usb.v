`include "usb_constants.v"

localparam DECODED_SYNC_PATTERN = 8'b10000000;

localparam TOP_STATE_POWERED = 0;
localparam TOP_STATE_IDLE = 1;
localparam TOP_STATE_ACTIVE = 2;

localparam EOP_NEED_SE0_0 = 0;
localparam EOP_NEED_SE0_1 = 1;
localparam EOP_NEED_J = 2;

module usb(
    input clock48,
    inout usb_d_p,
    inout usb_d_n,
    output usb_pullup = 1,
    output reg got_usb_packet, 
    output reg [7:0] data_buffer_address,
    input [31:0] data_buffer_read_value,
    output reg [31:0] data_buffer_write_value,
    output reg write_to_data_buffer,
    input usb_packet_ready,
    input [31:0] usb_control,
    output wire [31:0] set_usb_control = {
        9'bx, 
        set_usb_control_token,
        set_usb_control_endpoint,
        set_usb_control_address,
        set_usb_control_data_length
    }
);
    reg [1:0] top_state = TOP_STATE_POWERED;

    // decoding and sending interface
    reg write_enable = 0;
    wire [31:0] read_bits = { nzri_decoded_data, read_write_buffer[31:1] };
    reg [31:0] read_write_buffer;
    reg [5:0] read_write_bits_count;

    wire differential_1 = usb_d_p && !usb_d_n;
    wire differential_0 = !usb_d_p && usb_d_n;
    wire se0 = !usb_d_p && !usb_d_n;
    wire data_j = differential_1;
    wire data_k = differential_0;
    wire idle = usb_d_p && !usb_d_n; // equivalent to differential_1 and data_j
    wire data = data_j; // this is the undecoded bit sent over the wire
    wire nzri_decoded_data = !(data ^ previous_data); // nzri decoded, but not bit-stuffing decoded
    reg previous_data;

    reg [1:0] read_write_clock_counter;
    reg [2:0] consecutive_nzri_data_ones = 0;
    wire skip_bit = consecutive_nzri_data_ones >= 6;
    assign usb_d_p = write_enable ? output_data : 1'bz;
    assign usb_d_n = write_enable ? output_data_n : 1'bz;
    reg output_data, output_data_n;
    reg send_eop = 0;
    reg pending_load = 0;
    wire [3:0] current_data_pid = { data_sync_bit, PID_DATA0[2:0] };

    always @* begin
        if (send_eop) begin
            output_data = 0;
            output_data_n = 0;
        end else begin
            if (!skip_bit) begin
                output_data = !(read_write_buffer[0] ^ previous_data);
            end else begin
                // insert bit-stuffed transition
                output_data = !previous_data;
            end

            output_data_n = !output_data;
        end
    end

    reg [31:0] reset_counter = 0; // needs to hold one reset time, TODO could be smaller

    // wire-like regs set in the following combinational block
    reg [1:0] next_top_state;
    reg [3:0] next_packet_state;
    reg [1:0] next_read_write_clock_counter;
    reg [2:0] next_consecutive_nzri_data_ones;
    reg [5:0] next_read_write_bits_count;
    reg next_previous_data;
    reg [31:0] next_read_write_buffer;
    reg [3:0] next_stall_counter;
    reg next_pending_load;
    reg [8:0] next_words_read_written;
    reg [3:0] next_transaction_state;
    reg [3:0] next_current_transaction_pid;
    reg [3:0] next_pending_send;
    reg next_write_enable;
    reg next_send_eop;
    reg [6:0] next_current_transaction_address;
    reg [3:0] next_current_transaction_endpoint;
    reg [9:0] set_usb_control_data_length;
    reg [6:0] set_usb_control_address;
    reg [3:0] set_usb_control_endpoint;
    reg [1:0] set_usb_control_token;
    reg next_data_sync_bit;
    reg [4:0] next_token_crc;
    reg [15:0] next_data_crc;

    always @* begin
        next_top_state = top_state;
        next_packet_state = packet_state;
        next_read_write_clock_counter = read_write_clock_counter + 1;
        next_consecutive_nzri_data_ones = consecutive_nzri_data_ones;
        next_read_write_bits_count = read_write_bits_count;
        next_previous_data = previous_data;
        next_read_write_buffer = read_write_buffer;
        next_stall_counter = stall_counter;
        next_pending_load = 0;
        next_words_read_written = words_read_written;
        next_transaction_state = transaction_state;
        next_current_transaction_pid = current_transaction_pid;
        next_pending_send = pending_send;
        next_write_enable = write_enable;
        next_send_eop = send_eop;
        next_current_transaction_address = current_transaction_address;
        next_current_transaction_endpoint = current_transaction_endpoint;
        next_data_sync_bit = data_sync_bit;
        next_token_crc = token_crc;
        next_data_crc = data_crc;

        got_usb_packet = 0;
        data_buffer_address = 8'bx;
        data_buffer_write_value = 32'bx;
        write_to_data_buffer = 0;
        set_usb_control_data_length = 10'bx;
        set_usb_control_address = 7'bx;
        set_usb_control_endpoint = 4'bx;
        set_usb_control_token = 2'bx;

        case (top_state)
            TOP_STATE_POWERED: begin
                // TODO actually only needs to be 2.5 microseconds
                if (reset_counter > 48000 * 9) begin
                    next_top_state = TOP_STATE_IDLE;
                end
            end
            TOP_STATE_IDLE: begin
                if (data_k) begin
                    next_top_state = TOP_STATE_ACTIVE;
                    next_packet_state = PACKET_STATE_SYNCING;
                    next_read_write_bits_count = 8;
                    next_previous_data = 1;
                    next_consecutive_nzri_data_ones = 0;
                    next_read_write_clock_counter = 3;
                end
            end
            TOP_STATE_ACTIVE: begin
                if (read_write_clock_counter == 3) begin
                    if (stall_counter > 0) begin
                        next_stall_counter = stall_counter - 1;
                    end

                    if (nzri_decoded_data == 1) begin
                        next_consecutive_nzri_data_ones = consecutive_nzri_data_ones + 1;
                    end else begin
                        next_consecutive_nzri_data_ones = 0;
                    end

                    next_previous_data = data;

                    if (!skip_bit) begin
                        next_read_write_buffer = read_bits;
                        next_data_crc = data_crc[15] ^ nzri_decoded_data
                                ? (data_crc << 1) ^ 16'b1000000000000101
                                : (data_crc << 1);
                        next_token_crc = token_crc[4] ^ nzri_decoded_data
                                ? (token_crc << 1) ^ 5'b00101
                                : (token_crc << 1);
                        // run got_bit after everything else to allow it
                        // to override other values
                        got_bit();
                    end
                end

                if (pending_load) begin
                    next_read_write_buffer = data_buffer_read_value;
                end
            end
        endcase

    end

    localparam PACKET_STATE_WRITE_DATA = 0;
    localparam PACKET_STATE_READING = 2;
    localparam PACKET_STATE_WRITE_DATA_CRC = 3;
    localparam PACKET_STATE_WRITE_DATA_PID = 4;
    localparam PACKET_STATE_AWAIT_END_OF_PACKET = 5;
    localparam PACKET_STATE_SYNCING = 6;
    localparam PACKET_STATE_WRITE_HANDSHAKE = 7;
    localparam PACKET_STATE_READING_PID = 8;
    localparam PACKET_STATE_READING_TOKEN = 9;
    localparam PACKET_STATE_READING_DATA = 10;
    localparam PACKET_STATE_FINISH = 11;
    localparam PACKET_STATE_WRITE_PAUSE = 12;
    localparam PACKET_STATE_WRITE_SYNC = 13;
    localparam PACKET_STATE_SEND_EOP = 14;
    localparam PACKET_STATE_WRITE_FINISH = 15;

    localparam PENDING_SEND_NONE = 0;
    localparam PENDING_SEND_HANDSHAKE = 1;
    localparam PENDING_SEND_DATA = 2;

    localparam TRANSACTION_STATE_IDLE = 0;
    localparam TRANSACTION_STATE_AWAIT_DATA = 1;
    localparam TRANSACTION_STATE_AWAIT_HANDSHAKE = 2;

    localparam BREQUEST_GET_STATUS = 0;
    localparam BREQUEST_CLEAR_FEATURE = 1;
    localparam BREQUEST_SET_FEATURE = 3;
    localparam BREQUEST_SET_ADDRESS = 5;
    localparam BREQUEST_GET_DESCRIPTOR = 6;
    localparam BREQUEST_SET_DESCRIPTOR = 7;
    localparam BREQUEST_GET_CONFIGURATION = 8;
    localparam BREQUEST_SET_CONFIGURATION = 9;
    localparam BREQUEST_GET_INTERFACE = 10;
    localparam BREQUEST_SET_INTERFACE = 11;
    localparam BREQUEST_SYNCH_FRAME = 12;

    localparam PID_OUT = 4'b0001;
    localparam PID_IN = 4'b1001;
    localparam PID_SETUP = 4'b1101;
    localparam PID_DATA0 = 4'b0011;
    localparam PID_DATA1 = 4'b1011;
    localparam PID_ACK = 4'b0010;
    localparam PID_NAK = 4'b1010;
    localparam PID_STALL = 4'b1110;
    localparam PID_NYET = 4'b0110;

    reg [3:0] current_transaction_pid = 0;
    reg [6:0] current_transaction_address;
    reg [3:0] current_transaction_endpoint;
    reg [3:0] pending_send = PENDING_SEND_NONE;
    reg [3:0] packet_state;
    reg [3:0] transaction_state = TRANSACTION_STATE_IDLE;
    reg [3:0] stall_counter;
    reg [8:0] words_read_written;
    reg data_sync_bit; // TODO implement data sync bit error handling
    reg [4:0] token_crc;
    reg [15:0] data_crc;

    wire read_complete = read_write_bits_count == 1;
    wire write_complete = read_write_bits_count == 1;
    wire [3:0] usb_control_handshake_pid = { usb_control[22:21], 2'b10 };

    task got_bit();
        next_send_eop = 0;
        if (read_write_bits_count > 0) begin
            next_read_write_bits_count = read_write_bits_count - 1;
        end

        case (packet_state)
            PACKET_STATE_SYNCING: begin
                if (read_complete) begin
                    if (read_bits[31:24] == 8'b10000000) begin
                        next_packet_state = PACKET_STATE_READING_PID;
                        next_read_write_bits_count = 8;
                    end else begin
                        `ifdef simulation
                            $stop;
                        `else
                            next_packet_state = PACKET_STATE_AWAIT_END_OF_PACKET;
                        `endif
                    end
                end
            end
            PACKET_STATE_READING_PID: begin
                if (read_complete) begin
                    if (read_bits[27:24] == ~read_bits[31:28]) begin // check PID check
                        case (transaction_state)
                            TRANSACTION_STATE_AWAIT_DATA: begin
                                if (read_bits[27:24] == current_data_pid) begin
                                    next_packet_state = PACKET_STATE_READING_DATA;
                                    next_data_crc = ~0;
                                    next_words_read_written = 0;
                                    next_read_write_bits_count = 32;
                                end else begin
                                    `ifdef simulation
                                        $display("got bad pid for context %b", read_bits[27:24]);
                                        $stop;
                                    `endif
                                    next_packet_state = PACKET_STATE_AWAIT_END_OF_PACKET;
                                end
                            end
                            TRANSACTION_STATE_IDLE: begin
                                if (read_bits[27:24] == PID_IN
                                    || read_bits[27:24] == PID_OUT
                                    || read_bits[27:24] == PID_SETUP
                                ) begin
                                    next_read_write_bits_count = 16;
                                    next_current_transaction_pid = read_bits[27:24];
                                    next_packet_state = PACKET_STATE_READING_TOKEN;
                                    next_token_crc = ~0;
                                    next_transaction_state = TRANSACTION_STATE_AWAIT_DATA;
                                end else begin
                                    `ifdef simulation
                                        $stop;
                                    `endif
                                    next_packet_state = PACKET_STATE_AWAIT_END_OF_PACKET;
                                end
                            end
                            TRANSACTION_STATE_AWAIT_HANDSHAKE: begin
                                `ifdef simulation
                                    if (read_bits[27:24] != PID_ACK) begin
                                        $stop;
                                    end
                                `endif
                                next_data_sync_bit = !data_sync_bit;
                                next_transaction_state = TRANSACTION_STATE_IDLE;
                                next_packet_state = PACKET_STATE_AWAIT_END_OF_PACKET;
                            end
                            default:
                                `ifdef simulation
                                    $stop;
                                `else
                                    next_packet_state = PACKET_STATE_AWAIT_END_OF_PACKET;
                                `endif
                        endcase
                    end else begin
                        `ifdef simulation
                            $stop;
                        `else
                            next_packet_state = PACKET_STATE_AWAIT_END_OF_PACKET;
                        `endif
                    end
                end 
            end
            PACKET_STATE_READING_TOKEN: begin
                if (read_complete) begin
                    if (next_token_crc == 5'b01100) begin
                        next_current_transaction_address = read_bits[22:16];
                        next_current_transaction_endpoint = read_bits[26:23];

                        if (current_transaction_pid == PID_OUT || current_transaction_pid == PID_SETUP) begin
                            next_transaction_state = TRANSACTION_STATE_AWAIT_DATA;
                            next_packet_state = PACKET_STATE_AWAIT_END_OF_PACKET; // TODO ignore if not receiving EOP immediately?

                            if (current_transaction_pid == PID_SETUP) begin
                                next_data_sync_bit = 0;
                            end
                        end else if (current_transaction_pid == PID_IN) begin
                            got_usb_packet = 1;
                            next_pending_send = PENDING_SEND_DATA;
                            next_packet_state = PACKET_STATE_AWAIT_END_OF_PACKET;
                            set_usb_control_address = next_current_transaction_address;
                            set_usb_control_endpoint = next_current_transaction_endpoint;
                            set_usb_control_token = current_transaction_pid[3:2];
                        end else begin
                            // this is an internal error, should never happen
                            `ifdef simulation
                                $stop;
                            `endif
                        end
                    end else begin
                        `ifdef simulation
                            $display("got bad next_token_crc: 0x%h", next_token_crc);
                            $stop;
                        `else
                            next_packet_state = PACKET_STATE_AWAIT_END_OF_PACKET;
                        `endif
                    end
                end
            end
            PACKET_STATE_READING_DATA: begin
                if (se0) begin
                    if (data_crc == 16'b1000000000001101) begin
                        if (words_read_written < 256) begin
                            // read_write_bits_count - 1 is the number of bits that would still
                            // need to be read to get a whole word
                            data_buffer_write_value = read_bits >> (read_write_bits_count - 1);
                            data_buffer_address = words_read_written[7:0];
                            write_to_data_buffer = 1;
                        end
                        next_data_sync_bit = !data_sync_bit;
                        // 33 - read_write_bits_count is the number of bits that have been read on this word
                        // need to set all of it here
                        // - 2 because of the two crc bytes
                        set_usb_control_data_length = (words_read_written * 4) + ((33 - { 4'b0, read_write_bits_count }) / 8) - 2;
                        set_usb_control_address = current_transaction_address;
                        set_usb_control_endpoint = current_transaction_endpoint;
                        set_usb_control_token = current_transaction_pid[3:2];
                        got_usb_packet = 1;
                        next_pending_send = PENDING_SEND_HANDSHAKE;
                        next_packet_state = PACKET_STATE_FINISH;
                    end else begin
                        `ifdef simulation
                            $display("got bad data_crc: 0x%h, words_read_written: %b", data_crc, words_read_written);
                            $stop;
                        `else
                            next_packet_state = PACKET_STATE_AWAIT_END_OF_PACKET;
                        `endif
                    end
                end else if (read_complete) begin
                    // words_read_written can be greater than 255 because of the two crc
                    // bytes after the data payload but these don't need to be written
                    if (words_read_written < 256) begin
                        data_buffer_write_value = read_bits;
                        data_buffer_address = words_read_written[7:0];
                        write_to_data_buffer = 1;
                    end
                    next_words_read_written = words_read_written + 1;
                    next_read_write_bits_count = 32;
                end
            end
            PACKET_STATE_AWAIT_END_OF_PACKET: begin
                // TODO implement timeout?
                if (se0) begin
                    // end of packet
                    next_packet_state = PACKET_STATE_FINISH;
                end
            end
            PACKET_STATE_FINISH: begin // to implement a pause after receiving eop
                if (pending_send != PENDING_SEND_NONE) begin
                    next_stall_counter = 4; // could be shorter while still complying with spec // TODO use read_write_bits_count instead of separate stall counter
                    next_packet_state = PACKET_STATE_WRITE_PAUSE;
                end else begin
                    next_top_state = TOP_STATE_IDLE;
                end
            end
            PACKET_STATE_WRITE_PAUSE: begin
                if (stall_counter == 0 && !usb_packet_ready) begin // usb_packet_ready is set to zero when the software
                                                                   // has handled the transaction
                    if (!usb_control[23]) begin // usb_control[23] is whether to ignore the transaction
                        next_consecutive_nzri_data_ones = 0;
                        next_write_enable = 1;
                        next_packet_state = PACKET_STATE_WRITE_SYNC;
                        next_read_write_bits_count = 8;
                        next_read_write_buffer[7:0] = DECODED_SYNC_PATTERN;
                    end else begin
                        next_top_state = TOP_STATE_IDLE;
                        next_transaction_state = TRANSACTION_STATE_IDLE;
                    end
                end
            end
            PACKET_STATE_WRITE_SYNC: begin
                if (write_complete) begin
                    case (pending_send)
                        PENDING_SEND_HANDSHAKE: begin
                            next_read_write_bits_count = 8;
                            next_read_write_buffer[7:0] = { ~usb_control_handshake_pid, usb_control_handshake_pid };
                            next_packet_state = PACKET_STATE_WRITE_HANDSHAKE;
                        end
                        PENDING_SEND_DATA: begin
                            next_read_write_bits_count = 8;
                            next_read_write_buffer[7:0] = { ~current_data_pid, current_data_pid };
                            next_packet_state = PACKET_STATE_WRITE_DATA_PID;
                        end
                        default: begin
                            // for now
                            `ifdef simulation
                                $stop;
                            `endif
                        end
                    endcase

                    next_pending_send = PENDING_SEND_NONE;
                end
            end
            PACKET_STATE_WRITE_HANDSHAKE: begin
                if (write_complete) begin
                    next_transaction_state = TRANSACTION_STATE_IDLE;
                    next_send_eop = 1;
                    next_packet_state = PACKET_STATE_SEND_EOP;
                end
            end
            PACKET_STATE_WRITE_DATA_PID: begin
                if (write_complete) begin
                    next_transaction_state = TRANSACTION_STATE_AWAIT_HANDSHAKE;

                    if (usb_control[9:0] > 0) begin // data length
                        next_pending_load = 1;
                        next_words_read_written = 0;
                        data_buffer_address = 0;
                        next_read_write_bits_count = bytes_to_read_write_bit_count(usb_control[9:0]);
                        next_data_crc = ~0;
                        next_packet_state = PACKET_STATE_WRITE_DATA;
                    end else begin
                        next_read_write_buffer[15:0] = 0;
                        next_read_write_bits_count = 16;
                        next_packet_state = PACKET_STATE_WRITE_DATA_CRC;
                    end
                end
            end
            PACKET_STATE_WRITE_DATA: begin
                // this write code is complicated :(
                if (write_complete) begin
                    next_words_read_written = words_read_written + 1;
                    if (usb_control[9:0] > (next_words_read_written * 4)) begin // if usb_data_length is greater than the number
                                                                               // of bytes that have been written, it is
                                                                               // guaranteed to greater than next_words_written * 4
                                                                               // because 4 bytes are always written if there
                                                                               // are 4 bytes available
                        data_buffer_address = next_words_read_written[7:0];
                        next_pending_load = 1; // needed because reads from memory are delayed one clock cycle
                                               // (of the module input clock, not a bit time)
                        next_read_write_bits_count = bytes_to_read_write_bit_count(usb_control[9:0] - (next_words_read_written * 4));
                    end else begin
                        // reverse and negate crc bits
                        for (reg [4:0] i = 0; i < 16; i = i + 1) begin
                            // use next_data_crc instead of data_crc because I need to include the current bit
                            next_read_write_buffer[i] = !next_data_crc[15 - i];
                        end
                        next_read_write_bits_count = 16;
                        next_packet_state = PACKET_STATE_WRITE_DATA_CRC;
                    end
                end

                // TODO need to send the CRC16 at the end of the packet
            end
            PACKET_STATE_WRITE_DATA_CRC: begin
                if (write_complete) begin
                    next_send_eop = 1;
                    next_packet_state = PACKET_STATE_SEND_EOP;
                end
            end
            PACKET_STATE_SEND_EOP: begin
                next_send_eop = 1;
                next_packet_state = PACKET_STATE_WRITE_FINISH;
            end
            PACKET_STATE_WRITE_FINISH: begin
                next_write_enable = 0;
                next_top_state = TOP_STATE_IDLE;
            end
        endcase
    endtask

    always @(posedge clock48) begin
        top_state <= next_top_state;
        packet_state <= next_packet_state;
        transaction_state <= next_transaction_state;
        read_write_clock_counter <= next_read_write_clock_counter;
        consecutive_nzri_data_ones <= next_consecutive_nzri_data_ones;
        read_write_bits_count <= next_read_write_bits_count;
        previous_data <= next_previous_data;
        read_write_buffer <= next_read_write_buffer;
        stall_counter <= next_stall_counter;
        pending_load <= next_pending_load;
        current_transaction_pid <= next_current_transaction_pid;
        pending_send <= next_pending_send;
        write_enable <= next_write_enable;
        send_eop <= next_send_eop;
        words_read_written <= next_words_read_written;
        current_transaction_address <= next_current_transaction_address;
        current_transaction_endpoint <= next_current_transaction_endpoint;
        data_sync_bit <= next_data_sync_bit;
        token_crc <= next_token_crc;
        data_crc <= next_data_crc;

        if (se0) begin
            reset_counter <= reset_counter + 1;
        end else begin
            reset_counter <= 0;
        end
    end

    function [5:0] bytes_to_read_write_bit_count(input [9:0] bytes);
        if (bytes > 4) begin
            bytes_to_read_write_bit_count = 32;
        end else begin
            bytes_to_read_write_bit_count = workaround_select(bytes * 8);
        end
    endfunction

    // syntax workaround, there probably a proper way to do this, whatever
    function [5:0] workaround_select(input [9:0] in);
        workaround_select = in[5:0];
    endfunction
endmodule
