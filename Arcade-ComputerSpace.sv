//============================================================================
//  Arcade: Computer Space
//
//  Port to MiSTer
//  Copyright (C) 2017-2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output [11:0] VIDEO_ARX,
	output [11:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

`ifdef USE_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

`ifdef USE_DDRAM
	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,
`endif

`ifdef USE_SDRAM
	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,
`endif

`ifdef DUAL_SDRAM
	//Secondary SDRAM
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0; 

assign LED_USER   = 0;
assign LED_DISK   = 0;
assign LED_POWER  = 0;
assign BUTTONS    = 0;
assign AUDIO_MIX  = 0;
assign VGA_F1     = 0;
assign VGA_SCALER = 0;

wire [1:0] ar = status[4:3];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.COMSPC;;",
	"-;",
	"O34,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O2,Color,No,Yes;",
	"-;",
	"R0,Reset;",
	"J1,Thrust,Fire,Start,Coin;",
	"jn,B,A,Start,R;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys = CLK_50M;
wire clk_5m, clk_vid;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_vid),
	.outclk_1(clk_5m),
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire [21:0] gamma_bus;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.gamma_bus(gamma_bus),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);

wire m_left   = joy[1];
wire m_right  = joy[0];
wire m_thrust = joy[4];
wire m_fire   = joy[5];
wire m_start  = joy[6];
wire m_coin   = joy[7];

wire HBlank, VBlank;
wire VSync, HSync;

reg ce_pix;
always @(posedge clk_vid) begin
	reg [1:0] div;

	div <= div + 1'd1;
	ce_pix <= !div;
end

arcade_video #(260,12) arcade_video
(
	.*,
	.clk_video(clk_vid),
	.RGB_in({r,g,b}),

	.forced_scandoubler(0),
	.fx(0)
);

wire [15:0] audio;
assign AUDIO_L = audio;
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 1;

computer_space_top computerspace
(
	.reset(RESET | buttons[1] | status[0] ),

	.clock_50(clk_sys),
	.game_clk(clk_5m),

	.signal_ccw(m_left),
	.signal_cw(m_right),
	.signal_thrust(m_thrust),
	.signal_fire(m_fire),
	.signal_start(m_start),
	.signal_coin(m_coin),

	.hsync(HSync),
	.vsync(VSync),
	.hblank(HBlank),
	.vblank(VBlank),
	.video(video),

	.audio(audio)
);

wire [3:0] video;

wire [5:0] rs,gs,bs, ro,go,bo, rc,gc,bc, rm,gm,bm;
wire [3:0] r,g,b;

assign {rs,gs,bs} = ~video[0] ? 18'd0 : status[2] ? {6'b0111,6'b0111,6'b0111} : {6'b0111,6'b0111,6'b0111};
assign {rc,gc,bc} = ~video[1] ? 18'd0 : status[2] ? {6'b0000,6'b1111,6'b1111} : {6'b0111,6'b0111,6'b0111};
assign {ro,go,bo} = ~video[2] ? 18'd0 : status[2] ? {6'b1111,6'b1111,6'b0000} : {6'b1111,6'b1111,6'b1111};

assign rm = rs + ro + rc;
assign gm = gs + go + gc;
assign bm = bs + bo + bc;

assign r = (rm[5:4] ? 4'b1111 : rm[3:0]) ^ {4{inv}};
assign g = (gm[5:4] ? 4'b1111 : gm[3:0]) ^ {4{inv}};
assign b = (bm[5:4] ? 4'b1111 : bm[3:0]) ^ {4{inv}};

reg inv;
always @(posedge clk_5m) begin
	reg old_vs, cur_inv;
	old_vs <= VSync;
	
	cur_inv <= cur_inv | video[3];
	if (~old_vs & VSync) {inv,cur_inv} <= {cur_inv, 1'b0};
end

endmodule
