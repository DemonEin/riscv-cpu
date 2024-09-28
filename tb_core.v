module tb_core;
    reg clock;

    wire [31:0] program_memory_value, memory_address;
    reg [31:0] memory_value, program_counter;
    wire [2:0] memory_write_sections;

    reg [7:0] program_memory[1000:0], memory[];

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
        $readmemh("dump.o", program_memory);
        // $monitor("%0h", memory_address);
        $monitor("%0h", program_counter);
        // file = $fopen("test.o", "w");
        #100
        // #100 $display(memory[0]);
        $finish;
    end
endmodule
