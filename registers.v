// when write addresses 1 and 2 are to the same register, write value 1 takes
// precedence
module registers(clock, write_address_1, write_value_1, write_address_2, write_value_2, read_address_1, read_value_1, read_address_2, read_value_2);
    input clock;
    input [4:0] read_address_1, read_address_2, write_address_1, write_address_2;
    input [31:0] write_value_1, write_value_2;
    output [31:0] read_value_1, read_value_2;

    reg [31:0] r[31:1];

    always @(posedge clock) begin
        if (write_address_1 != 0) begin
            r[write_address_1] <= write_value_1;
        end
        if (write_address_2 != 0 && write_address_2 != write_address_1) begin
            r[write_address_2] <= write_value_2;
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
