/*
 * Copyright (c) 2024 Team Trinity
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_hardware_accelerator (
    input  wire [7:0] ui_in,    // Dedicated inputs (Operand A)
    output wire [7:0] uo_out,   // Dedicated outputs (Result)
    input  wire [7:0] uio_in,   // IOs: Input path (Operand B)
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // --- INTERNAL SIGNALS ---
    reg [15:0] imem [0:15];    
    reg [3:0]  pc;             
    reg [7:0]  timer;          
    
    wire [15:0] current_acc;
    wire [7:0]  alu_result;
    wire [7:0]  rf_douta, rf_doutb;
    
    // Instruction Decoding
    wire [3:0] opcode = imem[pc][15:12];
    wire [2:0] rd     = imem[pc][10:8];
    wire [2:0] ra_addr = imem[pc][6:4];
    wire [2:0] rb_addr = imem[pc][2:0];

    // Latch Logic for Dynamic Inputs
    reg [7:0] latch_a, latch_b;

    // --- HARDWARE INSTANTIATIONS ---

    regfile RF (
        .clk(clk), .rstn(rst_n), 
        .wren(timer == 8'd127), 
        .addra(ra_addr), .addrb(rb_addr), .addrdest(rd),
        .din(alu_result), .douta(rf_douta), .doutb(rf_doutb)
    );

    datapath DP (
        .clk(clk), .reset(!rst_n),
        .opcode(opcode), 
        .a((pc == 0) ? latch_a : rf_douta), // Feed latched data in first step
        .b((pc == 0) ? latch_b : rf_doutb), 
        .result(alu_result), .acc(current_acc)
    );

    // --- MAIN CONTROL LOGIC ---
    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= 0; timer <= 0;
            latch_a <= 8'h0; latch_b <= 8'h0;

            // Program: Operates on whatever was loaded into Registers
            imem[0]  <= 16'h5100; // Step 0: Capture and Store Operands
            imem[1]  <= 16'h0312; // ADD R3 = R1 + R2
            imem[2]  <= 16'h1412; // SUB R4 = R1 - R2
            imem[3]  <= 16'h2512; // MUL R5 = R1 * R2
            imem[4]  <= 16'h3012; // MAC Acc += (R1 * R2)
            imem[5]  <= 16'h8000; // STACC (Show Result)
            imem[6]  <= 16'h0000; // NOP
            imem[7]  <= 16'h0000;
        end else if (ena) begin
            if (timer < 128) begin 
                timer <= timer + 1;
                // Capture the physical pins at the very start of execution
                if (pc == 0 && timer == 0) begin
                    latch_a <= ui_in;
                    latch_b <= uio_in;
                end
            end else begin
                timer <= 0;
                if (pc < 7) pc <= pc + 1;
            end
        end
    end

    assign uo_out  = alu_result; 
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0; 

endmodule

module regfile (
    input  wire clk, rstn, wren,
    input  wire [2:0] addra, addrb, addrdest,
    input  wire [7:0] din,
    output wire [7:0] douta, doutb
);
    reg [7:0] storage [0:7];
    assign douta = storage[addra];
    assign doutb = storage[addrb];
    integer i;
    always @(posedge clk) begin
        if (!rstn) begin
            for (i=0; i<8; i=i+1) storage[i] <= 8'h0;
        end else if (wren) begin
            storage[addrdest] <= din;
        end
    end
endmodule

module datapath (
    input  wire        clk, reset,
    input  wire [3:0]  opcode,
    input  wire [7:0]  a, b,
    output reg  [7:0]  result,
    output reg  [15:0] acc
);
    always @(posedge clk) begin
        if (reset) begin
            acc <= 16'b0; result <= 8'b0;
        end else begin
            case (opcode)
                4'h0: result <= a + b;
                4'h1: result <= a - b;
                4'h2: result <= a * b;
                4'h3: acc    <= acc + (a * b);
                4'h5: result <= a;             // Pass-through for latching
                4'h8: result <= acc[7:0];
                default: result <= result;
            endcase
        end
    end
endmodule
