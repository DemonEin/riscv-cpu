module tb_registers;

    reg [4:0] read_address, write_address;
    reg [31:0] write_value, read_value;
    reg clk;

    registers r(clk, read_address, write_address, write_value, read_value);

    always #1 clk = !clk;

    initial begin
        read_address = 0;
        write_address = 0;
        write_value = 0;
        #2 if (read_value != 0) $error;

        write_address = 0;
        write_value = 2;
        read_address = 0;
        #2 if (read_value != 0) $error;

        write_address = 2;
        write_value = 2;
        read_address = 2;
        #2 if (read_value != 2) $error;

        $finish;
    end
        
endmodule
