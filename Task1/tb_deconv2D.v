`timescale 1ns/1ps

module tb_deconv2D;

  // Parameters
  parameter N = 2;
  parameter K = 3;
  parameter PIXEL_WIDTH = 8;
  parameter ACCUM_WIDTH = PIXEL_WIDTH*2 + $clog2(N*N);
  parameter STRIDE = 2;
  parameter CLK_PERIOD = 20;

  // TB signals
  reg clk;
  reg rst;
  reg enable;
  reg load_kernel;
  reg load_input;
  reg [PIXEL_WIDTH-1:0] image_input;
  reg [PIXEL_WIDTH-1:0] kernel_input;

  wire input_ready;
  wire kernel_ready;
  wire done;
  wire [PIXEL_WIDTH-1:0] image_output [0:N*K*N*K-1];

  // Counters / variables
  integer i, j;
  integer errors;
  integer non_zero_count;
  integer total_sum;

  // Test data
  reg [PIXEL_WIDTH-1:0] test_image  [0:N*N-1];
  reg [PIXEL_WIDTH-1:0] test_kernel [0:K*K-1];

  // DUT
  deconv2D #(
    .N(N),
    .K(K),
    .PIXEL_WIDTH(PIXEL_WIDTH),
    .STRIDE(STRIDE)
  ) dut (
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .load_kernel(load_kernel),
    .load_input(load_input),
    .image_input(image_input),
    .kernel_input(kernel_input),
    .input_ready(input_ready),
    .kernel_ready(kernel_ready),
    .done(done),
    .image_output(image_output)
  );

  // Clock
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // Main stimulus
  initial begin
    errors = 0;

    $display("\n========================================");
    $display("DECONV2D SIMPLIFIED TESTBENCH");
    $display("Configuration: N=%0d, K=%0d, STRIDE=%0d", N, K, STRIDE);
    $display("Expected output size: %0dx%0d = %0d pixels", N*K, N*K, N*K*N*K);
    $display("========================================\n");

    // ---------------- Test vectors ----------------
    test_image[0] = 8'd1;  test_image[1] = 8'd2;
    test_image[2] = 8'd3;  test_image[3] = 8'd4;

    // Kernel:
    //  1 0 0
    //  0 1 0
    //  0 0 1
    test_kernel[0] = 8'd1; test_kernel[1] = 8'd0; test_kernel[2] = 8'd0;
    test_kernel[3] = 8'd0; test_kernel[4] = 8'd1; test_kernel[5] = 8'd0;
    test_kernel[6] = 8'd0; test_kernel[7] = 8'd0; test_kernel[8] = 8'd1;

    $display("Input Image (2x2):");
    for (i = 0; i < N; i = i + 1) begin
      $write("  ");
      for (j = 0; j < N; j = j + 1)
        $write("%3d ", test_image[i*N + j]);
      $display("");
    end

    $display("\nKernel (3x3):");
    for (i = 0; i < K; i = i + 1) begin
      $write("  ");
      for (j = 0; j < K; j = j + 1)
        $write("%3d ", test_kernel[i*K + j]);
      $display("");
    end

    // ---------------- Reset ----------------
    rst         = 1;
    enable      = 0;
    load_kernel = 0;
    load_input  = 0;
    image_input = 0;
    kernel_input= 0;

    repeat(3) @(posedge clk);
    rst = 0;
    @(posedge clk);
    $display("\n[%0t] === RESET RELEASED ===\n", $time);

    // =====================================================
    // STEP 1: Stream kernel weights (9 cycles)
    // =====================================================
    $display("[%0t] STEP 1: Loading kernel weights...", $time);

    // Wait until buffer reports ready once
    @(posedge clk);
    wait (kernel_ready == 1'b1);
    $display("[%0t]   kernel_ready=1, starting stream", $time);

    load_kernel = 1;
    for (i = 0; i < K*K; i = i + 1) begin
      kernel_input = test_kernel[i];      // data valid BEFORE clock
      @(posedge clk);
      $display("[%0t]   kernel[%0d] = %0d (kernel_ready=%b)",
               $time, i, kernel_input, kernel_ready);
    end
    load_kernel = 0;
    kernel_input = 0;
    @(posedge clk);
    $display("[%0t]   ? Kernel loading complete (kernel_ready=%b, kernel_loaded=%b)\n",
             $time, kernel_ready, dut.kernel_loaded);

    // =====================================================
    // STEP 2: Stream input image (4 cycles)
    // =====================================================
    $display("[%0t] STEP 2: Loading input image...", $time);

    @(posedge clk);
    wait (input_ready == 1'b1);
    $display("[%0t]   input_ready=1, starting stream", $time);

    load_input = 1;
    for (i = 0; i < N*N; i = i + 1) begin
      image_input = test_image[i];        // data valid BEFORE clock
      @(posedge clk);
      $display("[%0t]   image[%0d] = %0d (input_ready=%b)",
               $time, i, image_input, input_ready);
    end
    load_input = 0;
    image_input = 0;
    @(posedge clk);
    $display("[%0t]   ? Input loading complete (input_ready=%b, input_loaded=%b)\n",
             $time, input_ready, dut.input_loaded);

    // =====================================================
    // STEP 3: Start processing
    // =====================================================
    $display("[%0t] STEP 3: Starting deconvolution...\n", $time);
    enable = 1;
    @(posedge clk);
    enable = 0;

    // =====================================================
    // STEP 4: Wait for done (timeout-protected)
    // =====================================================
    i = 0;
    while (!done && i < 5000) begin
      @(posedge clk);
      i = i + 1;
    end

    if (!done) begin
      $display("[%0t] ERROR: Timeout waiting for done!", $time);
      errors = errors + 1;
      $finish;
    end

    $display("\n[%0t] === PROCESSING COMPLETE (done=1) === (cycles=%0d)\n", $time, i);

    // =====================================================
    // STEP 5: Check output
    // =====================================================
    non_zero_count = 0;
    for (i = 0; i < N*K*N*K; i = i + 1)
      if (image_output[i] != 0)
        non_zero_count = non_zero_count + 1;

    $display("Non-zero output pixels: %0d / %0d", non_zero_count, N*K*N*K);
    if (non_zero_count == 0) begin
      $display("? ERROR: All outputs are zero!");
      errors = errors + 1;
    end else begin
      $display("? PASS: Output contains data");
    end

    $display("\nOutput Feature Map (%0dx%0d):", N*K, N*K);
    for (i = 0; i < N*K; i = i + 1) begin
      $write("  ");
      for (j = 0; j < N*K; j = j + 1)
        $write("%4d ", image_output[i*(N*K) + j]);
      $display("");
    end

    // Simple corner check
    if (image_output[0] == test_image[0] * test_kernel[0]) begin
      $display("\n? Output[0,0] = %0d (expected %0d)",
               image_output[0], test_image[0]*test_kernel[0]);
    end else begin
      $display("\n? Output[0,0] = %0d (expected %0d)",
               image_output[0], test_image[0]*test_kernel[0]);
      errors = errors + 1;
    end

    total_sum = 0;
    for (i = 0; i < N*K*N*K; i = i + 1)
      total_sum = total_sum + image_output[i];
    $display("Total output sum: %0d", total_sum);
    if (total_sum == 0) begin
      $display("? ERROR: Zero total sum");
      errors = errors + 1;
    end else begin
      $display("? PASS: Non-zero total sum");
    end

    $display("\n========================================");
    if (errors == 0)
      $display("ALL TESTS PASSED! ?");
    else
      $display("TESTS FAILED: %0d errors ?", errors);
    $display("========================================\n");

    $finish;
  end

  // Optional debug monitors
  always @(dut.deconv_state) begin
    case (dut.deconv_state)
      2'b00: $display("[%0t] FSM: IDLE", $time);
      2'b01: $display("[%0t] FSM: RECIEVE", $time);
      2'b10: $display("[%0t] FSM: MULTIPLY (input_select=%0d)", $time, dut.input_select);
      2'b11: $display("[%0t] FSM: ACCUMULATE (input_select=%0d)", $time, dut.input_select);
    endcase
  end
  always @(posedge clk) begin
  if (dut.decode_done)
    $display("[%0t] decoded[0]=%0d prod[0]=%0d", $time, dut.decoded_image[0], dut.prod[0]);
  if (dut.accum_enable)
    $display("[%0t] accum_in[0]=%0d accum_out[0]=%0d", $time, dut.decoded_image[0], dut.accum_out[0]);
  end
  always @(posedge clk) begin
  if (dut.deconv_state == 2'b10) begin  // MULTIPLY
    $display("[%0t] MULTIPLY: input_select=%0d input_pix=%0d image[%0d]=%0d kernel[0]=%0d prod[0]=%0d",
             $time,
             dut.input_select,
             dut.input_pix,
             dut.input_select,
             dut.image[dut.input_select],
             dut.kernel_weights[0],
             dut.prod[0]);
  end
end


    

  initial begin
    #(CLK_PERIOD*10000);
    $display("\n[%0t] ERROR: Global simulation timeout!", $time);
    $finish;
  end

endmodule