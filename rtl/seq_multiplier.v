`timescale 1ns/1ps
module seq_multiplier #(
    parameter DATA_W = 32
)(
    input wire clk,
    input wire rst_n,
    input wire start,            // Pulse to start calculation
    input wire [DATA_W-1:0] a,   // Operand 1
    input wire [DATA_W-1:0] b,   // Operand 2
    output reg [DATA_W-1:0] result,
    output reg done,             // High when result is ready
    output wire busy             // High while calculating
);

    reg [DATA_W-1:0] mc; // Multiplicand (shifted left)
    reg [DATA_W-1:0] mp; // Multiplier (shifted right)
    reg [DATA_W-1:0] acc;
    reg [5:0] count;
    
    // State Encoding
    localparam IDLE = 1'b0, WORK = 1'b1;
    reg state;

    assign busy = (state == WORK);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            result  <= 0;
            done    <= 0;
            acc     <= 0;
            mc      <= 0;
            mp      <= 0;
            count   <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        mc    <= a;
                        mp    <= b;
                        acc   <= 0;
                        count <= 0;
                        state <= WORK;
                    end
                end

                WORK: begin
                    // 1. Shift and Add Logic
                    // If the current bit of multiplier (mp[0]) is 1, add mc to accumulator
                    if (mp[0]) begin
                        acc <= acc + mc;
                    end

                    // 2. Shift operands for next cycle
                    mc <= mc << 1; 
                    mp <= mp >> 1;
                    
                    // 3. Increment Counter
                    count <= count + 1;

                    // 4. Check Termination (32 cycles)
                    if (count == DATA_W-1) begin
                        state  <= IDLE;
                        done   <= 1'b1;
                        // Final capture of result
                        result <= (mp[0]) ? acc + mc : acc;
                    end
                end
            endcase
        end
    end

endmodule