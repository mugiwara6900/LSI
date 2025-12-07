module decoder #(
    parameter N = 2,
    parameter K = 3,
    parameter ILEN = 8,
    parameter OLEN = 16,
    parameter stride = 2
)(
    input wire clk,
    input wire rst,
    input wire enable,
    input wire [$clog2(N*N)-1:0] state, // represents the current pixel index.
    input wire [OLEN-1:0] multiplied_image [0:K*K-1], // input image coming in from the multiplier.
    output reg [OLEN-1:0] decoded_image [0:N*K*N*K-1], // output image.
    output reg decoding_complete // indicates the completion of the decoding process.
);
    //states of the state machine.
    reg [1:0] fsm_state;
    localparam IDLE   = 2'b00,
               DECODE = 2'b01,
               DONE   = 2'b10;

    //indices.
    reg [$clog2(K*K):0] prod_idx; // counter variable.
    reg [$clog2(N*K)-1:0] base_x, base_y; // x and y coordinates of the input
    reg enable_prev; // tracking the enable in the previous cycle.
    
    // assigning wires to registers. These combinations are fixed.
    wire [$clog2(N*K)-1:0] out_x = base_x + (prod_idx / K); // output x coordinate
    wire [$clog2(N*K)-1:0] out_y = base_y + (prod_idx % K); // output y coordinate
    wire [$clog2(N*K*N*K)-1:0] out_idx = out_x * (N*K) + out_y; // output index in 1D format

    always @(posedge clk) begin
        if (rst) begin
            fsm_state <= IDLE;
            decoding_complete <= 1'b0;
            prod_idx <= 0;
            base_x <= 0;
            base_y <= 0;
            enable_prev <= 0;
            decoded_image <= '{default: '0};
        end else begin
            enable_prev <= enable;
            
            case (fsm_state)
                
                IDLE: begin
                    decoding_complete <= 1'b0;
                    prod_idx <= 0;
                    
                    // Detect rising edge of enable
                    if (enable && !enable_prev) begin
                        // Clear entire array on new enable
                        decoded_image <= '{default: '0};
                        base_x <= (state / N) * stride; // getting the x coordinate of the input image
                        base_y <= (state % N) * stride; // getting the y coordinate of the input image
                        fsm_state <= DECODE;
                    end
                end
                
                DECODE: begin
                    if (prod_idx < K*K) begin
                        decoded_image[out_idx] <= multiplied_image[prod_idx];
                        prod_idx <= prod_idx + 1;
                    end else begin
                        fsm_state <= DONE;
                    end
                end
                
                DONE: begin
                    decoding_complete <= 1'b1;
                    fsm_state <= IDLE;
                end
                
                default: fsm_state <= IDLE;
                
            endcase
        end
    end

endmodule