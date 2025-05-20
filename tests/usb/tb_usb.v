`include "usb_constants.v"

localparam FULL_SPEED_PERIOD = 83.3333333ns; // the period of usb full-speed transimssion (12 mhz
localparam SYNC_PATTERN = 8'b01010100;
localparam STDIN = 32'h8000_0000;

module tb_usb();
    wire usb_pullup;

    reg output_data, output_data_n; // TODO rename these to output
    reg write_enable;
    tri1 data_wire = write_enable ? output_data : 1'bz;
    tri0 data_n_wire = write_enable ? output_data_n : 1'bz;
    wire end_of_packet = !data_wire && !data_n_wire;
    reg data_sync_bit_receive = 0;
    reg data_sync_bit_transmit = 0;
    wire [3:0] current_data_pid_receive = { data_sync_bit_receive, PID_DATA0[2:0] };
    wire [3:0] current_data_pid_transmit = { data_sync_bit_transmit, PID_DATA0[2:0] };

    wire gpio_1, gpio_2, gpio_3, gpio_4, gpio_5, gpio_6, gpio_7, gpio_8, gpio_9, gpio_10;

    reg [7:0] data_list[1023];
    reg [31:0] data_list_length;

    reg clock48;

    reg [6:0] test_device_address = 0;
    reg [3:0] test_device_endpoint = 0;

    wire r, g, b, null;
    top top(
        clock48,
        1,
        data_wire,
        data_n_wire,
        usb_pullup,
        r,
        g,
        b,
        gpio_1,
        gpio_2,
        gpio_3,
        gpio_4,
        gpio_5,
        gpio_6,
        gpio_7,
        gpio_8,
        gpio_9,
        gpio_10
    );

    initial begin
        reg [31:0] bytes_read = $fread(data_list, STDIN);

        // reset
        write_enable = 1;
        output_data = 0;
        output_data_n = 0;
        #30ms
        write_enable = 0;

        // idle
        #10ms

        $display("tb_usb.v: set device address");
        set_device_address(1);
        #10ms // give some time for the device to change address; this is in
              // place of the correct thing to do here which would be to retry
              // until the device responds

        $display("tb_usb.v: get device descriptor");
        do_control_transfer(
            8'b10000000,
            BREQUEST_GET_DESCRIPTOR,
            DESCRIPTOR_TYPE_DEVICE << 8,
            0,
            18,
            data_list,
            data_list_length
        );
        if (data_list_length != 18) $stop;
        if (data_list[0] != 18) $stop;
        if (data_list[1] != DESCRIPTOR_TYPE_DEVICE) $stop;
        if (data_list[17] < 1) $stop;

        $display("tb_usb.v: get configuration descriptor");
        do_control_transfer(
            8'b10000000,
            BREQUEST_GET_DESCRIPTOR,
            DESCRIPTOR_TYPE_CONFIGURATION << 8,
            0,
            8,
            data_list,
            data_list_length
        );
        if (data_list_length != 8) $stop;
        if (data_list[0] != 9) $stop;
        if (data_list[1] != DESCRIPTOR_TYPE_CONFIGURATION) $stop;

        do_control_transfer(
            8'b10000000,
            BREQUEST_GET_DESCRIPTOR,
            DESCRIPTOR_TYPE_CONFIGURATION << 8,
            0,
            64,
            data_list,
            data_list_length
        );
        if (data_list_length < 18) $stop; // because this must contain one configuration descriptor
                                          // (length 9) and at least one interface descriptor
                                          // (length 9)
        if (data_list[0] != 9) $stop;
        if (data_list[1] != DESCRIPTOR_TYPE_CONFIGURATION) $stop;
        if (data_list[2] <= 9) $stop;
        if (data_list[9] != 9) $stop;

        do_control_transfer(
            8'b00000000,
            BREQUEST_SET_CONFIGURATION,
            1,
            0,
            0,
            data_list,
            data_list_length
        );
        do_control_transfer(
            8'b10000000,
            BREQUEST_GET_CONFIGURATION,
            0,
            0,
            1,
            data_list,
            data_list_length
        );
        if (data_list_length != 1) $stop;
        if (data_list[0] != 1) $stop;

        do_control_transfer(
            8'b00000000,
            13,
            0,
            0,
            1,
            data_list,
            data_list_length
        );
        #10ms

        $finish;
    end

    always #10.4166667ns begin // half of the 48mhz period
        clock48 <= ~clock48;
    end

    task set_device_address(input [6:0] address);
        do_control_transfer(0, BREQUEST_SET_ADDRESS, { 9'b0, address }, 0, 0, data_list, data_list_length);
        test_device_address = address;
    endtask

    task do_control_transfer(
        input [7:0] bmRequestType,
        input [7:0] bRequest,
        input [15:0] wValue,
        input [15:0] wIndex,
        input [15:0] wLength,
        inout [7:0] data[1023],
        output [31:0] byte_count, // only used for IN/read transfers
    );
        do_setup_transaction(
            bmRequestType,
            bRequest,
            wValue,
            wIndex,
            wLength
        );

        if (bmRequestType[7] == 1) begin
            // control read transfer
            do_bulk_in_transaction(data, byte_count);

            // status stage
            do_bulk_out_transaction(data, 0, PID_DATA1);
        end else begin
            // control write transfer
            if (wLength > 0) begin
                do_bulk_out_transaction(data, { 16'b0, wLength }, PID_DATA0);  // TODO toggle DATA0/DATA1
            end

            // status stage
            do_bulk_in_transaction(data, byte_count); // the data and byte_count outputs here are unused
            if (byte_count != 0) begin
                $stop("received data packet non-zero size");
            end
        end
    endtask

    reg [3:0] do_bulk_out_transaction_pid;
    reg [31:0] do_bulk_out_transaction_timeout;
    task do_bulk_out_transaction(input [7:0] data[1023], input [31:0] byte_count, input [3:0] data_pid);
        $display("tb_usb.v: do_bulk_out_transaction");
        do_bulk_out_transaction_timeout = 0;

        send_token_packet(PID_OUT);
        send_data_packet(current_data_pid_transmit, data, byte_count);
        receive_handshake(do_bulk_out_transaction_pid);
        while (do_bulk_out_transaction_pid != PID_ACK) begin
            if (do_bulk_out_transaction_pid != PID_NAK) begin
                $display("got bad pid for bulk out handshake 0b%b", do_bulk_out_transaction_pid);
                $stop;
            end

            do_bulk_out_transaction_timeout = do_bulk_out_transaction_timeout + 1;
            if (do_bulk_out_transaction_timeout >= 500) begin // takes 50ms
                $display("timeout when doing bulk out transaction");
                $stop;
            end

            #100us;
            send_token_packet(PID_OUT);
            send_data_packet(current_data_pid_transmit, data, byte_count);
            receive_handshake(do_bulk_out_transaction_pid);
        end

        data_sync_bit_transmit = !data_sync_bit_transmit;
    endtask

    reg [3:0] do_bulk_in_transaction_pid;
    reg [31:0] do_bulk_in_transaction_timeout;
    task do_bulk_in_transaction(output [7:0] data[1023], output [31:0] byte_count);
        $display("tb_usb.v: do_bulk_in_transaction");
        do_bulk_in_transaction_timeout = 0;

        send_token_packet(PID_IN);
        receive_packet(do_bulk_in_transaction_pid, data, byte_count);
        while (do_bulk_in_transaction_pid != current_data_pid_receive) begin
            if (do_bulk_in_transaction_pid != PID_NAK) begin
                $display("received incorrect pid for data packet: %b", do_bulk_in_transaction_pid);
                $stop;
            end

            do_bulk_in_transaction_timeout = do_bulk_in_transaction_timeout + 1;
            if (do_bulk_in_transaction_timeout >= 500) begin // takes 50ms
                $display("timeout when doing bulk in transaction");
                $stop;
            end

            #100us;
            send_token_packet(PID_IN);
            receive_packet(do_bulk_in_transaction_pid, data, byte_count);
        end

        data_sync_bit_receive = !data_sync_bit_receive;
        send_token_packet(PID_ACK);
    endtask

    reg [7:0] do_setup_transaction_data[1023];
    reg [3:0] do_setup_transaction_pid;
    task do_setup_transaction(
        input [7:0] bmRequestType,
        input [7:0] bRequest,
        input [15:0] wValue,
        input [15:0] wIndex,
        input [15:0] wLength
    );
        $display("tb_usb.v: do_setup_transaction");
        send_token_packet(PID_SETUP);
        do_setup_transaction_data[0] = bmRequestType;
        do_setup_transaction_data[1] = bRequest;
        do_setup_transaction_data[2] = wValue[7:0];
        do_setup_transaction_data[3] = wValue[15:8];
        do_setup_transaction_data[4] = wIndex[7:0];
        do_setup_transaction_data[5] = wIndex[15:8];
        do_setup_transaction_data[6] = wLength[7:0];
        do_setup_transaction_data[7] = wLength[15:8];
        send_data_packet(PID_DATA0, do_setup_transaction_data, 8);
        data_sync_bit_transmit = 1;
        data_sync_bit_receive = 1;
        receive_handshake(do_setup_transaction_pid);
        if (do_setup_transaction_pid != PID_ACK) begin
            $display("did not get ACK after setup packet, got pid 0b%b", do_setup_transaction_pid);
        end
    endtask

    reg [7:0] receive_ack_data[1023];
    reg [31:0] receive_ack_data_length;
    task receive_handshake(output [3:0] pid);
        receive_packet(pid, receive_ack_data, receive_ack_data_length);
    endtask

    reg [7:0] send_token_packet_data[1026];
    reg [4:0] token_crc;
    task send_token_packet(input [3:0] pid);
        send_token_packet_data[0] = { ~pid, pid };

        // generate crc
        token_crc = ~0;
        for (reg [31:0] bit_index = 0; bit_index < 11; bit_index = bit_index + 1) begin
            token_crc = token_crc[4] ^ { test_device_endpoint, test_device_address }[bit_index]
                ? (token_crc << 1) ^ 5'b00101
                : (token_crc << 1);
        end

        send_token_packet_data[1] = { test_device_endpoint[0], test_device_address };
        send_token_packet_data[2][2:0] = test_device_endpoint[3:1];
        for (reg [31:0] i = 0; i < 5; i = i + 1) begin
            send_token_packet_data[2][i + 3] = !token_crc[4 - i];
        end

        send_packet(send_token_packet_data, 3);
    endtask

    reg [7:0] send_data_packet_data [1026];
    task send_data_packet(input [3:0] pid, input [7:0] data [1023], input [31:0] byte_count);
        for (reg [31:0] i = byte_count; i >= 1; i = i - 1) begin
            send_data_packet_data[i] = data[i - 1];
        end
        send_data_packet_data[0] = { ~pid, pid };

        // generate crc, duplicated in receive_data but whatever
        data_crc = ~0;
        for (reg [31:0] bit_index = 8; bit_index < (byte_count + 1) * 8; bit_index = bit_index + 1) begin
            data_crc = data_crc[15] ^ send_data_packet_data[bit_index / 8][bit_index % 8]
                    ? (data_crc << 1) ^ 16'b1000000000000101
                    : (data_crc << 1);
        end

        for (reg [31:0] i = 0; i < 16; i = i + 1) begin
            send_data_packet_data[byte_count + 1 + (i / 8)][i % 8] = !data_crc[15 - i];
        end

        send_packet(send_data_packet_data, byte_count + 3);
    endtask

    task send_handshake_packet(input [3:0] pid);
        data_list[0] = { ~pid, pid };
        send_packet(data_list, 1);
    endtask

    reg previous_data;
    reg [31:0] consecutive_decoded_ones;
    reg input_bit;
    task send_packet(input [7:0] data[1026], input [31:0] byte_count);
        write_enable = 1;
        // send sync pattern
        for (reg [3:0] i = 0; i < 8; i = i + 1) begin
            output_data = SYNC_PATTERN[7 - i[2:0]];
            output_data_n = ~output_data;
            #FULL_SPEED_PERIOD;
        end

        // send output_data
        previous_data = 0; // since the sync packet ends at low level
        consecutive_decoded_ones = 1; // since the sync packet ends with an encoded one
        for (reg [31:0] i = 0; i < byte_count; i = i + 1) begin
            for (reg [7:0] j = 0; j < 8; j = j + 1) begin
                input_bit = data[i][j[2:0]];

                if (input_bit) begin
                    consecutive_decoded_ones = consecutive_decoded_ones + 1;
                end else begin
                    consecutive_decoded_ones = 0;
                end

                send_bit(!(input_bit ^ previous_data));

                if (consecutive_decoded_ones == 6) begin
                    // send bit-stuffed bit
                    consecutive_decoded_ones = 0;
                    send_bit(~previous_data);
                end else if (consecutive_decoded_ones > 6) begin
                    $stop("this should not happen");
                end
            end
        end

        // send end of packet
        output_data = 0;
        output_data_n = 0;
        #FULL_SPEED_PERIOD;
        #FULL_SPEED_PERIOD;
        write_enable = 0;

        // the spec requires at least a two bit-time delay between packets,
        // do it here so upon exit from this task it is valid to send another
        // packet
        #FULL_SPEED_PERIOD;
        #FULL_SPEED_PERIOD;
    endtask

    reg [7:0] raw_data[1026];
    reg [15:0] data_crc;
    reg [31:0] received_bit_count;
    reg nzri_decoded_bit;
    reg [31:0] receive_timeout;
    // receives packet and verifies all token lengths and checksums
    // data and byte_count are only defined for data packets
    task receive_packet(output [3:0] pid, output [7:0] data[1023], output[31:0] byte_count);
        // receive sync pattern
        // assume starting in idle or eop state
        receive_timeout = 14; // usb spec says the timeout is at minimum 16, but two bit times are
                              // already included at the end of send_packet
        while (data_wire != 0 || data_n_wire != 1) begin
            #FULL_SPEED_PERIOD;
            receive_timeout = receive_timeout - 1;
            if (receive_timeout == 0) begin
                $display("timeout when waiting to receive packet");
                $stop;
            end
        end

        // get sync
        for (reg [31:0] i = 0; i < 8; i = i + 1) begin
            if (data_wire != SYNC_PATTERN[7 - i[2:0]] || data_n_wire != !data_wire) begin
                $stop;
            end else begin
                #FULL_SPEED_PERIOD;
            end
        end

        // read output_data
        previous_data = SYNC_PATTERN[0];
        consecutive_decoded_ones = 1;
        received_bit_count = 0;
        receive_timeout = 1025 * 8; // receive at max this many bytes
        while (!end_of_packet && receive_timeout > 0) begin
            nzri_decoded_bit = !(data_wire ^ previous_data);

            if (consecutive_decoded_ones < 6) begin
                raw_data[received_bit_count / 8][received_bit_count % 8] = nzri_decoded_bit;
                received_bit_count = received_bit_count + 1;
            end

            if (nzri_decoded_bit == 1) begin
                consecutive_decoded_ones = consecutive_decoded_ones + 1;
            end else begin
                consecutive_decoded_ones = 0;
            end

            previous_data = data_wire;
            #FULL_SPEED_PERIOD;
        end

        if (receive_timeout == 0) begin
            $stop;
        end

        if (received_bit_count % 8 != 0) begin
            $stop;
        end

        byte_count = received_bit_count / 8;

        #FULL_SPEED_PERIOD; // wait once for the second end of packet bit time

        // wait twice for the standard inter-packet delay
        #FULL_SPEED_PERIOD;
        #FULL_SPEED_PERIOD;

        // at this point raw_data contains the raw_data and byte_count
        // contains the raw byte count

        if (raw_data[0][3:0] != ~raw_data[0][7:4]) begin
            $display("received invalid pid checksum");
            $stop;
        end

        pid = raw_data[0][3:0];

        case (pid[1:0])
            0'b00: begin
                // special pid
                $display("no test support for special packets");
                $stop;
            end
            0'b01: begin
                // token pid
                $display("no test support for token packets");
                $stop;
            end
            0'b10: begin
                // handshake pid
                if (byte_count != 1) begin
                    $display("received handshake packet with %b bytes", byte_count);
                    $stop;
                end
            end
            0'b11: begin
                // data pid

                if (byte_count < 3) begin
                    $display("received only %d bytes in data packet", byte_count);
                    $stop;
                end

                // verify crc
                data_crc = ~0;
                for (reg [31:0] bit_index = 8; bit_index < byte_count * 8; bit_index = bit_index + 1) begin
                    data_crc = data_crc[15] ^ raw_data[bit_index / 8][bit_index % 8]
                            ? (data_crc << 1) ^ 16'b1000000000000101
                            : (data_crc << 1);
                end
                if (data_crc != 16'b1000000000001101) begin
                    $display("data packet received with invalid crc, %h", data_crc);
                    $stop;
                end

                byte_count = byte_count - 3;
                for (reg [31:0] i = 0; i < byte_count; i = i + 1) begin
                    data[i] = raw_data[i + 1];
                end
            end
        endcase
    endtask

    task send_bit(input value);
        output_data = value;
        output_data_n = ~output_data;
        previous_data = output_data;
        #FULL_SPEED_PERIOD;
    endtask

endmodule
