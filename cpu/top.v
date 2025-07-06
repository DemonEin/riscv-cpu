localparam MEMORY_SIZE = 32'h10000; // in bytes

localparam MEMORY_ADDRESS_TOP_INDEX = $clog2(MEMORY_SIZE) - 1;

localparam ADDRESS_MTIME = 32'h80000000;
localparam ADDRESS_MTIMEH = ADDRESS_MTIME + 4;
localparam ADDRESS_MTIMECMP = ADDRESS_MTIMEH + 4;
localparam ADDRESS_MTIMECMPH = ADDRESS_MTIMECMP + 4;
localparam ADDRESS_LED = 32'h80000010;
localparam ADDRESS_USB_CONTROL = 32'h80000014;
localparam ADDRESS_USB_DEVICE_ADDRESS = 32'h80000018;
localparam ADDRESS_USB_DATA_BUFFER = 32'hc0000000;

// this would only need to be 1023 bytes to contain the maximum size data
// payload but this way it makes only full memory words
localparam USB_DATA_BUFFER_SIZE = 1024; // in bytes

module top(
    input clk48,
    input usr_btn,
    inout usb_d_p,
    inout usb_d_n,

    output usb_pullup,
    output rgb_led0_r = ~led_on,
    output rgb_led0_g = ~led_on,
    output rgb_led0_b = ~led_on,

    output gpio_0,
    output gpio_1,
    output gpio_5,
    output gpio_6,
    output gpio_9,
    output gpio_10,
    output gpio_11,
    output gpio_12,
    output gpio_13,

    output rst_n
);
    // TODO usb does not work correctly without these but I don't know why,
    // see if and how these can be removed although they are good for debugging
    assign gpio_10 = usb_d_p;
    assign gpio_11 = usb_d_n;

    // wires for module output
    wire [31:0] memory_address,
        unshifted_memory_write_value,
        usb_module_usb_data_buffer_write_value,
        next_program_counter;
    wire [2:0] unshifted_memory_write_sections;
    wire [7:0] usb_data_buffer_address;
    wire write_to_usb_data_buffer;
    wire handled_usb_packet;
    wire got_usb_packet;
    wire [15:0] usb_usb_control;

    core core(clk24, next_program_counter, program_memory_value, memory_address, unshifted_memory_write_value, unshifted_memory_write_sections, memory_read_value, usb_packet_ready, handled_usb_packet, mip_mtip);
    usb usb(
        clk48,
        usb_d_p,
        usb_d_n,
        usb_pullup,
        got_usb_packet,
        usb_data_buffer_address,
        usb_data_buffer_read_value,
        usb_module_usb_data_buffer_write_value,
        write_to_usb_data_buffer,
        usb_packet_ready,
        usb_device_address[6:0],
        usb_control,
        usb_usb_control
    );

    // continuously assigned wires and wire-like regs
    reg [3:0] usb_data_buffer_write_sections;
    wire [3:0] memory_write_sections = { {2{unshifted_memory_write_sections[2]}}, unshifted_memory_write_sections[1:0] } << memory_address[1:0];

    reg [31:0] unshifted_memory_read_value;
    always @* begin
        if (read_usb_data_buffer) begin
            unshifted_memory_read_value = usb_data_buffer_read_value;
        end else if (read_memory_mapped_register) begin
            unshifted_memory_read_value = memory_mapped_register_read_value;
        end else begin
            unshifted_memory_read_value = block_ram_read_value;
        end

        if (usb_packet_ready) begin
            // core owns the usb data buffer
            usb_data_buffer_write_sections = addressing_usb_data_buffer ? memory_write_sections : 0;
        end else begin
            // usb module owns the usb data buffer
            usb_data_buffer_write_sections = write_to_usb_data_buffer ? 4'b1111 : 0;
        end
    end

    // these shifts work due to requiring natural alignment of memory accesses
    wire [31:0] memory_read_value = unshifted_memory_read_value >> (pending_read_shift * 8);
    wire [31:0] memory_write_value = unshifted_memory_write_value << (memory_address[1:0] * 8);
    wire [31:0] usb_data_buffer_write_value = addressing_usb_data_buffer ? memory_write_value : usb_module_usb_data_buffer_write_value;

    wire addressing_usb_data_buffer = memory_address >= ADDRESS_USB_DATA_BUFFER && memory_address < (ADDRESS_USB_DATA_BUFFER + USB_DATA_BUFFER_SIZE);
    // needed because of parsing errors that happen only in yosys when I do
    // either of these inline
    wire [31:0] usb_address_base = (memory_address - ADDRESS_USB_DATA_BUFFER);
    wire [7:0] usb_address = addressing_usb_data_buffer ? usb_address_base[9:2] : usb_data_buffer_address;

    wire mip_mtip = mtime >= mtimecmp;

    // stateful regs written in the following block
    (* ram_style = "block" *)
    reg [31:0] memory[MEMORY_SIZE / 4 - 1:0];
    initial $readmemh(`MEMORY_FILE, memory);

    reg [31:0] program_memory_value,
        block_ram_read_value,
        memory_mapped_register_read_value;
    reg [63:0] mtime, mtimecmp;
    reg [1:0] pending_read_shift;
    reg led_on = 0;
    reg read_memory_mapped_register;
    reg read_usb_data_buffer;
    reg [31:0] usb_data_buffer_read_value;

    always @(posedge clk24) begin
        program_memory_value <= memory[next_program_counter[MEMORY_ADDRESS_TOP_INDEX:2]];
        // needs to be shifted for non-32 bit aligned reads, but that can't be
        // done in this block because the synthesizer has trouble with it
        block_ram_read_value <= memory[memory_address[MEMORY_ADDRESS_TOP_INDEX:2]];
        usb_data_buffer_read_value <= usb_data_buffer[usb_packet_ready
            ? memory_address[9:2]
            : usb_data_buffer_address
        ];

        read_usb_data_buffer <= 0;
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
            ADDRESS_LED[31:2]: begin
                memory_mapped_register_read_value <= { 31'b0, led_on };
                read_memory_mapped_register <= 1;
            end
            // TODO properly support non-word sized memory-mapped registers
            ADDRESS_USB_CONTROL[31:2]: begin
                memory_mapped_register_read_value <= { 16'bx, usb_control };
                read_memory_mapped_register <= 1;
            end
            ADDRESS_USB_DEVICE_ADDRESS[31:2]: begin
                memory_mapped_register_read_value <= { 24'bx, usb_device_address };
                read_memory_mapped_register <= 1;
            end
            default: begin
                memory_mapped_register_read_value <= 32'bx;
                read_memory_mapped_register <= 0;

                if (addressing_usb_data_buffer) begin
                    read_usb_data_buffer <= 1;
                end
            end
        endcase
        pending_read_shift <= memory_address[1:0];

        if (memory_address < MEMORY_SIZE) begin
            if (memory_write_sections[0]) begin
                memory[memory_address[MEMORY_ADDRESS_TOP_INDEX:2]][7:0] <= memory_write_value[7:0];
            end
            if (memory_write_sections[1]) begin
                memory[memory_address[MEMORY_ADDRESS_TOP_INDEX:2]][15:8] <= memory_write_value[15:8];
            end
            if (memory_write_sections[2]) begin
                memory[memory_address[MEMORY_ADDRESS_TOP_INDEX:2]][23:16] <= memory_write_value[23:16];
            end
            if (memory_write_sections[3]) begin
                memory[memory_address[MEMORY_ADDRESS_TOP_INDEX:2]][31:24] <= memory_write_value[31:24];
            end
        end

        if (usb_data_buffer_write_sections[0]) begin
            usb_data_buffer[usb_address][7:0] <= usb_data_buffer_write_value[7:0];
        end
        if (usb_data_buffer_write_sections[1]) begin
            usb_data_buffer[usb_address][15:8] <= usb_data_buffer_write_value[15:8];
        end
        if (usb_data_buffer_write_sections[2]) begin
            usb_data_buffer[usb_address][23:16] <= usb_data_buffer_write_value[23:16];
        end
        if (usb_data_buffer_write_sections[3]) begin
            usb_data_buffer[usb_address][31:24] <= usb_data_buffer_write_value[31:24];
        end

        if (usb_packet_ready) begin
            if (memory_address[31:2] == ADDRESS_USB_CONTROL[31:2] && memory_write_sections[1:0] != 0) begin
                usb_packet_ready <= 0;

                if (memory_write_sections[0]) begin
                    usb_control[7:0] <= memory_write_value[7:0];
                end
                if (memory_write_sections[1]) begin
                    usb_control[15:8] <= memory_write_value[15:8];
                end
            end
        end else begin
            if (got_usb_packet) begin
                usb_packet_ready <= 1;
                usb_control[15:0] <= usb_usb_control;
            end
        end

        case (memory_address[31:2])
            ADDRESS_MTIME[31:2]: begin
                if (memory_write_sections[0]) begin
                    mtime[7:0] <= memory_write_value[7:0];
                end
                if (memory_write_sections[1]) begin
                    mtime[15:8] <= memory_write_value[15:8];
                end
                if (memory_write_sections[2]) begin
                    mtime[23:16] <= memory_write_value[23:16];
                end
                if (memory_write_sections[3]) begin
                    mtime[31:24] <= memory_write_value[31:24];
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
                    mtime[55:48] <= memory_write_value[23:16];
                end
                if (memory_write_sections[3]) begin
                    mtime[63:56] <= memory_write_value[31:24];
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
                    mtimecmp[23:16] <= memory_write_value[23:16];
                end
                if (memory_write_sections[3]) begin
                    mtimecmp[31:24] <= memory_write_value[31:24];
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
                    mtimecmp[55:48] <= memory_write_value[23:16];
                end
                if (memory_write_sections[3]) begin
                    mtimecmp[63:56] <= memory_write_value[31:24];
                end
            end
        endcase

        if (memory_address == ADDRESS_LED && memory_write_sections[0]) begin
            led_on <= memory_write_value[0];
        end

        if (memory_address[31:2] == ADDRESS_USB_DEVICE_ADDRESS[31:2] && memory_write_sections[0]) begin
            usb_device_address <= memory_write_value[7:0];
        end
    end

    // stateful regs written in the following block
    reg [31:0] usb_data_buffer[USB_DATA_BUFFER_SIZE / 4];
    reg usb_packet_ready = 0; // 1 means the core owns the buffer, 0 means the usb
                              // module owns the buffer
    reg [15:0] usb_control;
    reg [7:0] usb_device_address = 0;

    // nextpnr reports this as a 12 mhz clock; this is a bug in nextpnr,
    // I confirmed on hardware that the observed clock is 24 mhz
    reg clk24 = 0;

    always @(posedge clk48) begin
        clk24 <= ~clk24;
    end

    // make the on-board button enter the bootloader
    reg reset = 1;
    always @(posedge clk48) begin
        reset <= usr_btn;
    end
    assign rst_n = reset;
endmodule
