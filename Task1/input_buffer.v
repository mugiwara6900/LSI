`timescale 1ns/1ps

module input_buffer #(
  parameter DATA_WIDTH = 8,      // Pixel bit width (8-bit for your GAN)
  parameter DEPTH = 4,            // Buffer size (N*N=4 for N=2)
  parameter ADDR_WIDTH = $clog2(DEPTH)  // Counter width (2 bits for 4 locations)
)(
  input wire clk,
  input wire rst,
  input wire load_en,                     // VALID signal (master says "data ready")
  input wire [DATA_WIDTH-1:0] data_in,    // Data bus
   input wire clear,                      // explicit clear signal from FSM
  output reg ready,                       // READY signal (slave says "I can accept")
  output reg loaded,                      // Status: all DEPTH pixels received
  output wire [DATA_WIDTH-1:0] buffer_out [0:DEPTH-1]  // Parallel access to stored data
);
  reg [DATA_WIDTH-1:0] buffer [0:DEPTH-1];  //RAM array holding pixels
  reg [ADDR_WIDTH:0] count;                 //Write pointer (extra bit to reach DEPTH)

  always @(posedge clk) begin
    if (rst) begin
      count  <= 0;
      loaded <= 1'b0;
      ready  <= 1'b1;  // Start ready to accept data
      buffer <= '{default: '0};
    end else if (clear) begin
        count  <= 0;
        loaded <= 1'b0;
        ready  <= 1'b1;  // Re-arm for next batch
        buffer <= '{default: '0};
    end else if (load_en && ready) begin
      buffer[count] <= data_in;  // Store incoming pixel at current write position
      if (count == DEPTH - 1) begin
        loaded <= 1'b1;  // Signal: "All pixels received, ready for processing"
        ready  <= 1'b0;  // Backpressure: stop accepting more data
      end else begin
        count <= count + 1;
      end
    end
  end
  // Expose all stored pixels simultaneously
  genvar i;
  generate
    for (i = 0; i < DEPTH; i = i + 1) begin : output_map
      assign buffer_out[i] = buffer[i];  // Expose all stored pixels simultaneously
    end
  endgenerate
endmodule