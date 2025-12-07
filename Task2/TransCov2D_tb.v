`timescale 1ns / 1ps

module TransCov2D_tb;

    // Parameters
    parameter N = 2;
    parameter K = 3;
    parameter pixel_bits = 8;

    // Inputs
    reg clk;
    reg enable;
    reg rst;
    reg strobe_signal_pixel;
    reg strobe_signal_kernel;
    reg [pixel_bits-1:0] pixel;
    reg [$clog2(K)-1:0] stride;
    reg [$clog2(K)-1:0] kernel_width;
    reg [pixel_bits-1:0] kernel_weight;
    reg [$clog2(N*N)-1:0] pixel_number;
    reg [$clog2(N*K*N*K)-1:0] result_address;

    // Outputs
    wire [pixel_bits*4-1:0] final_output;
    wire done;

    // Instantiate the Unit Under Test (UUT)
    deconv2D #(
        .N(N),
        .K(K),
        .pixel_bits(pixel_bits)
    ) uut (
        .clk(clk), 
        .enable(enable), 
        .rst(rst), 
        .strobe_signal_pixel(strobe_signal_pixel), 
        .strobe_signal_kernel(strobe_signal_kernel), 
        .pixel(pixel), 
        .stride(stride), 
        .kernel_width(kernel_width), 
        .kernel_weight(kernel_weight), 
        .pixel_number(pixel_number), 
        .result_address(result_address), 
        .final_output(final_output), 
        .done(done)
    );

    // Clock Generation
    always #5 clk = ~clk; // 10ns period

    // Task to Send Kernel Weights
    task load_kernel;
        input [pixel_bits-1:0] weight_val;
        begin
            strobe_signal_kernel = 0;
            kernel_weight = weight_val;
            #10; // Wait for setup
            strobe_signal_kernel = 1; // Pulse Strobe
            #10;
            strobe_signal_kernel = 0;
            #10;
        end
    endtask

    // Task to Send Pixels
    task send_pixel;
        input [pixel_bits-1:0] p_val;
        input [$clog2(N*N)-1:0] p_num;
        begin
            strobe_signal_pixel = 0;
            pixel = p_val;
            pixel_number = p_num;
            #10;
            strobe_signal_pixel = 1; // Pulse Strobe
            #10;
            strobe_signal_pixel = 0;
            // Wait some time to simulate processing (optional, FSM handles it)
            #100; 
        end
    endtask

    integer i;

    initial begin
        // Initialize Inputs
        clk = 0;
        enable = 0;
        rst = 1;
        strobe_signal_pixel = 0;
        strobe_signal_kernel = 0;
        pixel = 0;
        stride = 3;      
        kernel_width = 3; 
        kernel_weight = 0;
        pixel_number = 0;
        result_address = 0;

        // Reset Sequence
        #20;
        rst = 0;
        #10;
        

        // Triggering diagram logic to visualize stride/kernel
        
        $display("--- Starting Simulation ---");
        enable = 1;
        #20; // Wait for IDLE -> CLEAR_RAM -> INITIALIZE transition

        
        $display("Loading Kernel Weights (All 1s)...");
        // We are sending 4 weights because kernel_width=2
        load_kernel(8'd1); // Weight 0
        load_kernel(8'd1); // Weight 1
        load_kernel(8'd1); // Weight 2
        load_kernel(8'd1); // Weight 3
        load_kernel(8'd1); // Weight 4
        load_kernel(8'd1); // Weight 5
        load_kernel(8'd1); // Weight 6
        load_kernel(8'd1); // Weight 7
        load_kernel(8'd1); // Weight 8
        
        // Wait for FSM to transition to ASSIGN_REG
        #20; 

        // -------------------------------------------------
        // 2. Process Image Pixels (2x2 Image)
        // -------------------------------------------------
        $display("Processing Pixels...");
        
        // Pixel 0 (Top-Left) = 10
        send_pixel(8'd10, 0); 
        
        // Pixel 1 (Top-Right) = 20
        send_pixel(8'd20, 1);
        
        // Pixel 2 (Bottom-Left) = 30
        send_pixel(8'd30, 2);
        
        // Pixel 3 (Bottom-Right) = 40
        send_pixel(8'd40, 3);

        // -------------------------------------------------
        // 3. Wait for Done
        // -------------------------------------------------
        wait(done == 1);
        $display("--- Processing Done ---");
        enable = 0;

        // -------------------------------------------------
        // 4. Read Output
        // -------------------------------------------------
        $display("Reading Result RAM (Non-zero values):");
        
        // Check a reasonable range. 
        // With N=2, K=3, Stride=1, Max Address is roughly 6x6 area.
        for (i = 0; i < N*K*N*K; i = i + 1) begin
            result_address = i;
            #10; // Wait for read
            if (final_output !== 0) begin
                $display("Address %0d: Value %0d", i, final_output);
            end
        end

        $finish;
    end
      
endmodule