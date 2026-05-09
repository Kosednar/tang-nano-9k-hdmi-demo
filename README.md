# Tang Nano 9K HDMI 720p60 Demo

This project is a Tang Nano 9K HDMI reference design that generates a 1280x720 @ 60 Hz HDMI display using the Gowin FPGA toolchain.

The demo shows a visual comparison between a simple PLL-style timing reference and Joseph F. Kosednar's patented phase-engine concept when the displayed duty cycle is swept from 40/60 to 60/40.

## Important Gowin Device Setting

Use:

**GW1NR-9, Device Version C**

Using the wrong device version may cause a device ID error when programming the Tang Nano 9K.

## Project Notes

- Board: Sipeed Tang Nano 9K
- FPGA family: Gowin GW1NR-9
- Video mode: 1280x720 @ 60 Hz
- Pixel clock: 74.25 MHz
- TMDS serializer clock: 371.25 MHz
- HDMI output is generated with explicit OSER/ELVDS-style output logic.

## Patent / IP Notice

This HDMI demonstration code is provided only as a Tang Nano 9K HDMI reference design and visual display example.

Joseph F. Kosednar's patented AC phase-control / phase-engine intellectual property is NOT included in this source code. Any on-screen reference to the patent or phase engine is for demonstration and labeling purposes only.

This code does not grant any license, rights, or permission to use, reproduce, implement, or derive from the patented phase-engine IP.

## Credits

Coded by ChatGPT with substantial human direction, testing, correction, and hardware verification by Joseph F. Kosednar.

Date: 5/9/2026