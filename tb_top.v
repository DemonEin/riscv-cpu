module tb_top;
    
    reg clock = 0;
    always #10.4166667ns clock <= ~clock; // 48 mhz
    wire usb_d_p, usb_d_n, usb_pullup, r, g, b;
    top top(clock, usb_d_p, usb_d_n, usb_pullup, r, g, b);

    initial $monitor(r);
endmodule
