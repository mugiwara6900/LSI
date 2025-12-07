`timescale 1ns / 1ps
`include "input_buffer.v"
`include "mux.v"
`include "multiply_unit.v"
`include "decoder.v"
`include "accumulator.v"

module deconv2D #(
  parameter N = 2,
  parameter K = 3,
  parameter PIXEL_WIDTH = 8,
  parameter STRIDE = 2,
  parameter ACCUM_WIDTH = PIXEL_WIDTH*2 + $clog2(N*N)
)(
  input wire clk,         // main clock
  input wire rst,         // reset
  input wire enable,      // process when high pulse
  input wire load_kernel, // signal to load kernel weights
  input wire load_input,  // signal to load input image
  input wire [PIXEL_WIDTH-1:0] image_input,   // Input image
  input wire [PIXEL_WIDTH-1:0] kernel_input,  // Kernel weights

  output wire input_ready,   // Input Backpressure signal
  output wire kernel_ready,  // Kernel Backpressure signal
  output reg done, // high indicates completion
  output wire [PIXEL_WIDTH-1:0] image_output [0:N*K*N*K-1] // Output feature map
);
  // Internal signals and registers
  reg [$clog2(N*N)-1:0] input_select;      // select signal for input multiplexer
  wire [PIXEL_WIDTH-1:0] image [0:N*N-1];  // input image
  reg [PIXEL_WIDTH-1:0] input_pix;         // current input pixel to be processed
  wire [PIXEL_WIDTH*2-1:0] prod [0:K*K-1]; // products from multiply unit
  wire [PIXEL_WIDTH*2-1:0] decoded_image [0:N*K*N*K-1]; // decoded pixel products
  wire [PIXEL_WIDTH-1:0] kernel_weights [0:K*K-1];      // kernel weights from buffer
  wire [ACCUM_WIDTH-1:0] accum_out [0:N*K*N*K-1];       // output from accumulator grid
  wire kernel_loaded; // high when kernel is loaded
  wire input_loaded;  // high when input image is loaded
  reg accum_enable;   // enable signal for accumulator grid
  reg decoder_enable; // enable signal for decoder
  wire decode_done;   // high when decoding of pixel products is complete
  reg [1:0] deconv_state; // Main deconv2D FSM state
  reg clear_buffers;  // clear signal for buffers
  localparam IDLE = 2'b00,
             RECIEVE = 2'b01,
             MULTIPLY = 2'b10,
             ACCUMULATE = 2'b11;

  // Module Instantiations
  input_buffer #(.DATA_WIDTH(PIXEL_WIDTH), .DEPTH(N*N)) img_buf ( // image buffer
    .clk(clk), .rst(rst),
    .load_en(load_input),
    .data_in(image_input),
    .clear(clear_buffers),
    .ready(input_ready),       
    .loaded(input_loaded),     
    .buffer_out(image)         // All N² pixels available in parallel
  );
  input_buffer #(.DATA_WIDTH(PIXEL_WIDTH), .DEPTH(K*K)) kern_buf ( // kernel buffer
    .clk(clk), .rst(rst),
    .load_en(load_kernel),
    .data_in(kernel_input),
    .clear(clear_buffers),
    .ready(kernel_ready),
    .loaded(kernel_loaded),
    .buffer_out(kernel_weights) // All K² pixels available in parallel
  );
  mux #(
  .N(N),
  .WIDTH(PIXEL_WIDTH)  
  ) input_mux (
    .select(input_select),
    .in_line(image),
    .out_line(input_pix)
  );
  multiply_unit #( // multiply unit
  .K(K),
  .ILEN(PIXEL_WIDTH),
  .OLEN(PIXEL_WIDTH*2)
) mult_unit (
  .input_pix(input_pix),
  .kernel(kernel_weights),
  .prod(prod)
);
  accumulator #( // accumulator grid
    .N(N),
    .K(K),
    .ILEN(PIXEL_WIDTH*2),
    .GRID_SIZE(N*K),
    .ACCUM_WIDTH(ACCUM_WIDTH)
  ) accum_grid (
    .clk(clk),
    .rst(rst),
    .enable(accum_enable),
    .accum_in(decoded_image),
    .accum_grid(accum_out)
  );
  decoder #( 
    .N(N), .K(K), .ILEN(PIXEL_WIDTH*2), .OLEN(PIXEL_WIDTH*2), 
    .stride(STRIDE)
  ) pix_decoder (
    .clk(clk),
    .rst(rst),
    .enable(decoder_enable),     
    .state(input_select),    
    .multiplied_image(prod),
    .decoded_image(decoded_image),
    .decoding_complete(decode_done)
  );

  // FSM and control logic
  always @(posedge clk) begin
    if (rst) begin
      deconv_state <= IDLE;
      done <= 1'b0;
      accum_enable <= 1'b0;
      decoder_enable <= 1'b0;
      input_select <= 0;
      clear_buffers <= 1'b0; // Clear buffers on reset
    end else begin
      case (deconv_state)
        IDLE: begin // idle state
          clear_buffers <= 1'b0;
            accum_enable <= 1'b0;
            decoder_enable <= 1'b0;
            done <= 1'b0;
          if (enable) begin
            deconv_state <= RECIEVE;
            input_select <= 0;
          end
        end
        RECIEVE: begin // receive input state
          clear_buffers <= 1'b0; // Clear buffers to prepare for new data
          decoder_enable <= 1'b0;
          accum_enable <= 1'b0;
          // Wait for both input and kernel to be loaded
          if (input_loaded && kernel_loaded) begin
            deconv_state <= MULTIPLY;
            // Buffer handles loading and ready signals
            input_select <=0;
          end
        end
        MULTIPLY: begin // multiply
          // Check if master is trying to send new data
          if (load_input || load_kernel) begin
            // New data arriving; abort current operation and reload
            deconv_state  <= RECIEVE;
            accum_enable  <= 1'b0;
            input_select <= 0;
          end else begin 
            decoder_enable <= 1'b1; // enable decoder
            if (decode_done) begin  
              // give the multiplied grid to accumulator
              accum_enable <= 1'b1;
              decoder_enable <= 1'b0;
              deconv_state <= ACCUMULATE;
              // input_select will be incremented in ACCUMULATE state
            end
          end
        end
        ACCUMULATE: begin // accumulate
          if (load_input || load_kernel) begin
            // New data arriving; abort current operation and reload
            deconv_state  <= RECIEVE;
            accum_enable  <= 1'b0;
            input_select <= 0;
          end else begin
            if (input_select < N*N - 1) begin // more inputs to process
              input_select <= input_select + 1;
              deconv_state <= MULTIPLY; 
            end else begin
              // All inputs processed, go back to IDLE
              deconv_state <= IDLE;
              input_select <= 0;
              decoder_enable <= 1'b0;
              done <= 1'b1;
            end
            accum_enable <= 1'b0;
          end
        end
        default: begin
          // Return to IDLE on any illegal state
          deconv_state <= IDLE;
          input_select <= 0;
          accum_enable <= 1'b0;
          decoder_enable <= 1'b0;
          clear_buffers <= 1'b0;
          done <= 1'b0;
        end
      endcase
    end
  end

  genvar g;
  generate
    for (g = 0; g < N*K*N*K; g = g + 1) begin : truncate
      // Truncate to PIXEL_WIDTH (discard lower bits or round)
      assign image_output[g] = accum_out[g][PIXEL_WIDTH-1:0];
    end
  endgenerate
endmodule
