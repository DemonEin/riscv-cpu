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

    wire r, g, b;
    top top(clock48, data_wire, data_n_wire, usb_pullup, r, g, b);

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

        // send sync pattern
        for (reg [3:0] i = 0; i < 8; i = i + 1) begin
            data = SYNC_PATTERN[7 - i[2:0]];
            data_n = ~data;
            #FULL_SPEED_PERIOD;
        end

        // send data
        for (reg [31:0] i = 0; i < bytes_read; i = i + 1) begin
            for (reg [7:0] j = 0; j < 8; j = j + 1) begin
                data = data_list[i][j[2:0]];
                data_n = ~data;
                #FULL_SPEED_PERIOD;
            end
        end

        // send end of packet
        data = 0;
        data_n = 0;
        #FULL_SPEED_PERIOD
        #FULL_SPEED_PERIOD

        #10ms

        $finish;
    end

    always #10.4166667ns begin // half of the 48mhz period
        clock48 <= ~clock48;
    end

endmodule
