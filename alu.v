module alu(operation, operand1, operand2, result);
    input [3:0] operation;
    input [31:0] operand1, operand2;
    output reg [31:0] result;

    always @* begin
        case (operation)
            // TODO ignore some top bits since they're unneeded
            ALU_OPCODE_ADD: result = operand1 + operand2;
            ALU_OPCODE_SUBTRACT: result = operand1 - operand2;
            ALU_OPCODE_LEFT_SHIFT: result = operand1 << operand2[4:0];
            ALU_OPCODE_XOR: result = operand1 ^ operand2;
            ALU_OPCODE_RIGHT_SHIFT_LOGICAL: result = operand1 >> operand2[4:0];
            ALU_OPCODE_RIGHT_SHIFT_ARITHMETIC: result = operand1 >>> operand2[4:0];
            ALU_OPCODE_OR: result = operand1 | operand2;
            ALU_OPCODE_AND: result = operand1 & operand2;
            default: result = 0;
        endcase
    end
endmodule
