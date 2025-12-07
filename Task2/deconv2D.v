`include "multiply_unit.v"
`include "decoder.v"

module deconv2D #(
    parameter N = 2,
    parameter K = 3,
    parameter pixel_bits = 8

)(
    input wire clk,
    input wire enable,
    input wire rst,
    input wire strobe_signal_pixel,
    input wire strobe_signal_kernel,
    input wire [pixel_bits-1:0] pixel,
    input wire [$clog2(K)-1:0] stride,
    input wire [$clog2(K)-1:0] kernel_width,
    input wire [pixel_bits-1:0] kernel_weight,
    input wire [$clog2(N*N)-1:0] pixel_number,
    input wire [$clog2(N*K*N*K)-1:0] result_address,
    output wire [pixel_bits*4-1:0] final_output,
    output wire done
);

    integer j, k, l;

    reg [2:0] state;

    reg [pixel_bits-1:0] kernel_RAM [0: K*K-1];
    reg [pixel_bits*4 - 1:0] result_RAM [0:N*K*N*K-1];

    reg [$clog2(K*K)-1:0] weight_counter;
    reg [$clog2(K*K)-1:0] add_counter;
    reg [$clog2(N*N)-1:0] pixel_counter;
    
    reg [pixel_bits*2 - 1:0] multiplied_output_reg [0:K*K -1];
    reg done_temp;

    wire [pixel_bits*2 - 1:0] multiplied_output [0:K*K -1];
    wire [$clog2(N*K*N*K)-1:0] decoded_index [0:K*K -1];
    wire [$clog2(K*K)-1:0] actual_index = ((weight_counter/kernel_width)*K) + (weight_counter % kernel_width); 

    assign done = done_temp;
    assign final_output = result_RAM[result_address];

    localparam IDLE = 3'b000;
    localparam CLEAR_RAM = 3'b001;
    localparam INITIALIZE = 3'b010;
    localparam ASSIGN_REG = 3'b011;
    localparam ADD = 3'b100;
    localparam DONE_STATE = 3'b101;

    genvar i;
    generate

        for (i = 0; i < K*K ; i = i + 1) begin : module_instances

            wire [$clog2(K*K)-1:0] idx_wire = i;

            multiply_unit #(
                .pixel_bits(pixel_bits)
            ) multiply(
                .pixel(pixel),
                .kernel_weight(kernel_RAM[i]),
                .multiplied_output(multiplied_output[i])
            );
            decoder #(
                .N(N),
                .K(K)
            ) decode_module(
                .current_index(idx_wire),
                .pixel_number(pixel_number),
                .stride(stride),
                .decoded_index(decoded_index[i])
            );
        end

    endgenerate

    always @(posedge clk) begin
        if(rst) begin
            done_temp <= 0;
            weight_counter <= 0; 
            add_counter <= 0;
            pixel_counter <= 0;
            state <= IDLE;
        end else begin
            case(state) 

                IDLE: begin
                    done_temp <= 0;  
                    weight_counter <= 0;
                    add_counter <= 0;
                    pixel_counter <= 0;
                    
                    if(enable) begin
                        state <= CLEAR_RAM;
                    end
                end

                CLEAR_RAM: begin
                    for(j = 0; j < N*N*K*K; j = j + 1) begin 
                        result_RAM[j] <= 0;
                    end
                    for(l = 0; l < K*K; l = l + 1) begin
                        kernel_RAM[l] <= 0;
                    end
                    state <= INITIALIZE;
                end

                INITIALIZE: begin
                    if (weight_counter == kernel_width*kernel_width) begin
                        state <= ASSIGN_REG;
                    end
                    else if (strobe_signal_kernel) begin
                        kernel_RAM[actual_index] <= kernel_weight;
                        weight_counter <= weight_counter + 1'b1;
                    end
                end

                ASSIGN_REG: begin
                    if(strobe_signal_pixel) begin
                        for(k = 0; k < K*K; k = k + 1) begin 
                            multiplied_output_reg[k] <= multiplied_output[k];
                        end
                        state <= ADD;
                        add_counter <= 0;
                    end
                    
                end

                ADD: begin
                    if(add_counter == K*K) begin
                        if(pixel_counter == N*N-1) begin
                            state <= DONE_STATE;
                        end else begin
                            pixel_counter <= pixel_counter + 1'b1;
                            state <= ASSIGN_REG;
                        end
                    end else begin
                        result_RAM[decoded_index[add_counter]] <= result_RAM[decoded_index[add_counter]] + multiplied_output_reg[add_counter];
                        add_counter <= add_counter + 1'b1;
                    end
                end

                DONE_STATE: begin
                    done_temp <= 1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done_temp <= 0;
                    weight_counter <= 0;
                    add_counter <= 0;
                    pixel_counter <= 0;
                end
            endcase
        end
    end
endmodule