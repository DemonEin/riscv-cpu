module alu(operation, operand1, operand2, result);
    input [3:0] operation;
    input [31:0] operand1, operand2;
    output reg [31:0] result;

    always @* begin
        case (operation)
            // TODO ignore some top bits since they're unneeded
            4'b0000: result = operand1 + operand2;
            4'b1000: result = operand1 - operand2;
            4'b0001: result = operand1 << operand2[4:0];
            4'b0100: result = operand1 ^ operand2;
            4'b0101: result = operand1 >> operand2[4:0];
            4'b1101: result = operand1 >>> operand2[4:0];
            4'b0110: result = operand1 | operand2;
            4'b0111: result = operand1 & operand2;
            default: result = 0;
        endcase
    end
endmodule
