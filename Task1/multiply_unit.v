`timescale 1ns/1ps
// `define K 3   //Size of Kernel 
// `define N 2   //Size of input
// `define PIXEL_WIDTH 8   //Width of pixel (8 bit integer)


module multiply_unit #(
    parameter K = 3,        // Kernel size
    parameter ILEN = 8,     // 8 bit integer input
    parameter OLEN = 16     // 8 bit integer product
    ) (
    // Inputs
    input wire [ILEN-1:0] input_pix,    // single input pixel
    input wire [ILEN-1:0] kernel [0:K*K-1], // 1D kernel weights
    // Outputs
    output wire [OLEN-1:0] prod [0:K*K-1] // output 8 bit array of  products
    );
    // generate block instantiates K*K multipliers.
    // Each multiplier computes the product of the input pixel and the corresponding weight.
    genvar i;
    generate
        for (i = 0; i < K * K; i = i + 1) begin : multiplier_instance
            // multiplication of i-th weight (combinational) and assign product to the correct index of output vector
            assign prod[i] = input_pix * kernel[i];
        end
    endgenerate
endmodule
