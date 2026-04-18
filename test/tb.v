`default_nettype none
`timescale 1ns / 1ps

module tb ();

  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Updated Instantiation Name
  tt_um_hardware_accelerator user_project (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (ui_in),   
      .uo_out (uo_out),  
      .uio_in (uio_in),  
      .uio_out(uio_out), 
      .uio_oe (uio_oe),  
      .ena    (ena),     
      .clk    (clk),     
      .rst_n  (rst_n)    
  );

  initial begin 
    clk = 0; 
    forever #5 clk = ~clk; 
  end

  initial begin
    ui_in  = 8'h0;
    uio_in = 8'h0;
    ena    = 1'b1;
    
    rst_n  = 1'b0;      
    #100;           
    rst_n  = 1'b1;  
    
    #30000;         
    
    $display("Simulation Finished. Check uo_out for the staircase.");
    $finish;
  end

endmodule
