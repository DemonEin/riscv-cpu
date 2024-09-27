module tb_alu;
    reg [3:0] operation;
    reg [31:0] op1, op2, result;

    alu alu(operation, op1, op2, result);

    initial begin
        operation = 4'b0000; // add
        op1 = 1;
        op2 = 1;
        #1 if (result != 2) $error;

        operation = 4'b0011; // unsigned less than
        op1 = 1;
        op2 = 2;
        #1 if (result != 1) $error;

        operation = 4'b0010; // signed less than
        op1 = -1;
        op2 = 2;
        #1 if (result != 1) $error;

        op1 = 1;
        op2 = 1;
        #1 if (result != 0) $error;
    end

endmodule
