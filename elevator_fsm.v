`timescale 1ns / 1ps

module elevator_fsm (
    input clk,
    input clk_enable,
    input rst,
    input [7:0] floor_request,

    output reg [3:0] current_floor,
    output reg [1:0] direction,
    output reg door_open,
    output reg Overload_LED
);

    // Parameters
    parameter FLOOR_0 = 4'd0;
    parameter FLOOR_7 = 4'd7;

    parameter S_IDLE       = 2'b00;
    parameter S_MOVING_UP  = 2'b01;
    parameter S_MOVING_DOWN = 2'b10;
    parameter S_DOOR_OPEN  = 2'b11;

    parameter D_IDLE = 2'b00;
    parameter D_UP   = 2'b01;
    parameter D_DOWN = 2'b10;

    parameter DOOR_OPEN_CYCLES       = 10;
    parameter MOVE_CYCLES_PER_FLOOR  = 2;
    parameter QUEUE_DEPTH            = 8;
    parameter IDLE_TIMEOUT_CYCLES    = 20;
    parameter OVERload_led_cycles    = 10;

    // Internal Registers
    reg [1:0] state, next_state;

    reg [3:0] door_timer;
    reg [1:0] move_timer;
    reg [4:0] idle_timer;
    reg [3:0] overload_timer;

    // FIFO Queue Registers
    reg [3:0] queue [0:QUEUE_DEPTH-1];
    reg [3:0] head;
    reg [3:0] tail;
    reg [3:0] count;

    reg [7:0] requests_to_enqueue;
    reg [3:0] current_target_floor;
    reg target_valid;

    // Queue Status
    wire queue_empty = (count == 0);
    wire queue_full  = (count == QUEUE_DEPTH);

    // Priority Encoder
    wire [2:0] pe_index;
    wire pe_valid;

    assign pe_index =
        requests_to_enqueue[0] ? 3'd0 :
        requests_to_enqueue[1] ? 3'd1 :
        requests_to_enqueue[2] ? 3'd2 :
        requests_to_enqueue[3] ? 3'd3 :
        requests_to_enqueue[4] ? 3'd4 :
        requests_to_enqueue[5] ? 3'd5 :
        requests_to_enqueue[6] ? 3'd6 :
        requests_to_enqueue[7] ? 3'd7 :
                                 3'd0;

    assign pe_valid = |requests_to_enqueue;

    reg [7:0] next_requests_to_enqueue;

    // Combinational Logic: Next State and Outputs
    always @(*) begin
        next_state = state;
        direction  = D_IDLE;
        door_open  = 1'b0;

        case (state)

            S_IDLE: begin
                direction = D_IDLE;

                if (target_valid) begin
                    if (current_floor < current_target_floor)
                        next_state = S_MOVING_UP;
                    else if (current_floor > current_target_floor)
                        next_state = S_MOVING_DOWN;
                    else
                        next_state = S_DOOR_OPEN;
                end
            end

            S_MOVING_UP: begin
                direction = D_UP;

                if (move_timer == MOVE_CYCLES_PER_FLOOR) begin
                    if (current_floor == current_target_floor)
                        next_state = S_DOOR_OPEN;
                end
            end

            S_MOVING_DOWN: begin
                direction = D_DOWN;

                if (move_timer == MOVE_CYCLES_PER_FLOOR) begin
                    if (current_floor == current_target_floor)
                        next_state = S_DOOR_OPEN;
                end
            end

            S_DOOR_OPEN: begin
                direction = D_IDLE;
                door_open = 1'b1;

                if (door_timer == DOOR_OPEN_CYCLES)
                    next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
                direction  = D_IDLE;
                door_open  = 1'b0;
            end

        endcase

        // Request Latching and Clearing
        next_requests_to_enqueue =
            requests_to_enqueue | floor_request;

        if (pe_valid)
            next_requests_to_enqueue[pe_index] = 1'b0;
    end

    // Sequential Logic: State, Floor, Timers, and Queue
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state                <= S_IDLE;
            current_floor        <= FLOOR_0;
            door_timer           <= 0;
            move_timer           <= 0;
            idle_timer           <= 0;
            overload_timer       <= 0;
            Overload_LED         <= 0;

            head                 <= 0;
            tail                 <= 0;
            count                <= 0;
            requests_to_enqueue  <= 8'b0;
            target_valid         <= 0;
            current_target_floor <= 0;

        end else if (clk_enable) begin
            state <= next_state;

            requests_to_enqueue <= next_requests_to_enqueue;

            // Overload Timer and LED
            if (overload_timer > 0) begin
                overload_timer <= overload_timer - 1'b1;
                Overload_LED   <= 1'b1;
            end else begin
                Overload_LED <= 1'b0;
            end

            // Queue Enqueue Logic
            if (pe_valid && overload_timer == 0) begin
                if (pe_index == current_floor) begin
                    if (state == S_IDLE)
                        state <= S_DOOR_OPEN;
                    else if (state == S_DOOR_OPEN)
                        door_timer <= 0;

                end else if (count < 5) begin
                    queue[tail] <= pe_index;
                    tail        <= tail + 1'b1;
                    count       <= count + 1'b1;

                end else begin
                    overload_timer <= OVERload_led_cycles;
                    Overload_LED   <= 1'b1;
                end
            end

            // Target Selection
            if (state == S_IDLE && !target_valid) begin
                if (!queue_empty) begin
                    current_target_floor <= queue[head];
                    target_valid         <= 1'b1;

                end else if (
                    idle_timer == IDLE_TIMEOUT_CYCLES &&
                    current_floor != FLOOR_0
                ) begin
                    current_target_floor <= FLOOR_0;
                    target_valid         <= 1'b1;
                end
            end

            // Queue Dequeue Logic
            if (next_state == S_DOOR_OPEN && state != S_DOOR_OPEN) begin
                if (count > 0) begin
                    head  <= head + 1'b1;
                    count <= count - 1'b1;
                end

                target_valid <= 1'b0;
            end

            if (state == S_DOOR_OPEN) begin
                if (!target_valid && !queue_empty) begin
                    current_target_floor <= queue[head];
                    target_valid         <= 1'b1;
                end
            end

            // Movement Timer
            if (next_state == S_MOVING_UP ||
                next_state == S_MOVING_DOWN) begin

                if (move_timer < MOVE_CYCLES_PER_FLOOR)
                    move_timer <= move_timer + 1'b1;
                else
                    move_timer <= 0;

            end else begin
                move_timer <= 0;
            end

            // Floor Movement
            if (
                state == S_MOVING_UP &&
                next_state == S_MOVING_UP &&
                move_timer == MOVE_CYCLES_PER_FLOOR
            ) begin
                if (current_floor < FLOOR_7)
                    current_floor <= current_floor + 1'b1;

            end else if (
                state == S_MOVING_DOWN &&
                next_state == S_MOVING_DOWN &&
                move_timer == MOVE_CYCLES_PER_FLOOR
            ) begin
                if (current_floor > FLOOR_0)
                    current_floor <= current_floor - 1'b1;
            end

            // Door Timer
            if (next_state == S_DOOR_OPEN) begin
                if (door_timer < DOOR_OPEN_CYCLES)
                    door_timer <= door_timer + 1'b1;
            end else begin
                door_timer <= 0;
            end

            // Idle Timer
            if (state == S_IDLE && !target_valid && queue_empty) begin
                if (current_floor != FLOOR_0) begin
                    if (idle_timer < IDLE_TIMEOUT_CYCLES)
                        idle_timer <= idle_timer + 1'b1;
                end else begin
                    idle_timer <= 0;
                end
            end else begin
                idle_timer <= 0;
            end
        end
    end

endmodule
