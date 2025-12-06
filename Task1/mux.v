module mux #(
    parameter N = 2,                  // size of input (must match case entries)
    parameter WIDTH = 8               // width of each input
)(
    input  wire [WIDTH-1:0] in_line [0:N*N-1],
    input  wire [$clog2(N*N)-1:0] select,
    output wire [WIDTH-1:0] out_line
);
    assign out_line = in_line[select];
endmodule