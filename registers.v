module registers(clock, write_address, write_value, read_address_1, read_value_1, read_address_2, read_value_2);
    input clock;
    input [4:0] read_address_1, read_address_2, write_address;
    input [31:0] write_value;
    output [31:0] read_value_1, read_value_2;

    reg [31:0] r[31:1];

    always @(posedge clock) begin
        if (write_address != 0) begin
            r[write_address] = write_value;
        end
    end

    assign read_value_1 = read_address_1 == 0 ? 0 : r[read_address_1];
    assign read_value_2 = read_address_2 == 0 ? 0 : r[read_address_2];

    /*
    initial begin
        while (1) begin
            #2;
            if (r[31] != 1) $error;
        end
    end
    */

endmodule
