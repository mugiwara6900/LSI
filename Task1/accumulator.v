`timescale 1ns/1ps

// Single accumulator cell
module accumulator_cell #(
    parameter ILEN = 16,
    parameter ACCUM_WIDTH = 20
)(
    input wire clk,
    input wire rst,
    input wire enable,
    input wire [ILEN-1:0] data_in,
    output wire [ACCUM_WIDTH-1:0] data_out
);
    reg [ACCUM_WIDTH-1:0] accum_reg;
    
    always @(posedge clk) begin
        if (rst)
            accum_reg <= 0;
        else if (enable)
            accum_reg <= accum_reg + data_in;
    end
    assign data_out = accum_reg;
endmodule


// This module implements an accumulator for a grid of size N*K.
// It accumulates input values into a grid structure, where each cell in the grid
// corresponds to a position in the output image after deconvolution.
module accumulator #(
    parameter N = 2,
    parameter K = 3,
    parameter ILEN = 16, // width of each input segment
    parameter GRID_SIZE = N*K, // 6x6 grid
    parameter ACCUM_WIDTH = ILEN + $clog2(N*N) // width of running sum
) (
    // Inputs
    input wire clk,
    input wire rst,     // reset
    input wire enable,  // accumulate when high
    input wire [ILEN-1:0] accum_in [0:GRID_SIZE*GRID_SIZE-1], // input to be accumulated
    // Outputs
    output wire [ACCUM_WIDTH-1:0] accum_grid [0:GRID_SIZE*GRID_SIZE-1]
);
  // Instantiate GRID_SIZE x GRID_SIZE accumulators without using cells using generate block
  genvar i;
  generate
    for (i = 0; i < GRID_SIZE*GRID_SIZE; i = i + 1) begin : accum_cells
        accumulator_cell #(
                .ILEN(ILEN),
                .ACCUM_WIDTH(ACCUM_WIDTH)
            ) accum_cell (
                .clk(clk),
                .rst(rst),
                .enable(enable),
                .data_in(accum_in[i]),
                .data_out(accum_grid[i])
            );
    end
    endgenerate
endmodule
