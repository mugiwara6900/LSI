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
    wire ready; // <--- 1. New Wire for Handshake

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
        .ready(ready), // <--- 2. Connect the Ready Signal
        .done(done)
    );

    // Clock Generation
    always #5 clk = ~clk; // 10ns period

    // ---------------------------------------------------------
    // Task: Send Kernel Weights (With Handshake)
    // ---------------------------------------------------------
    integer clk_counter = 0;

    always @(posedge clk) begin
        clk_counter = clk_counter + 1;
    end

    task load_kernel;
        input [pixel_bits-1:0] weight_val;
        begin
            // Wait until module says "I am ready for data"
            wait(ready == 1); 
            
            // Align with clock edge to allow setup time
            @(posedge clk);   
            
            kernel_weight = weight_val;
            strobe_signal_kernel = 1; 
            
            // Hold strobe High for one clock cycle
            @(posedge clk);   
            
            strobe_signal_kernel = 0;
            // No extra delay needed; next call will wait for ready automatically
        end
    endtask

    // ---------------------------------------------------------
    // Task: Send Pixels (With Handshake)
    // ---------------------------------------------------------
    task send_pixel;
        input [pixel_bits-1:0] p_val;
        input [$clog2(N*N)-1:0] p_num;
        begin
            // 1. Handshake: Block execution until Module is finished processing previous pixel
            wait(ready == 1); 
            
            // 2. Setup Data
            @(posedge clk);
            pixel = p_val;
            pixel_number = p_num;
            
            // 3. Pulse Strobe
            strobe_signal_pixel = 1;
            @(posedge clk); // Hold for 1 cycle
            strobe_signal_pixel = 0;
            
            // Note: We removed the hardcoded #100 wait.
            // The next time we call send_pixel, the 'wait(ready)' line 
            // will automatically pause until the ADD loop is finished.
        end
    endtask

    integer i, j;

    

    initial begin
        // Initialize Inputs
        clk = 0;
        enable = 0;
        rst = 1;
        strobe_signal_pixel = 0;
        strobe_signal_kernel = 0;
        pixel = 0;
        stride = 1;      
        kernel_width = 2; 
        kernel_weight = 0;
        pixel_number = 0;
        result_address = 0;

        // Reset Sequence
        #20;
        rst = 0;
        #10;

        $display("--- Starting Simulation ---");
        enable = 1;
        
        // Note: We removed the hardcoded #20 wait here.
        // The load_kernel task below will automatically wait 
        // for the CLEAR_RAM state to finish (when ready goes high).

        $display("Loading Kernel Weights ...");
        // We are sending 4 weights because kernel_width=2
        // These will execute back-to-back as fast as the module allows
        load_kernel(8'd1); // Weight 0
        load_kernel(8'd1); // Weight 1
        load_kernel(8'd1); // Weight 2
        load_kernel(8'd1); // Weight 3
        /* load_kernel(8'd1); // Weight 4
        load_kernel(8'd1); // Weight 5
        load_kernel(8'd1); // Weight 6
        load_kernel(8'd1); // Weight 7
        load_kernel(8'd1); // Weight 8
        */

        // -------------------------------------------------
        // 2. Process Image Pixels (2x2 Image)
        // -------------------------------------------------
        $display("Processing Pixels...");
        
        // The send_pixel task now handles the timing flow control.
        // It won't send Pixel 1 until Pixel 0 is fully calculated.
        
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
        $display("Total execution time: %0d clock cycles", clk_counter);
        enable = 0;

        // -------------------------------------------------
        // 4. Read Output
        // -------------------------------------------------
        $display("Reading Result RAM (Non-zero values):");
        
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