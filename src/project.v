/*
 * Copyright (c) 2024 Team Trinity
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_hardware_accelerator (
    input  wire [7:0] ui_in,    // Operand A
    output wire [7:0] uo_out,   // Result
    input  wire [7:0] uio_in,   // Operand B
    output wire [7:0] uio_out,  // Unused
    output wire [7:0] uio_oe,   // Set to 0 for input mode
    input  wire       ena,      
    input  wire       clk,      
    input  wire       rst_n     
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

    // --- HARDWARE INSTANTIATIONS ---

    regfile RF (
        .clk(clk), 
        .rstn(rst_n), 
        .wren(timer == 8'd127), 
        .force_w(pc == 0 && timer == 0), // Capture switches at start
        .din_a(ui_in), 
        .din_b(uio_in),
        .addra(ra_addr), 
        .addrb(rb_addr), 
        .addrdest(rd),
        .din(alu_result), 
        .douta(rf_douta), 
        .doutb(rf_doutb)
    );

    datapath DP (
        .clk(clk), 
        .reset(!rst_n),
        .opcode(opcode), 
        .a(rf_douta), 
        .b(rf_doutb), 
        .result(alu_result), 
        .acc(current_acc)
    );

    // --- MAIN CONTROL LOGIC ---
    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= 0; 
            timer <= 0;
            // The Program Sequence
            imem[0]  <= 16'h0000; // NOP (Allow 1 cycle for latching)
            imem[1]  <= 16'h0312; // R3 = R1 + R2
            imem[2]  <= 16'h1412; // R4 = R1 - R2
            imem[3]  <= 16'h2512; // R5 = R1 * R2
            imem[4]  <= 16'h3012; // Acc += R1 * R2
            imem[5]  <= 16'h8000; // Output Accumulator
            imem[6]  <= 16'h0000; // End
            imem[7]  <= 16'h0000;
        end else if (ena) begin
            if (timer < 128) begin 
                timer <= timer + 1;
            end else begin
                timer <= 0;
                if (pc < 7) pc <= pc + 1;
            end
        end
    end

    // Pin Assignments
    assign uo_out  = alu_result; 
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0; // All bidirectional pins are inputs

endmodule

// --- SUB-MODULE: REGISTER FILE ---
module regfile (
    input  wire clk, rstn, wren, force_w,
    input  wire [7:0] din_a, din_b,
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
        end else if (force_w) begin
            storage[1] <= din_a; // Latch Operand A into R1
            storage[2] <= din_b; // Latch Operand B into R2
        end else if (wren) begin
            storage[addrdest] <= din;
        end
    end
endmodule

// --- SUB-MODULE: DATAPATH ---
module datapath (
    input  wire        clk, reset,
    input  wire [3:0]  opcode,
    input  wire [7:0]  a, b,
    output reg  [7:0]  result,
    output reg  [15:0] acc
);
    always @(posedge clk) begin
        if (reset) begin
            acc <= 16'b0; 
            result <= 8'b0;
        end else begin
            case (opcode)
                4'h0: result <= a + b;
                4'h1: result <= a - b;
                4'h2: result <= a * b;
                4'h3: acc    <= acc + (a * b);
                4'h8: result <= acc[7:0];
                default: result <= result;
            endcase
        end
    end
endmodule
