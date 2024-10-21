localparam MEMORY_SIZE = 32'h1000;

module top(
    input clk48,

    output rgb_led0_r,
    output rgb_led0_g,
    output rgb_led0_b
);

    // nextpnr reports this as a 12 mhz clock; this is a bug in nextpnr,
    // I confirmed on hardware that the observed clock is 24 mhz
    reg clk24 = 0;

    wire [31:0] memory_address;
    reg [31:0] program_memory_value, memory_value, next_program_counter;
    wire [2:0] memory_write_sections;

    (* ram_style = "block" *)
    reg [7:0] memory[MEMORY_SIZE - 1:0];

    reg led_on = 0;

    core core(clk24, next_program_counter, program_memory_value, memory_address, memory_value, memory_write_sections);

    initial $readmemh(`MEMORY_FILE, memory);

    assign rgb_led0_r = ~led_on;
    assign rgb_led0_g = ~led_on;
    assign rgb_led0_b = ~led_on;

    always @(posedge clk24) begin
        if (memory_write_sections != 0) begin
            led_on = memory_value != 0;
        end
    end

    always @(posedge clk24) begin
        program_memory_value = { memory[next_program_counter + 3], memory[next_program_counter + 2], memory[next_program_counter + 1], memory[next_program_counter] };
    end

    always @(posedge clk48) begin
        clk24 = ~clk24;
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
