//============================================================================
//  Arcade: Computer Space
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
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
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S    // 1 - signed audio samples, 0 - unsigned
);

assign LED_USER  = 0;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : 8'd4;
assign HDMI_ARY = status[1] ? 8'd9  : 8'd3;

`include "build_id.v" 
localparam CONF_STR = {
	"A.COMSPC;;",
	"-;",
	"O1,Aspect ratio,4:3,16:9;",
	"O2,Color,No,Yes;",
	"-;",
	"R0,Reset;",
	"J1,Thrust,Fire,Start;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys = CLK_50M;
wire clk_5m;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_5m),
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire [64:0] ps2_key;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.ps2_key(ps2_key)
);

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'hX6B: btn_left   <= pressed; // left
			'hX74: btn_right  <= pressed; // right
			'h029: btn_thrust <= pressed; // space
			'h014: btn_fire   <= pressed; // ctrl

			'h005: btn_start  <= pressed; // F1
			// JPAC/IPAC/MAME Style Codes
			'h016: btn_start  <= pressed; // 1
		endcase
	end
end

reg btn_right = 0;
reg btn_left  = 0;
reg btn_fire  = 0;
reg btn_thrust= 0;
reg btn_start = 0;

wire m_left   = btn_left   | joy[1];
wire m_right  = btn_right  | joy[0];
wire m_thrust = btn_thrust | joy[4];
wire m_fire   = btn_fire   | joy[5];
wire m_start  = btn_start  | joy[6];

wire blank;
wire vs,hs;

assign VGA_CLK  = clk_5m;
assign VGA_CE   = 1;
assign VGA_HS   = hs;
assign VGA_VS   = vs;
assign VGA_R    = {r,r};
assign VGA_G    = {g,g};
assign VGA_B    = {b,b};
assign VGA_DE   = ~blank;

assign HDMI_CLK = VGA_CLK;
assign HDMI_CE  = 1;
assign HDMI_HS  = VGA_HS;
assign HDMI_VS  = VGA_VS;
assign HDMI_R   = VGA_R;
assign HDMI_G   = VGA_G;
assign HDMI_B   = VGA_B;
assign HDMI_DE  = VGA_DE;
assign HDMI_SL  = 0;

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

	.hsync(hs),
	.vsync(vs),
	.blank(blank),
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
	old_vs <= vs;
	
	cur_inv <= cur_inv | video[3];
	if (~old_vs & vs) {inv,cur_inv} <= {cur_inv, 1'b0};
end

endmodule
