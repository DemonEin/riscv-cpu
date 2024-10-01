localparam PROGRAM_MEMORY_SIZE = 1000;

module tb_core;
    reg clock;

    wire [31:0] program_memory_value, memory_address;
    reg [31:0] memory_value, program_counter;
    wire [2:0] memory_write_sections;

    reg [7:0] program_memory[PROGRAM_MEMORY_SIZE - 1:0];
    reg [7:0] memory[];

    reg file;

    core core(clock, program_counter, program_memory_value, memory_address, memory_value, memory_write_sections);

    always #1 clock = ~clock;

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

    assign program_memory_value = { program_memory[program_counter + 3], program_memory[program_counter + 2], program_memory[program_counter + 1], program_memory[program_counter] };

    initial begin
        reg [31:0] memory_image_file;
        reg [31:0] read_result;
        memory_image_file = $fopen("memory_image", "r");
        if (memory_image_file == 0) begin
            $display("could not open memory image file");
            $stop;
        end
        read_result = $fread(program_memory, memory_image_file);
        if (read_result == 0) begin
            $display("could not read memory image file");
            $stop;
        end
        if (read_result == PROGRAM_MEMORY_SIZE) begin
            // BUG: this can be hit when there is exactly enough memory to fit
            // the memory image, but it's close enough
            $display("memory image too big to fit in program memory");
            $stop;
        end
    end
endmodule
