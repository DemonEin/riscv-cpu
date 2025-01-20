localparam FULL_SPEED_PERIOD = 83.3333333ns; // the period of usb full-speed transimssion (12 mhz
localparam SYNC_PATTERN = 8'b01010100;

module tb_usb();
    wire data_wire, data_n_wire, usb_pullup, packet_ready;

    reg data, data_n;
    assign data_wire = data;
    assign data_n_wire = data_n;

    reg data_list[1024 * 8];
    reg [12:0] data_index = 0;

    reg clock48;

    usb usb(clock48, data_wire, data_n_wire, usb_pullup, packet_ready);

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

        #10ms
        
        $stop; // only hit if packet_ready isn't set which it should be
    end

    always @(posedge packet_ready) begin
        $display("bits: %b", usb.packet_buffer[0][3:0]);
        $finish;
    end

    always #10.4166667ns begin // half of the 48mhz period
        clock48 <= ~clock48;
    end

endmodule
