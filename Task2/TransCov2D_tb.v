module deconv2D_tb;

reg clk; // clock
reg enable; // enable pin starts the whole process
reg rst; //resets kernel weights to 0 
reg strobe_signal; //strobe signal (used for loading kernel weights)
reg [7:0] pixel; //1 byte pixel of image 
reg [7:0] kernel_weight; //weight of kernel
reg [$clog2(N*N)-1] pixel_number; // index of pixel (useful for decoding convoluted position in F.M)
reg [$clog2(N*K*N*K)-1:0] result_address; // decoded position in F.M
reg [$clog2(K)-1:0] stride; // stride we are using for DeConv
wire [7:0] final_output; // final output 
wire done; // 1 pixel completely processed

deconv2D test_deconv2D (
    .clk(clk),
    .enable(enable),
    .rst(rst),
    .strobe_signal(strobe_signal),
    .pixel(pixel),
    .kernel_weight(kernel_weight),
    .pixel_number(pixel_number),
    .result_address(result_address),
    .result_address(result_address),
    .stride(stride),
    .final_output(final_output),
    .done(done)
);

function void init();
    clk <= 0;
    enable <= 0;
    rst <= 1;
    strobe_signal <= 0;
    pixel <= 0;
    kernel_weight <= 0;
    pixel_number <= 0;
    result_address <= 0;
    stride <= 1;
    final_output <= 0;
endfunction

initial begin
    init();

    #10 // 10 time units delay
end

task release_reset();
    #10 rst <= 0;
endtask

task initialize_weights();
    //first weight
    strobe_signal <= 1;
    kernel_weight <= 1;
    @(posedge clk)
    strobe_signal <= 0;
    @(posedge clk)
    //second weight
    strobe_signal <= 1;
    kernel_weight <= 0;
    @(posedge clk)
    strobe_signal <= 0;
    @(posedge clk)
    //third weight
    strobe_signal <= 1;
    kernel_weight <= 0;
    @(posedge clk)
    strobe_signal <= 0;
    @(posedge clk)
    //fourth weight
    strobe_signal <= 1;
    kernel_weight <= 1;
    @(posedge clk)
    strobe_signal <= 0;
    @(posedge clk)
    //fifth weight
    strobe_signal <= 1;
    kernel_weight <= 2;
    @(posedge clk)
    strobe_signal <= 0;
    @(posedge clk)
    //sixth weight
    strobe_signal <= 1;
    kernel_weight <= 0;
    @(posedge clk)
    strobe_signal <= 0;
    @(posedge clk)
    //seventh weight
    strobe_signal <= 1;
    kernel_weight <= 0;
    @(posedge clk)
    strobe_signal <= 0;
    @(posedge clk)
    //eighth weight
    strobe_signal <= 1;
    kernel_weight <= 0;
    @(posedge clk)
    strobe_signal <= 0;
    @(posedge clk)
    //ninth weight
    strobe_signal <= 1;
    kernel_weight <= 3;
    @(posedge clk)
    strobe_signal <= 0;
    @(posedge clk)
endtask

task send_pixels();
    // first pixel sent
    pixel_number <= 0;
    pixel <= 1;
    @(posedge clk);
    //second pixel sent
    pixel_number <= 1;
    pixel <= 3;
    @(posedge clk);
    //third pixel sent
    pixel_number <= 2;
    pixel <= 0;
    @(posedge clk);
    //fourth pixel sent
    pixel_number <= 3;
    pixel <= 2;
    @(posedge clk);
endtask

endmodule