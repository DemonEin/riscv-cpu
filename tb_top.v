module tb_top;
    
    reg clock = 0;
    always #20.833ns clock = ~clock; // 48 mhz
    wire r, g, b;
    top top(clock, r, g, b);

    initial $monitor(r);
endmodule
