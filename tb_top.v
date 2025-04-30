module tb_top;
    
    reg clock = 0;
    always #10.4166667ns clock <= ~clock; // 48 mhz
    wire usb_d_p, usb_d_n, usb_pullup, r, g, b, null;
    top top(
        clock,
        1,
        usb_d_p,
        usb_d_n,
        usb_pullup,
        r,
        g,
        b,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null
    );

    initial $monitor(r);
endmodule
