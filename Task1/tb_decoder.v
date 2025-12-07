`timescale 1ns/1ps
`include "decoder.v"
module tb_decoder(); // This module is a testbench for the decoder module
  // Parameters
  localparam N=2;
  localparam K=3;
  localparam PIXEL_WIDTH=8;
  localparam STRIDE=2;
  localparam ACCUM_WIDTH = PIXEL_WIDTH*2 + $clog2(K*K);
  localparam GRID_SIZE = N * K * N * K; // Total output size

  // Clock
  reg clk;
  always #10 clk = ~clk; // 50 MHz clock
  // Reset
  reg rst;
  // Control signals
  reg enable;
  reg load_kernel;
  reg load_input;
  // Input signals
  wire [PIXEL_WIDTH-1:0] image_input; // Input image
  wire [PIXEL_WIDTH-1:0] kernel_input; // Kernel weights
  // Output signals & control
  wire done_wire; // Wire to connect to decoder output
  reg  done_reg;  // Reg for use in procedural blocks
  wire [ACCUM_WIDTH-1:0] image_output [0:GRID_SIZE-1]; // Output feature map
  // Internal signals
  reg [PIXEL_WIDTH*2-1:0] prod [0:K*K-1]; // products from multiply unit

  assign done_wire = done_reg; // Connect reg to wire

  // Instantiate the decoder module
  decoder #(
    .N(N),
    .K(K),
    .ILEN(PIXEL_WIDTH*2),
    .OLEN(ACCUM_WIDTH),
    .stride(STRIDE)
  ) uut (
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .state(2'b0),
    .multiplied_image(prod),
    .decoded_image(image_output), // This connection seems incorrect based on decoder.v
    .decoding_complete(done_wire)
  );
  always @(done_wire) done_reg <= done_wire;

  // Testbench signals
  initial begin
    integer i;
    // Initialize signals
    clk = 0;
    rst = 1;
    enable = 0;
    load_kernel = 0;
    load_input = 0;
    // Wait for a few clock cycles
    #20;
    // Release reset
    rst = 0;
    // Make an example prod
    for (i = 0; i < K * K; i = i + 1) begin
      prod[i] = {PIXEL_WIDTH*2{1'b1}}; // Example product values
    end
    // Enable the decoder
    enable = 1;
    // Wait for a few clock cycles
    #20;
    // Disable the decoder
    enable = 0; 
    // Wait for done signal
    wait(done_wire);
    
    // Check output
    $display("Decoding completed.");
    $display("Output:");
    for (i = 0; i < GRID_SIZE; i = i + 1) begin
      $display("image_output[%0d] = %h", i, image_output[i]);
    end
    // VCD dump
    $dumpfile("tb_decoder.vcd");
    $dumpvars(0, tb_decoder);
    
    // Finish simulation
    #10 $finish;
  end
endmodule