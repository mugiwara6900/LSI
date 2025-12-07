module decoder#(
    parameter K = 3,
    parameter N = 2
)(
    input wire [$clog2(K*K)-1:0] current_index,
    input wire [$clog2(N*N)-1:0] pixel_number,
    input wire [$clog2(K)-1:0] stride,
    output wire [$clog2(N*N*K*K)-1:0] decoded_index
);

    wire [$clog2(K)-1:0] k_x = (current_index / K);
    wire [$clog2(K)-1:0] k_y = (current_index % K);


    wire [$clog2(N*K)-1:0] shift_x = k_x + stride * (pixel_number / N); 
    wire [$clog2(N*K)-1:0] shift_y = k_y + stride * (pixel_number % N);

    assign decoded_index = shift_x * (N*K) + shift_y;

endmodule