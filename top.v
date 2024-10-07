localparam PROGRAM_MEMORY_SIZE = 1000;

module top(
    input clk48,

    output rgb_led0_r,
    output rgb_led0_g,
    output rgb_led0_b
);

    wire [31:0] program_memory_value, memory_address;
    reg [31:0] memory_value, program_counter;
    wire [2:0] memory_write_sections;

    reg [7:0] program_memory[PROGRAM_MEMORY_SIZE - 1:0];

    reg led_on = 0;

    core core(clk48, program_counter, program_memory_value, memory_address, memory_value, memory_write_sections);

    initial $readmemh("target/memory.hex", program_memory);

    assign rgb_led0_r = ~led_on;
    assign rgb_led0_g = ~led_on;
    assign rgb_led0_b = ~led_on;

    assign program_memory_value = { program_memory[program_counter + 3], program_memory[program_counter + 2], program_memory[program_counter + 1], program_memory[program_counter] };

    always @(posedge clk48) begin
        if (memory_write_sections != 0) begin
            led_on = memory_value != 0;
        end
    end

    /*
    always @(posedge clock) begin
        if (memory_write_sections[0]) begin
            memory[memory_address] = memory_value[7:0];
        end
        if (memory_write_sections[1]) begin
            memory[memory_address + 1] = memory_value[15:8];
        end
        if (memory_write_sections[2]) begin
            memory[memory_address + 2] = memory_value[23:16];
            memory[memory_address + 3] = memory_value[31:24];
        end
        if (memory_write_sections == 0) begin
            memory_value = { memory[memory_address + 3], memory[memory_address + 2], memory[memory_address + 1], memory[memory_address] };
        end
    end
    */

endmodule
