Firmware for a PIC16F18345-based PS/2 keyboard interface that
converts Set-2 scan codes into a ZX Spectrum keyboard matrix.
## Features
- PS/2 keyboard receiver using CLOCK falling-edge sampling
- Scan Code Set 2 make and break code handling (up to four at once)
- Configurable output mapping
- Designed for DM164141 EVALUATION BOARD (PIC16F18345)
- Built with MPLAB X 6.35 and pic-as
## Programming
DM164141 evaluation board connects to your PC as a USB Flash drive.
So copy dist/default/debug/ZX-Spectrum-PS-2-keyboard-adapter.debug.hex
into this drive and PIC16F18345 will be programmed instantly.
## Wiring
connect AT-keyboard CLOCK to RB6, connect AT-keyboard DATA to RB5,
connect ZX address lines A8-A15 to RC0-RC7 terminals on DM164141,
connect ZX data lines D0-D4 to RA0-RA2,RA4,RA5.
Don't forget to desolder 3.3V jumper pads and solder 5V ones
