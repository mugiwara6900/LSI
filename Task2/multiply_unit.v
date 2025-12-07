module multiply_unit #(
    parameter pixel_bits = 8
)(
    input wire [pixel_bits-1:0] pixel,
    input wire [pixel_bits-1:0] kernel_weight,
    output wire [pixel_bits*2 - 1:0] multiplied_output
);
    assign multiplied_output = (pixel * kernel_weight);
endmodule