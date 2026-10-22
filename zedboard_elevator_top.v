`timescale 1ns / 1ps

module zedboard_elevator_top (
    input clk,
    input rst_btn,
    input [7:0] switches,
    output [7:0] leds
);

    // Clock Enable
    wire fsm_clk_enable;

    my_clock_divider clk_div_inst (
        .clk_in  (clk),
        .rst_in  (rst_btn),
        .clk_out (fsm_clk_enable)
    );

    // Switch Edge Detection
    reg [7:0] switches_prev;
    wire [7:0] floor_request_pulse;

    always @(posedge clk or posedge rst_btn) begin
        if (rst_btn) begin
            switches_prev <= 8'b0;
        end else if (fsm_clk_enable) begin
            switches_prev <= switches;
        end
    end

    assign floor_request_pulse = switches & ~switches_prev;

    // Elevator FSM Signals
    wire [3:0] current_floor;
    wire [1:0] direction;
    wire door_open;
    wire Overload_LED;

    // Elevator FSM Instance
    elevator_fsm uut (
        .clk           (clk),
        .clk_enable    (fsm_clk_enable),
        .rst           (rst_btn),
        .floor_request (floor_request_pulse),
        .current_floor (current_floor),
        .direction     (direction),
        .door_open     (door_open),
        .Overload_LED  (Overload_LED)
    );

    // LED Mapping
    assign leds[3:0] = current_floor;
    assign leds[5:4] = direction;
    assign leds[6]   = door_open;
    assign leds[7]   = Overload_LED;

endmodule
