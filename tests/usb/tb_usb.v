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

    reg [7:0] data_list[1023];
    reg [31:0] data_list_length;

    reg clock48;

    reg [6:0] test_device_address = 0;
    reg [3:0] test_device_endpoint = 0;

    wire r, g, b, null;
    top top(
        clock48,
        data_wire,
        data_n_wire,
        usb_pullup,
        r,
        g,
        b,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null
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

        set_device_address(1);
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

    task do_bulk_out_transaction(input [7:0] data[1023], input [31:0] byte_count, input [3:0] data_pid);
        send_token_packet(PID_OUT);
        send_data_packet(data_pid, data, byte_count);
        receive_ack();
    endtask

    task do_bulk_in_transaction(output [7:0] data[1023], output [31:0] byte_count);
        send_token_packet(PID_IN);
        receive_data(PID_DATA0, data, byte_count); // TODO toggle DATA0/DATA1
        send_token_packet(PID_ACK);
    endtask

    reg [7:0] do_setup_transaction_data[1023];
    task do_setup_transaction(
        input [7:0] bmRequestType,
        input [7:0] bRequest,
        input [15:0] wValue,
        input [15:0] wIndex,
        input [15:0] wLength
    );
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
        receive_ack();
    endtask


    reg [7:0] receive_data_data[1024];
    task receive_data(input [3:0] pid, output [7:0] data[1023], output [31:0] byte_count);
        $display("waiting to receive data packet");
        receive_packet(receive_data_data, byte_count);
        if (!(byte_count > 0 && receive_data_data[0] == { ~pid, pid })) begin
            $stop("did not receive data");
        end

        byte_count = byte_count - 1;
        for (reg [31:0] i = 0; i < byte_count; i = i + 1) begin
            data[i] = receive_data_data[i + 1];
        end
    endtask


    reg [7:0] receive_ack_data[1024];
    reg [31:0] receive_ack_data_length;
    task receive_ack();
        $display("waiting to receive ack packet");
        receive_packet(receive_ack_data, receive_ack_data_length);
        if (!(receive_ack_data_length == 1 && receive_ack_data[0] == { ~PID_ACK, PID_ACK })) begin
            $display("did not receive ack");
            $stop;
        end
    endtask

    reg [7:0] send_token_packet_data[1024];
    task send_token_packet(input [3:0] pid);
        send_token_packet_data[0] = { ~pid, pid };
        send_token_packet_data[1] = { test_device_endpoint[0], test_device_address };
        send_token_packet_data[2] = { 5'b0, test_device_endpoint[3:1] }; // leave CRC5 as zero for now
        send_packet(send_token_packet_data, 3);
    endtask

    reg [7:0] send_data_packet_data [1024];
    task send_data_packet(input [3:0] pid, input [7:0] data [1023], input [31:0] byte_count);
        for (reg [31:0] i = byte_count; i >= 1; i = i - 1) begin
            send_data_packet_data[i] = data[i - 1];
        end
        send_data_packet_data[0] = { ~pid, pid };
        send_packet(send_data_packet_data, byte_count + 1);
    endtask

    task send_handshake_packet(input [3:0] pid);
        data_list[0] = { ~pid, pid };
        send_packet(data_list, 1);
    endtask

    reg previous_data;
    reg [31:0] consecutive_decoded_ones;
    reg input_bit;
    task send_packet(input [7:0] data[1024], input [31:0] byte_count);
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

    reg [31:0] received_bit_count;
    reg nzri_decoded_bit;
    reg [31:0] receive_timeout;
    task receive_packet(output [7:0] data[1024], output[31:0] byte_count);
        // receive sync pattern
        // assume starting in idle or eop state
        receive_timeout = 477707; // 10 milliseconds of FULL_SPEED_PERIOD
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
                data[received_bit_count / 8][received_bit_count % 8] = nzri_decoded_bit;
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
    endtask

    task send_bit(input value);
        output_data = value;
        output_data_n = ~output_data;
        previous_data = output_data;
        #FULL_SPEED_PERIOD;
    endtask

endmodule
