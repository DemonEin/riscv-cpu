localparam MEMORY_SIZE = 4096;

localparam ADDRESS_MTIME = 32'h80000000;
localparam ADDRESS_MTIMEH = ADDRESS_MTIME + 4;
localparam ADDRESS_MTIMECMP = ADDRESS_MTIMEH + 4;
localparam ADDRESS_MTIMECMPH = ADDRESS_MTIMECMP + 4;
localparam ADDRESS_LED = ADDRESS_MTIMECMPH + 4;
localparam ADDRESS_USB_PACKET_BUFFER = 32'hc0000000;

localparam USB_PACKET_BUFFER_SIZE = 1024; // in bytes

module top(
    input clk48,
    inout usb_d_p,
    inout usb_d_n,

    output usb_pullup,
    output rgb_led0_r,
    output rgb_led0_g,
    output rgb_led0_b
);

    // nextpnr reports this as a 12 mhz clock; this is a bug in nextpnr,
    // I confirmed on hardware that the observed clock is 24 mhz
    reg clk24 = 0;

    wire [31:0] memory_address, memory_write_value, memory_read_value, unshifted_memory_write_value, unshifted_memory_read_value;
    reg [31:0] program_memory_value, next_program_counter, block_ram_read_value, memory_mapped_register_read_value;
    wire [2:0] memory_write_sections, block_ram_write_sections;
    reg read_memory_mapped_register;

    reg [63:0] mtime, mtimecmp;

    reg [1:0] pending_read_shift;

    (* ram_style = "block" *)
    reg [31:0] memory[MEMORY_SIZE - 1:0];

    reg [31:0] usb_packet_buffer[USB_PACKET_BUFFER_SIZE / 4];

    // setting this to 1 keeps it on
    // reg led_on = 0;
    reg red = 0;
    reg green = 0;
    reg blue = 0;

    // needed because of parsing errors that happen only in yosys when I do
    // either of these inline
    wire [31:0] usb_address_base = (memory_address - ADDRESS_USB_PACKET_BUFFER);
    wire [7:0] usb_address = usb_address_base[9:2];

    wire usb_packet_ready;
    wire addressing_usb_packet_buffer = memory_address >= ADDRESS_USB_PACKET_BUFFER && memory_address < (ADDRESS_USB_PACKET_BUFFER + USB_PACKET_BUFFER_SIZE);

    core core(clk24, next_program_counter, program_memory_value, memory_address, unshifted_memory_write_value, memory_write_sections, memory_read_value);
    usb usb(clk48, usb_d_p, usb_d_n, usb_pullup, usb_packet_ready);

    initial $readmemh(`MEMORY_FILE, memory);

    assign block_ram_write_sections = memory_address[31:2] == ADDRESS_MTIME[31:2]
        || memory_address[31:2] == ADDRESS_MTIMEH[31:2]
        || memory_address[31:2] == ADDRESS_MTIMECMP[31:2] 
        || memory_address[31:2] == ADDRESS_MTIMECMPH[31:2] 
        || addressing_usb_packet_buffer ? 0 : memory_write_sections;

    wire [2:0] usb_packet_buffer_write_sections = addressing_usb_packet_buffer ? memory_write_sections : 0;

    assign rgb_led0_r = ~red;
    assign rgb_led0_g = ~green;
    assign rgb_led0_b = ~blue;

    assign unshifted_memory_read_value = read_memory_mapped_register ? memory_mapped_register_read_value : block_ram_read_value;
    // these shifts work due to requiring natural alignment of memory accesses
    assign memory_read_value = unshifted_memory_read_value >> (pending_read_shift * 8);
    assign memory_write_value = unshifted_memory_write_value << (memory_address[1:0] * 8);

    always @(posedge clk24) begin
        // $display("next_program_counter: %h", next_program_counter);
        program_memory_value <= memory[next_program_counter[13:2]];
        // needs to be shifted for non-32 bit aligned reads, but that can't be
        // done in this block because the synthesizer has trouble with it
        block_ram_read_value <= memory[memory_address[13:2]];
        case (memory_address[31:2])
            ADDRESS_MTIME[31:2]: begin
                memory_mapped_register_read_value <= mtime[31:0];
                read_memory_mapped_register <= 1;
            end
            ADDRESS_MTIMEH[31:2]: begin
                memory_mapped_register_read_value <= mtime[63:32];
                read_memory_mapped_register <= 1;
            end
            ADDRESS_MTIMECMP[31:2]: begin
                memory_mapped_register_read_value <= mtimecmp[31:0];
                read_memory_mapped_register <= 1;
            end
            ADDRESS_MTIMECMPH[31:2]: begin
                memory_mapped_register_read_value <= mtimecmp[63:32];
                read_memory_mapped_register <= 1;
            end
            default: begin
                if (addressing_usb_packet_buffer) begin
                    // the usb packet buffer isn't a register but whatever
                    memory_mapped_register_read_value <= usb_packet_buffer[memory_address[9:2]];
                    read_memory_mapped_register <= 1;
                end else begin
                    memory_mapped_register_read_value <= 32'bx;
                    read_memory_mapped_register <= 0;
                end
            end
        endcase
        pending_read_shift <= memory_address[1:0];

        if (block_ram_write_sections[0]) begin
            memory[memory_address[13:2]][7:0] <= memory_write_value[7:0];
        end
        if (block_ram_write_sections[1]) begin
            memory[memory_address[13:2]][15:8] <= memory_write_value[15:8];
        end
        if (block_ram_write_sections[2]) begin
            memory[memory_address[13:2]][31:16] <= memory_write_value[31:16];
        end

        // TODO bug when addressing inner byte?
        case (memory_address[31:2])
            ADDRESS_MTIME[31:2]: begin
                if (memory_write_sections[0]) begin
                    mtime[7:0] <= memory_write_value[7:0];
                end
                if (memory_write_sections[1]) begin
                    mtime[15:8] <= memory_write_value[15:8];
                end
                if (memory_write_sections[2]) begin
                    mtime[31:16] <= memory_write_value[31:16];
                end
            end
            ADDRESS_MTIMEH[31:2]: begin
                if (memory_write_sections[0]) begin
                    mtime[39:32] <= memory_write_value[7:0];
                end
                if (memory_write_sections[1]) begin
                    mtime[47:40] <= memory_write_value[15:8];
                end
                if (memory_write_sections[2]) begin
                    mtime[63:48] <= memory_write_value[31:16];
                end
            end
            default: mtime <= mtime + 1;
        endcase

        case (memory_address[31:2])
            ADDRESS_MTIMECMP[31:2]: begin
                if (memory_write_sections[0]) begin
                    mtimecmp[7:0] <= memory_write_value[7:0];
                end
                if (memory_write_sections[1]) begin
                    mtimecmp[15:8] <= memory_write_value[15:8];
                end
                if (memory_write_sections[2]) begin
                    mtimecmp[31:16] <= memory_write_value[31:16];
                end
            end
            ADDRESS_MTIMECMPH[31:2]: begin
                if (memory_write_sections[0]) begin
                    mtimecmp[39:32] <= memory_write_value[7:0];
                end
                if (memory_write_sections[1]) begin
                    mtimecmp[47:40] <= memory_write_value[15:8];
                end
                if (memory_write_sections[2]) begin
                    mtimecmp[63:48] <= memory_write_value[31:16];
                end
            end
        endcase

        if (next_program_counter < `INITIAL_PROGRAM_COUNTER || next_program_counter > `INITIAL_PROGRAM_COUNTER + 40) begin
            red <= 1;
        end
        
        // if (memory_address[31] == 1) begin
        // if (memory_address[31:2] == ADDRESS_LED[31:2]) begin
          // if (memory_write_sections != 0 && memory_write_value == 0) begin
            // led_on <= memory_write_value[0];
            // led_on <= !memory_write_value[0];
                // led_on <= !led_on;
                // led_on <= !led_on;
            // end
        // end
        //
        // this works
        // if (block_ram_read_value == 32'h80000010) begin
          //   led_on <= 1;
        // end
        if (memory_read_value == 32'h80000010) begin
            green <= 1;
        end
        if (unshifted_memory_write_value == 32'h80000010) begin
            blue <= 1;
        end
        // this works
        //if (memory_address == 32'h80000010) begin
            //led_on <= 1;
        //end
        // if (memory_write_value) begin
            // led_on <= 1;
        // end
    end

    always @(posedge clk48) begin
        if (usb_packet_buffer_write_sections[0]) begin
            usb_packet_buffer[usb_address][7:0] <= memory_write_value[7:0];
        end
        if (usb_packet_buffer_write_sections[1]) begin
            usb_packet_buffer[usb_address][15:8] <= memory_write_value[15:8];
        end
        if (usb_packet_buffer_write_sections[2]) begin
            usb_packet_buffer[usb_address][31:16] <= memory_write_value[31:16];
        end
    end

    always @(posedge clk48) begin
        clk24 <= ~clk24;
    end

endmodule
