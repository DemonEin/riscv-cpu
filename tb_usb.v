localparam FULL_SPEED_PERIOD = 83.3333333ns; // the period of usb full-speed transimssion (12 mhz
localparam SYNC_PATTERN = 8'b01010100;

module tb_usb();
    wire data_wire, data_n_wire, usb_pullup;

    reg data, data_n;
    assign data_wire = data;
    assign data_n_wire = data_n;

    reg data_list[1024 * 8];
    reg [12:0] data_index = 0;

    reg clock48;

    wire r, g, b;
    top top(clock48, data_wire, data_n_wire, usb_pullup, r, g, b);

    initial begin
        $readmemb("/dev/stdin", data_list);

        // reset
        $display("sending reset signal");
        data = 0;
        data_n = 0;
        #30ms

        // idle
        $display("sending idle signal");
        data = 1;
        data_n = 0;
        #10ms

        // send sync pattern
        for (reg [3:0] i = 0; i < 8; i = i + 1) begin
            data = SYNC_PATTERN[7 - i[2:0]];
            data_n = ~data;
            $display("sending data: %b from index: %d", data, 7 - i[2:0]);
            #FULL_SPEED_PERIOD;
        end

        // send data
        for (reg [31:0] i = 0; i < 1024 * 8; i = i + 1) begin
            data = data_list[i];
            data_n = ~data;
            $display("sending real data %b", data);
            #FULL_SPEED_PERIOD;
        end

        // send end of packet
        data = 0;
        data_n = 0;
        #FULL_SPEED_PERIOD
        #FULL_SPEED_PERIOD

        #10ms

        $display(top.usb_packet_buffer[0][0]);
        
        $stop;
    end

    always #10.4166667ns begin // half of the 48mhz period
        clock48 <= ~clock48;
    end

endmodule
