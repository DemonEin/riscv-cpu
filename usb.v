
localparam STATE_POWERED = 0;
localparam STATE_RESET = 1;
localparam STATE_READING = 2;
localparam STATE_READ_COMPLETE = 3;
localparam STATE_DONE = 4;
localparam STATE_IGNORE_PACKET = 5;

localparam EOP_NEED_SE0_0 = 0;
localparam EOP_NEED_SE0_1 = 1;
localparam EOP_NEED_J = 2;

module usb(clk48, usb_d_p, usb_d_n, usb_pullup, rgb_led0_r, rgb_led0_g, rgb_led0_b, usr_btn, rst_n, gpio_10, gpio_11, gpio_12, gpio_13);


    reg [2:0] test_counter;

    always @(posedge clk48) begin
        test_counter <= test_counter + 1;
    end


    

    reg [3:0] state = STATE_POWERED;
    // 0 means pressed
    input usr_btn;
    input clk48;
    output gpio_10, gpio_11;
    output reg gpio_12, gpio_13;

    initial gpio_12 = 0;
    initial gpio_13 = 0;
    // assign gpio_10 = debug_bits[0];
    // assign gpio_10 = test_counter[2];
    assign gpio_10 = usb_d_p;
    // assign gpio_11 = debug_bits[1];
    assign gpio_11 = usb_d_n;
    // assign gpio_12 = debug_bits[2];
    // assign gpio_13 = debug_bits[3];
    // for these, 1 means high voltage
    inout usb_d_p, usb_d_n;

    output usb_pullup, rgb_led0_r, rgb_led0_g, rgb_led0_b, rst_n;

    assign usb_pullup = 1;

    reg [2:0] eop_state;

    wire differential_1;
    wire differential_0;
    wire data_j;
    wire data_k;
    wire idle;
    wire se0;
    wire data_ready;
    wire data;

    reg led_on = 0;
    reg eight_ms_elapsed = 0;
    reg se0_at_time;
    reg got_val = 0;

    reg debounce_complete;

    reg fail = 0;

    reg [2:0] expected_sync_bit;

    reg [31:0] debounce_counter = 0;
    reg [31:0] counter = 0;

    reg [1:0] data_ready_counter = 0;

    reg previous_data;

    // needs to hold one reset time, TODO could be smaller
    reg [31:0] reset_counter = 0;

    reg [7:0] bits_to_read;
    reg [31:0] read_bits;


    reg [3:0] debug_bits;

    assign rgb_led0_r = ~led_on;
    assign rgb_led0_g = ~led_on;
    assign rgb_led0_b = ~led_on;

    assign differential_1 = usb_d_p && !usb_d_n;
    assign differential_0 = !usb_d_p && usb_d_n;
    assign se0 = !usb_d_p && !usb_d_n;
    assign data_j = differential_1;
    assign data_k = differential_0;
    assign idle = usb_d_p && !usb_d_n; // equivalent to differential_1 and data_j

    assign data = data_j;

    assign data_ready = data_ready_counter == 3;

    

    always @(posedge clk48) begin
        if (se0) begin
            reset_counter <= reset_counter + 1;
        end else begin
            reset_counter <= 0;
        end

        /*
        // TODO actually only needs to be 2.5 microseconds
        if (reset_counter > 48000 * 9) begin
            state <= STATE_RESET;
        end
        */

        case (state)
            STATE_POWERED: begin
                if (reset_counter > 48000 * 9) begin
                    gpio_12 = 0;
                    gpio_13 = 1;
                    state <= STATE_RESET;
                end
            end

        // TODO actually only needs to be 2.5 microseconds
            STATE_RESET: begin
                if (data_k) begin
                    gpio_13 = 0;
                    state <= STATE_READING;
                    previous_data = 1;
                    bits_to_read = 8;
                    data_ready_counter <= 2;
                end
            end
            STATE_READING: begin
                data_ready_counter <= data_ready_counter + 1;
                if (data_ready) begin
                    read_bits = read_bits >> 1;
                    read_bits[7] = !(data ^ previous_data);
                    // read_bits[7] = data;
                    gpio_12 = !(data ^ previous_data);
                    previous_data <= data;
                    bits_to_read = bits_to_read - 1;
                end
                if (bits_to_read == 0) begin
                    state <= STATE_READ_COMPLETE;
                end
            end
            STATE_READ_COMPLETE: begin
                // if (read_bits[7:0] == 8'b00000001 && read_bits[11:8] == ~read_bits[15:12]) begin
                // if (read_bits[7:0] == 8'b00000001) begin
                if (read_bits[7:0] == 8'b10000000) begin
                    led_on <= 1;
                    // debug_bits <= read_bits[11:8];
                    state <= STATE_DONE;
                end else begin
                    state <= STATE_IGNORE_PACKET;
                    eop_state <= EOP_NEED_SE0_0;
                end
            end
            STATE_IGNORE_PACKET: begin
                case (eop_state)
                    EOP_NEED_SE0_0: begin
                        if (se0) begin
                            eop_state <= EOP_NEED_SE0_1;
                        end
                    end
                    EOP_NEED_SE0_1: begin
                        if (se0) begin
                            eop_state <= EOP_NEED_J;
                        end else begin
                            eop_state <= EOP_NEED_SE0_0;
                        end
                    end
                    EOP_NEED_J: begin
                        if (data_j) begin
                            // state <= STATE_RESET;
                            state <= STATE_DONE;
                        end else begin
                            eop_state <= EOP_NEED_SE0_0;
                        end
                    end
                endcase
            end



        endcase
    end

    // reset on button press
    reg reset_sr = 1'b1;
    always @(posedge clk48) begin
        reset_sr <= {usr_btn};
    end
    assign rst_n = reset_sr;
    
endmodule
