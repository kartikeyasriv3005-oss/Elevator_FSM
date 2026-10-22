verilog
`timescale 1ns / 1ps

module my_clock_divider (
    input clk_in,
    input rst_in,
    output clk_out
);

    // Parameters
    parameter COUNT_MAX = 100_000_000 - 1;

    // Counter Register
    reg [26:0] counter_reg;

    // Counter Logic
    always @(posedge clk_in or posedge rst_in) begin
        if (rst_in) begin
            counter_reg <= 0;
        end else begin
            if (counter_reg == COUNT_MAX)
                counter_reg <= 0;
            else
                counter_reg <= counter_reg + 1'b1;
        end
    end

    // Clock Output
    assign clk_out = (counter_reg == COUNT_MAX);

endmodule
