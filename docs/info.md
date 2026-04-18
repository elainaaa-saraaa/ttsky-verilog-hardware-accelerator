<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This Hardware Accelerator is a custom 16-bit Multiply-Accumulate (MAC) engine using a 4-bit ISA and 8 registers R0 to R7. On power-up, it latches external switch values into its registers and runs a calculation loop. A 128-cycle strobe holds each result so the math is visible on LEDs.

## How to test

-Set Inputs: Set ui_in (Operand A) and uio_in (Operand B) using switches.

-Reset: Pulse rst_n low to latch your switch values.

-Run: Set ena high to start the loop.

-Observe: Monitor uo_out[7:0] for: A → B → Sum → Diff → Product → Accumulator.

## External hardware

-16 Switches: Connected to ui_in and uio_in for data input.

-8 LEDs: Connected to uo_out[7:0] to display binary results.

