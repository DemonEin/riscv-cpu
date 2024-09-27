module comparator(operation, operand1, operand2, result);
    input [2:0] operation;
    input [31:0] operand1, operand2;
    output reg result;

    always @* begin
        case (operation[2:1])
            2'b00: result = operand1 == operand2;
            2'b10: result = $signed(operand1) < $signed(operand2);
            2'b11: result = operand1 < operand2;
            // TODO make undefined
            default: result = 0;
        endcase
        result = result ^ operation[0];
    end
endmodule
