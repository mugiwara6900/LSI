`timescale 1ns/1ps
module deconv2D_tb;

parameter N = 2;
parameter K = 3;
parameter pixel_bits = 8;
parameter NUM_PIXELS = N * N;
parameter NUM_WEIGHTS = K * K;
parameter RESULT_ADDR_WIDTH = $clog2(N * K * N * K);

reg clk;
reg enable;
reg rst;
reg strobe_signal;
reg [pixel_bits-1:0] pixel;
reg [pixel_bits-1:0] kernel_weight;
reg [$clog2(N*N)-1:0] pixel_number;
reg [RESULT_ADDR_WIDTH-1:0] result_address;
reg [$clog2(K)-1:0] stride;
reg [$clog2(K*K)-1:0] number_weights;
wire [pixel_bits-1:0] final_output;
wire done;

deconv2D #(.N(N), .K(K), .pixel_bits(pixel_bits)) dut (
    .clk(clk),
    .enable(enable),
    .rst(rst),
    .strobe_signal(strobe_signal),
    .pixel(pixel),
    .kernel_weight(kernel_weight),
    .pixel_number(pixel_number),
    .result_address(result_address),
    .stride(stride),
    .number_weights(number_weights),
    .final_output(final_output),
    .done(done)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    enable = 0;
    rst = 1;
    strobe_signal = 0;
    pixel = 0;
    kernel_weight = 0;
    pixel_number = 0;
    result_address = 0;
    stride = 1;
    number_weights = K;
    #20;
    repeat (2) @(posedge clk);
    rst = 0;
    @(posedge clk);
    enable = 1;
    @(posedge clk);
    initialize_weights();
    send_pixels();
    wait(done == 1);
    #20;
    $finish;
end

reg [pixel_bits-1:0] weight_vec [0:NUM_WEIGHTS-1];
initial begin
    weight_vec[0] = 8'd1;
    weight_vec[1] = 8'd0;
    weight_vec[2] = 8'd0;
    weight_vec[3] = 8'd1;
    weight_vec[4] = 8'd2;
    weight_vec[5] = 8'd0;
    weight_vec[6] = 8'd0;
    weight_vec[7] = 8'd0;
    weight_vec[8] = 8'd3;
end

task initialize_weights;
    integer i;
    begin
        for (i = 0; i < NUM_WEIGHTS; i = i + 1) begin
            strobe_signal = 1;
            kernel_weight = weight_vec[i];
            @(posedge clk);
            strobe_signal = 0;
            @(posedge clk);
        end
    end
endtask

reg [pixel_bits-1:0] pixel_vec [0:NUM_PIXELS-1];
initial begin
    pixel_vec[0] = 8'd1;
    pixel_vec[1] = 8'd3;
    pixel_vec[2] = 8'd0;
    pixel_vec[3] = 8'd2;
end

task send_pixels;
    integer i;
    begin
        for (i = 0; i < NUM_PIXELS; i = i + 1) begin
            pixel_number = i[$clog2(NUM_PIXELS)-1:0];
            pixel = pixel_vec[i];
            @(posedge clk);
            @(posedge clk);
        end
    end
endtask

endmodule