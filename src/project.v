/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_elevator_controller (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // --- PIN ASSIGNMENTS ---
    // ui_in[4:0]   : Inside Cabin Floor Select (0-4)
    // ui_in[7:5]   : Hall Call UP (0, 1, 2)
    // uio_in[0]    : Hall Call UP (3)
    // uio_in[4:1]  : Hall Call DOWN (1, 2, 3, 4)
    // uo_out[2:0]  : Current Floor (Binary)
    // uo_out[3]    : Moving Up LED
    // uo_out[4]    : Moving Down LED
    // uo_out[5]    : Door Open LED (Blinks when open)
    // uo_out[6]    : OLED SCL (Clock passthrough)
    // uo_out[7]    : OLED SDA (Ground)

    wire rst = !rst_n;
    wire [2:0] current_floor;
    wire moving_up, moving_down, floor_reached;
    wire [2:0] target_floor;
    wire [4:0] floor_requests;

    // Slow blink logic for the Door Open LED (approx 2Hz at 10MHz)
    reg [21:0] blink_count;
    always @(posedge clk) blink_count <= blink_count + 1;
    wire door_visual = floor_reached && blink_count[21];

    // Instantiate Request Handler
    request_handler RH (
        .clk(clk), .rst(rst),
        .call_up_0(ui_in[5]), .call_up_1(ui_in[6]), .call_up_2(ui_in[7]), .call_up_3(uio_in[0]),
        .call_down_1(uio_in[1]), .call_down_2(uio_in[2]), .call_down_3(uio_in[3]), .call_down_4(uio_in[4]),
        .select_floor_0(ui_in[0]), .select_floor_1(ui_in[1]), .select_floor_2(ui_in[2]), 
        .select_floor_3(ui_in[3]), .select_floor_4(ui_in[4]),
        .current_floor(current_floor), .floor_reached(floor_reached),
        .floor_requests(floor_requests), .target_floor(target_floor)
    );

    // Instantiate Movement Controller with HUMAN VISIBLE DELAYS
    // 10,000,000 cycles = 1 second at 10MHz
    movement_controller #( .MOVE_DELAY(24'd10_000_000), .DOOR_DELAY(24'd20_000_000) ) MC (
        .clk(clk), .rst(rst), .target_floor(target_floor), .current_floor(current_floor),
        .floor_reached(floor_reached), .moving_up(moving_up), .moving_down(moving_down)
    );

    // --- OUTPUT ASSIGNMENTS ---
    assign uo_out[2:0] = current_floor;
    assign uo_out[3]   = moving_up;
    assign uo_out[4]   = moving_down;
    assign uo_out[5]   = door_visual; 
    
    // OLED Placeholders
    assign uo_out[6]   = clk; 
    assign uo_out[7]   = 1'b0; 

    // Configure uio pins as inputs
    assign uio_oe  = 8'b00000000;
    assign uio_out = 8'b00000000;

endmodule

module request_handler(   
    input  wire        clk, rst,
    input  wire        call_up_0, call_up_1, call_up_2, call_up_3,
    input  wire        call_down_1, call_down_2, call_down_3, call_down_4,
    input  wire        select_floor_0, select_floor_1, select_floor_2, select_floor_3, select_floor_4,
    input  wire [2:0]  current_floor,
    input  wire        floor_reached,
    output reg  [4:0]  floor_requests,
    output reg  [2:0]  target_floor
);
    reg floor_reached_prev;
    wire served = floor_reached_prev && !floor_reached;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            floor_requests <= 5'b0;
            floor_reached_prev <= 0;
        end else begin
            floor_reached_prev <= floor_reached;
            if (call_up_0   || select_floor_0) floor_requests[0] <= 1;
            if (call_up_1   || call_down_1 || select_floor_1) floor_requests[1] <= 1;
            if (call_up_2   || call_down_2 || select_floor_2) floor_requests[2] <= 1;
            if (call_up_3   || call_down_3 || select_floor_3) floor_requests[3] <= 1;
            if (call_down_4 || select_floor_4)                floor_requests[4] <= 1;
            if (served) floor_requests[current_floor] <= 0;
        end
    end

    always @(*) begin
        target_floor = current_floor; 
        if (floor_requests != 5'b0) begin
            if (floor_requests[4])      target_floor = 3'd4;
            if (floor_requests[3])      target_floor = 3'd3;
            if (floor_requests[2])      target_floor = 3'd2;
            if (floor_requests[1])      target_floor = 3'd1;
            if (floor_requests[0])      target_floor = 3'd0;
        end
    end
endmodule

module movement_controller #(
    parameter MOVE_DELAY = 10_000_000,
    parameter DOOR_DELAY = 20_000_000
)(            
    input  wire        clk, rst,
    input  wire [2:0]  target_floor,
    output reg  [2:0]  current_floor,
    output reg         floor_reached, moving_up, moving_down
);
    localparam IDLE=0, UP=1, DOWN=2, ARRIVED=3;
    reg [1:0]  state;
    reg [27:0] count; // Increased bit-width for large delays

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE; current_floor <= 3'd0; count <= 0;
            moving_up <= 0; moving_down <= 0; floor_reached <= 0;
        end else begin
            case (state)
                IDLE: begin
                    floor_reached <= 0; moving_up <= 0; moving_down <= 0; count <= 0;
                    if      (target_floor > current_floor) state <= UP;
                    else if (target_floor < current_floor) state <= DOWN;
                end
                UP: begin
                    moving_up <= 1;
                    if (count < MOVE_DELAY) count <= count + 1;
                    else begin
                        count <= 0;
                        current_floor <= current_floor + 1;
                        if (current_floor + 1 == target_floor) state <= ARRIVED;
                    end
                end
                DOWN: begin
                    moving_down <= 1;
                    if (count < MOVE_DELAY) count <= count + 1;
                    else begin
                        count <= 0;
                        current_floor <= current_floor - 1;
                        if (current_floor - 1 == target_floor) state <= ARRIVED;
                    end
                end
                ARRIVED: begin
                    moving_up <= 0; moving_down <= 0;
                    if (count < DOOR_DELAY) begin
                        floor_reached <= 1;
                        count <= count + 1;
                    end else begin
                        floor_reached <= 0;
                        count <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
