module tb_top;
    
    reg clock = 0;
    always #1 clock = ~clock;
    wire r, g, b;
    top top(clock, r, g, b);

    initial $monitor(r);
endmodule
