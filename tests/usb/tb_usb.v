localparam FULL_SPEED_PERIOD = 83.3333333ns; // the period of usb full-speed transimssion (12 mhz
localparam SYNC_PATTERN = 8'b01010100;
localparam STDIN = 32'h8000_0000;

module tb_usb();
    wire data_wire, data_n_wire, usb_pullup;

    reg data, data_n;
    assign data_wire = data;
    assign data_n_wire = data_n;

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
        data = 0;
        data_n = 0;
        #30ms

        // idle
        data = 1;
        data_n = 0;
        #10ms

        send_token_packet(4'b1101);
        #1ms
        data_list[0] = { 4'b1100, 4'b0011 };
        data_list[2] = 5;
        send_packet(data_list, 1);

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

    reg previous_output;
    reg [31:0] consecutive_input_ones;
    reg input_bit;
    task send_packet(input [7:0] data_list[1024], input [31:0] data_list_size);
        // send sync pattern
        for (reg [3:0] i = 0; i < 8; i = i + 1) begin
            data = SYNC_PATTERN[7 - i[2:0]];
            data_n = ~data;
            #FULL_SPEED_PERIOD;
        end

        // send data
        previous_output = 0; // since the sync packet ends at low level
        consecutive_input_ones = 1; // since the sync packet ends with an encoded one
        for (reg [31:0] i = 0; i < data_list_size; i = i + 1) begin
            for (reg [7:0] j = 0; j < 8; j = j + 1) begin
                input_bit = data_list[i][j[2:0]];

                if (input_bit) begin
                    consecutive_input_ones = consecutive_input_ones + 1;
                end else begin
                    consecutive_input_ones = 0;
                end

                send_bit(!(input_bit ^ previous_output));

                if (consecutive_input_ones == 6) begin
                    // send bit-stuffed bit
                    consecutive_input_ones = 0;
                    send_bit(~previous_output);
                end else if (consecutive_input_ones > 6) begin
                    $stop("this should not happen");
                end
            end
        end

        // send end of packet
        data = 0;
        data_n = 0;
        #FULL_SPEED_PERIOD;
        #FULL_SPEED_PERIOD;
    endtask

    task send_bit(input value);
        data = value;
        data_n = ~data;
        previous_output = data;
        #FULL_SPEED_PERIOD;
    endtask

endmodule
