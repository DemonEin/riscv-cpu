localparam MEMORY_SIZE = 4096;

module top(
    input clk48,

    output rgb_led0_r,
    output rgb_led0_g,
    output rgb_led0_b
);

    // nextpnr reports this as a 12 mhz clock; this is a bug in nextpnr,
    // I confirmed on hardware that the observed clock is 24 mhz
    reg clk24 = 0;

    wire [31:0] memory_address, memory_write_value, memory_read_value, unshifted_memory_write_value;
    reg [31:0] program_memory_value, next_program_counter, unshifted_memory_read_value;
    wire [2:0] memory_write_sections;

    reg [1:0] pending_read_shift;

    (* ram_style = "block" *)
    reg [31:0] memory[MEMORY_SIZE - 1:0];

    reg led_on = 0;

    core core(clk24, next_program_counter, program_memory_value, memory_address, unshifted_memory_write_value, memory_write_sections, memory_read_value);

    initial $readmemh(`MEMORY_FILE, memory);

    assign rgb_led0_r = ~led_on;
    assign rgb_led0_g = ~led_on;
    assign rgb_led0_b = ~led_on;

    always @(posedge clk24) begin
        if (memory_write_sections != 0) begin
            led_on = memory_write_value != 0;
        end
    end

    // these shifts work due to requiring natural alignment of memory accesses
    assign memory_read_value = unshifted_memory_read_value >> (pending_read_shift * 8);
    assign memory_write_value = unshifted_memory_write_value << (memory_address[1:0] * 8);

    always @(posedge clk24) begin
        program_memory_value <= memory[next_program_counter[13:2]];
        // needs to be shifted for non-32 bit aligned reads, but that can't be
        // done in this block because the synthesizer has trouble with it
        unshifted_memory_read_value <= memory[memory_address[13:2]];
        pending_read_shift <= memory_address[1:0];

        if (memory_write_sections[0]) begin
            memory[memory_address][7:0] <= memory_write_value[7:0];
        end
        if (memory_write_sections[1]) begin
            memory[memory_address][15:8] <= memory_write_value[15:8];
        end
        if (memory_write_sections[2]) begin
            memory[memory_address][31:16] <= memory_write_value[31:16];
        end
    end

    always @(posedge clk48) begin
        clk24 = ~clk24;
    end

endmodule
