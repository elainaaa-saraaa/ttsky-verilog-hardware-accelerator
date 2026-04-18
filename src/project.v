/*
 * Copyright (c) 2024 Team Trinity
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_hardware_accelerator (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // --- INTERNAL SIGNALS ---
    reg [15:0] imem [0:15];    // 16-bit Instruction Memory
    reg [3:0]  pc;             // Program Counter
    reg [7:0]  timer;          // Strobe timer for waveform visibility
    
    // Interconnect Wires
    wire [15:0] current_acc;
    wire [7:0]  alu_result;
    wire [7:0]  rf_douta, rf_doutb;
    wire [3:0]  opcode = imem[pc][15:12];
    wire [2:0]  rd      = imem[pc][10:8];
    wire [2:0]  ra_addr = imem[pc][6:4];
    wire [2:0]  rb_addr = imem[pc][2:0];
    wire [7:0]  imm     = imem[pc][7:0];

    // --- HARDWARE INSTANTIATIONS ---

    // Register File (R0-R7)
    regfile RF (
        .clk(clk), .rstn(rst_n), 
        .wren(timer == 8'd127), // Commit result at end of strobe
        .addra(ra_addr), .addrb(rb_addr), .addrdest(rd),
        .din(alu_result), .douta(rf_douta), .doutb(rf_doutb)
    );

    // Execution Unit (ALU + 16-bit MAC)
    datapath DP (
        .clk(clk), .reset(!rst_n),
        .opcode(opcode), .a(rf_douta), .b((opcode == 4'h4) ? imm : rf_doutb),
        .result(alu_result), .acc(current_acc)
    );

    // --- MAIN CONTROL LOGIC ---
    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= 0; timer <= 0;
            // PRE-LOADED ACCELERATOR PROGRAM
            imem[0]  <= 16'h410A; // LOAD R1, 10
            imem[1]  <= 16'h4205; // LOAD R2, 5
            imem[2]  <= 16'h0312; // ADD R3 = 15
            imem[3]  <= 16'h5300; // STORE R3
            imem[4]  <= 16'h1412; // SUB R4 = 5
            imem[5]  <= 16'h5400; // STORE R4
            imem[6]  <= 16'h2512; // MUL R5 = 50
            imem[7]  <= 16'h5500; // STORE R5
            imem[8]  <= 16'h4640; // LOAD R6, 64
            imem[9]  <= 16'h5600; // STORE R6
            imem[10] <= 16'h3012; // MAC Acc = 50
            imem[11] <= 16'h8000; // STACC (Show 50)
            imem[12] <= 16'h3012; // MAC Acc = 100
            imem[13] <= 16'h8000; // STACC (Show 100)
            imem[14] <= 16'h0000; 
            imem[15] <= 16'h0000;
        end else if (ena) begin
            // Human-visible delay loop
            if (timer < 128) begin 
                timer <= timer + 1;
            end else begin
                timer <= 0;
                if (pc < 15) pc <= pc + 1;
            end
        end
    end

    // --- OUTPUT ASSIGNMENTS ---
    assign uo_out  = alu_result; 
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0; 

endmodule

// --- SUB-MODULE: REGISTER FILE ---
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
            for (i=0; i<8; i=i+1) storage[i] <= 8'h00;
        end else if (wren) begin
            storage[addrdest] <= din;
        end
    end
endmodule

// --- SUB-MODULE: DATAPATH (ALU & 16-bit ACC) ---
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
                4'h6: result <= a << b[2:0];
                4'h4: result <= b;
                4'h5: result <= a;
                4'h8: result <= acc[7:0];
                default: result <= result;
            endcase
        end
    end
endmodule
