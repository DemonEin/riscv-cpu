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

    reg [7:0] data_list[1024];
    reg [12:0] data_index = 0;

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

        send_token_packet(4'b1101);
        #FULL_SPEED_PERIOD;
        #FULL_SPEED_PERIOD;
        data_list[0] = { 4'b1100, 4'b0011 };
        data_list[2] = 5;
        send_packet(data_list, 9);

        receive_packet();
        if (received_bit_count != 8) begin
            $display("received_bit_count: %d", received_bit_count);
            $stop;
        end

        #10ms

        $finish;
    end

    always #10.4166667ns begin // half of the 48mhz period
        clock48 <= ~clock48;
    end

    task send_token_packet(input [3:0] pid);
        data_list[0] = { ~pid, pid };
        data_list[1] = { test_device_endpoint[0], test_device_address };
        data_list[2] = { 5'b0, test_device_endpoint[3:1] }; // leave CRC5 as zero for now
        send_packet(data_list, 3);
    endtask

    reg previous_data;
    reg [31:0] consecutive_decoded_ones;
    reg input_bit;
    task send_packet(input [7:0] data_list[1024], input [31:0] data_list_size);
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
        for (reg [31:0] i = 0; i < data_list_size; i = i + 1) begin
            for (reg [7:0] j = 0; j < 8; j = j + 1) begin
                input_bit = data_list[i][j[2:0]];

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
    endtask

    reg [31:0] received_bit_count;
    reg nzri_decoded_bit;
    reg [31:0] receive_timeout;
    task receive_packet();
        // receive sync pattern
        // assume starting in idle or eop state
        while (data_wire != 0 || data_n_wire != 1) begin
            #FULL_SPEED_PERIOD;
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
                data_list[received_bit_count / 8][received_bit_count % 8] = nzri_decoded_bit;
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
    endtask

    task send_bit(input value);
        output_data = value;
        output_data_n = ~output_data;
        previous_data = output_data;
        #FULL_SPEED_PERIOD;
    endtask

endmodule
