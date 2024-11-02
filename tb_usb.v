
module tb_usb();
    reg clk48, usb_d_p, usb_d_n;
    wire usb_pullup, rgb_led0_r, rgb_led0_g, rgb_led0_b, usr_btn, rst_n, gpio_10, gpio_11, gpio_12, gpio_13;

    always #10.4166667ns clk48 = ~clk48; // 48 mhz

    // k state, diff 0, and idle are usb_d_p = 0, usb_d_n = 1
    // j state and diff 1 are usb_d_p = 1, usb_d_n = 0

    initial begin
        $monitor(usb.state);
        #1ms
        #1ns
        usb_d_p = 0;
        usb_d_n = 0;
        #10ms
        usb_d_p = 0;
        usb_d_n = 1;
        #2ms
        usb_d_p = 1;
        usb_d_n = 0;
        #20.8ns
        usb_d_p = 0;
        usb_d_n = 1;
        #20.8ns
        usb_d_p = 1;
        usb_d_n = 0;
        #20.8ns
        usb_d_p = 0;
        usb_d_n = 1;
        #20.8ns
        usb_d_p = 1;
        usb_d_n = 0;
        #20.8ns
        usb_d_p = 0;
        usb_d_n = 1;
        #20.8ns
        usb_d_p = 1;
        usb_d_n = 0;
        #20.8ns
        usb_d_p = 1;
        usb_d_n = 0;
        #2ns
        $finish();
    end




    usb usb(clk48, usb_d_p, usb_d_n, usb_pullup, rgb_led0_r, rgb_led0_g, rgb_led0_b, usr_btn, rst_n, gpio_10, gpio_11, gpio_12, gpio_13);
endmodule 
