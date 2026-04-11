<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

A state machine controlling a 5-floor elevator. It latches requests from cabin and hall buttons, moving the car sequentially.

## How to test

-Pulse any input in ui_in[4:0] (Cabin) or ui_in[7:5] / uio_in[4:0] (Hall).

-Monitor uo_out[2:0] for binary floor position.

-Observe uo_out[3] (Up), uo_out[4] (Down), and uo_out[5] (Door Open blink).

## External hardware

-LEDs: Connected to uo_out[5:0] to show floor and status.

-Buttons: Connected to ui_in and uio_in for floor calls.

-OLED: Pins uo_out[7:6] reserved for I2C monitoring.
