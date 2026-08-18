//============================================================================
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
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off 

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,

`ifdef MISTER_FB
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

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
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

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
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
	assign {UART_RTS, UART_TXD, UART_DTR} = 0;
	assign BUTTONS   = {1'b0,osd_btn};
	assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
	assign USER_OUT = 'Z;

	assign AUDIO_S = 1;
	assign AUDIO_MIX = 2'b00;
	assign HDMI_FREEZE = 0;
	assign VGA_DISABLE = 0;
	
	assign LED_DISK  = 0;
	assign LED_POWER = 0;
	assign LED_USER  = 0;
	assign VGA_SCALER = 0;
	assign HDMI_BLACKOUT = 1;
	assign FB_FORCE_BLANK = 0;

	///////////////////////////////////////////////////
	//
	// Status Bit Map:
	//             Upper                             Lower              
	// 0         1         2         3          4         5         6   	   7         8         9
	// 01234567890123456789012345678901 23456789012345678901234567890123 45678901234567890123456789012345
	// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
	// XXXXXXXXXXXXXX  XXXX             XXXXXX
	
	`include "build_id.v"
	localparam CONF_STR = {
		"Arcade-SKNS;;",
		"-;",
		"O[16],Autosave NVRAM,Off,On;",
		"D0T[17],Save NVRAM;",
		"-;",
		"O[19:18],Pause,Off,OSD,On;",
		"-;",
		
		"DIP;",
		"-;",
	
		"P1,Audio & Video;",
		"P1O[2:1],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
		"P1O[13:11],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
		"P1-;",
	
		"P1O[4:3],Rotate,No,CCW,CW;",
		"P1O[5],Flip 180,Off,On;",
		"P1O[8:6],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer,HV-Integer;",
		"-;",
		
`ifdef DEBUG
		"O[22:20],Region,J,U,K,E,A;",
`endif

		"P2,Debug;",
		"P2O[37:33],Hsync offs,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
		"-;",

		"R0,Reset;",
		"J1,B1,B2,Start,Coin,Service;",
		"V,v",`BUILD_DATE
	};

	wire [127:0] status;
	wire [ 15:0] menumask;
	wire [  1:0] buttons;
	wire [ 31:0] joystick_0,joystick_1,joystick_2,joystick_3,joystick_4;
	wire [  7:0] joy0_x0,joy0_y0,joy0_x1,joy0_y1,joy1_x0,joy1_y0,joy1_x1,joy1_y1;
	wire         ioctl_download,ioctl_upload;
	wire         ioctl_upload_req;
	wire         ioctl_wr,ioctl_rd;
	wire [ 25:0] ioctl_addr;
	wire [ 15:0] ioctl_data,ioctl_din;
	wire [  7:0] ioctl_index;
	reg          ioctl_wait = 0;
	
	reg  [ 31:0] sd_lba = '0;
	reg          sd_rd = 0;
	reg          sd_wr = 0;
	wire         sd_ack;
	wire [  7:0] sd_buff_addr;
	wire [ 15:0] sd_buff_dout;
	wire [ 15:0] sd_buff_din0;
	wire [ 15:0] sd_buff_din = 0;
	wire         sd_buff_wr;
	wire [  1:0] img_mounted;
	wire         img_readonly;
	wire [ 63:0] img_size;
	
	wire         forced_scandoubler;
	wire         new_vmode = 0;
	wire [ 10:0] ps2_key;
	wire [ 24:0] ps2_mouse;
	wire [ 15:0] ps2_mouse_ext;
	
	wire [ 64:0] RTC;
	
	wire [ 35:0] EXT_BUS;
	
	wire [ 21:0] gamma_bus;
	wire [ 15:0] sdram_sz;
	
	hps_io #(.CONF_STR(CONF_STR), .WIDE(1)) hps_io
	(
		.clk_sys(clk_sys),
		.HPS_BUS(HPS_BUS),
	
		.joystick_0(joystick_0),
		.joystick_1(joystick_1),
		.joystick_2(joystick_2),
		.joystick_3(joystick_3),
		.joystick_4(joystick_4),
		.joystick_l_analog_0({joy0_y0, joy0_x0}),
		.joystick_l_analog_1({joy1_y0, joy1_x0}),
		.joystick_r_analog_0({joy0_y1, joy0_x1}),
		.joystick_r_analog_1({joy1_y1, joy1_x1}),
	
		.buttons(buttons),
		.forced_scandoubler(forced_scandoubler),
		.new_vmode(new_vmode),
	
		.status(status),
		.status_in(status),
		.status_set(0),
		.status_menumask(menumask),
	
		.ioctl_download(ioctl_download),
		.ioctl_index(ioctl_index),
		.ioctl_upload(ioctl_upload),
		.ioctl_upload_req(ioctl_upload_req),
		.ioctl_upload_index(8'h04),
		.ioctl_addr(ioctl_addr),
		.ioctl_dout(ioctl_data),
		.ioctl_din(ioctl_din),
		.ioctl_wr(ioctl_wr),
		.ioctl_rd(ioctl_rd),
		.ioctl_wait(ioctl_wait),
	
		.sd_lba('{sd_lba}),
		.sd_rd(sd_rd),
		.sd_wr(sd_wr),
		.sd_ack(sd_ack),
		.sd_buff_addr(sd_buff_addr),
		.sd_buff_dout(sd_buff_dout),
		.sd_buff_din('{sd_buff_din}),
		.sd_buff_wr(sd_buff_wr),
		.img_mounted(img_mounted),
		.img_readonly(img_readonly),
		.img_size(img_size),
	
		.gamma_bus(gamma_bus),
		.sdram_sz(sdram_sz),
	
		.ps2_key(ps2_key),
		.ps2_mouse(ps2_mouse),
		.ps2_mouse_ext(ps2_mouse_ext),
		
		.RTC(RTC),
	
		.EXT_BUS(EXT_BUS)
	);
	
	assign menumask = {1'b0};
	
	wire cart_download = ioctl_download & (ioctl_index[5:0] == 6'h0);
	wire bios_download = ioctl_download & (ioctl_index[5:0] == 6'h1);
	wire conf_download = ioctl_download & (ioctl_index[5:0] == 6'h2);
	wire nvram_download = ioctl_download & (ioctl_index[5:0] == 6'h4);
	wire nvram_upload = ioctl_upload & (ioctl_index[5:0] == 6'h4);
	
	reg osd_btn = 0;

	///////////////////////////////////////////////////
	wire clk_sys, clk_ram, locked;
	pll pll
	(
		.refclk(CLK_50M),
		.rst(0),
		.outclk_0(clk_sys),
		.outclk_1(clk_ram),
		.locked(locked)
	);
	
	wire reset = RESET | status[0] | buttons[1];
	
	reg rst_ram = 0, loader_rst = 0;
	reg download;
	always @(posedge clk_sys) begin
		reg [7:0] delay_cnt;
		
		download <= bios_download || cart_download;
		if (delay_cnt) delay_cnt <= delay_cnt - 8'd1;
		else rst_ram <= 0;
		
		if ((!bios_download && !cart_download && download) || reset) begin
			rst_ram <= 1;
			delay_cnt <= '1;
		end
	end
	wire rst_sys = reset | download | rst_ram | loader_rst;
	
	//[1:0]
	//[5:4] - input mode: 1,2,3 buttons
	//[6] - input mode: paddle
	reg [ 7: 0] BOARD_CONF = 8'h10;
	reg [ 7: 0] BOARD_REGION = 8'h41;
	reg [15: 0] BOARD_SPR_OFFSX = '0,BOARD_SPR_OFFSY = '0;
	always @(posedge clk_sys) begin
		if (conf_download && ioctl_wr) begin
			case (ioctl_addr[7:0])
				8'h00: {BOARD_REGION,BOARD_CONF} <= ioctl_data;
				8'h02: BOARD_SPR_OFFSX <= ioctl_data;
				8'h04: BOARD_SPR_OFFSY <= ioctl_data;
			endcase
		end
	end
	
	reg [7:0] dip_sw = '0;
	always @(posedge clk_sys) begin
		if (ioctl_wr && (ioctl_index == 8'd254) && !ioctl_addr)
			dip_sw <= ioctl_data[7:0];
	end
	
	wire [7:0] p0,p1,p2,p3,p4,p5,p6,p7,pF;
	always_comb begin
		{p0,p1,p2,p3,p4,p5,p6,p7,pF} = '1;
		if (BOARD_CONF[5:4] == 2'h0) begin //1 button
			p0 = ~{3'b000,joystick_0[4],joystick_0[0],joystick_0[1],joystick_0[2],joystick_0[3]};
			p1 = ~{3'b000,joystick_1[4],joystick_1[0],joystick_1[1],joystick_1[2],joystick_1[3]};
			p2 = ~{1'b0,1'b0,1'b0,1'b0,joystick_1[6],joystick_0[6],joystick_1[5],joystick_0[5]};
			p7 = ~{dip_sw[7:1],joystick_0[7]};
		end else if (BOARD_CONF[5:4] == 2'h1) begin //2 buttons
			p0 = ~{2'b00,joystick_0[5],joystick_0[4],joystick_0[0],joystick_0[1],joystick_0[2],joystick_0[3]};
			p1 = ~{2'b00,joystick_1[5],joystick_1[4],joystick_1[0],joystick_1[1],joystick_1[2],joystick_1[3]};
			p2 = ~{1'b0,1'b0,1'b0,1'b0,joystick_1[7],joystick_0[7],joystick_1[6],joystick_0[6]};
			p7 = ~{dip_sw[7:1],joystick_0[8]};
		end else if (BOARD_CONF[5:4] == 2'h2) begin //3 buttons
			p0 = ~{1'b0,joystick_0[6],joystick_0[5],joystick_0[4],joystick_0[0],joystick_0[1],joystick_0[2],joystick_0[3]};
			p1 = ~{1'b0,joystick_1[6],joystick_1[5],joystick_1[4],joystick_1[0],joystick_1[1],joystick_1[2],joystick_1[3]};
			p2 = ~{1'b0,1'b0,1'b0,1'b0,joystick_1[8],joystick_0[8],joystick_1[7],joystick_0[7]};
			p7 = ~{dip_sw[7:1],joystick_0[9]};
		end else begin
//			p0 = ~{joystick_0[3],joystick_0[2],joystick_0[0],joystick_0[1],joystick_0[4],joystick_0[5],1'b0,joystick_0[8]};
//			p1 = ~{joystick_1[3],joystick_1[2],joystick_1[0],joystick_1[1],joystick_1[4],joystick_1[5],1'b0,joystick_1[8]};
//			p2 = ~{joystick_0[6],joystick_0[7],2'b00,joystick_1[6],joystick_1[7],2'b00};
//			p3 = ~{1'b0,~dip_sw[6],joystick_0[10],joystick_0[11],2'b11,joystick_1[9],joystick_0[9]};
		end
	end
	
	wire [20: 0] ROM_A;
	wire [15: 0] ROM_D;
	wire         ROM_OE_N;
	wire         BIOS_CE_N;
	wire         GROM_CE_N;
	
	wire [19: 2] DRAM_A;
	wire [31: 0] DRAM_DI;
	wire [31: 0] DRAM_DO;
	wire [ 3: 0] DRAM_WE_N;
	wire         DRAM_RD_N;
	wire         DRAM_CE_N;
	
	wire         MEM_WAIT_N;
	
	wire [23: 0] SPR_ROM_A;
	wire [15: 0] SPR_ROM_D;
	wire         SPR_ROM_RD_N;
	wire         SPR_ROM_WAIT;
	
	wire [18: 1] SPR_FB0_A;
	wire [15: 0] SPR_FB0_D;
	wire [15: 0] SPR_FB0_Q;
	wire         SPR_FB0_WE;
	wire [18: 1] SPR_FB1_A;
	wire [15: 0] SPR_FB1_D;
	wire [15: 0] SPR_FB1_Q;
	wire         SPR_FB1_WE;
	
	wire [23: 0] BGA_ROM_A;
	wire [15: 0] BGA_ROM_D;
	wire         BGA_ROM_RD_N;
	wire [17: 1] BGB_RAM_A;
	wire [15: 0] BGB_RAM_WD;
	wire [ 1: 0] BGB_RAM_WE_N;
	wire         BGB_RAM_RD_N;
	wire [23: 0] BGB_ROM_A;
	wire [15: 0] BGB_ROM_D;
	wire         BGB_ROM_RD_N;
	
	wire [23: 0] SOUND_ROM_A;
	wire [ 7: 0] SOUND_ROM_D;
	wire         SOUND_ROM_RD_N;
	
	wire [12: 0] NVRAM_A;
	wire [ 7: 0] NVRAM_DO;
	wire [ 7: 0] NVRAM_DI;
	wire         NVRAM_WE_N;
	wire         NVRAM_OE_N;
	wire         NVRAM_CE_N;
	
	wire [ 7: 0] R, G, B;
	wire         HBL_N, VBL_N;
	wire         HS_N,VS_N;
	wire         DCLK;
	wire         DCE_R;
	wire [15: 0] SOUND_L;
	wire [15: 0] SOUND_R;
	
	wire [31:0] in_clk = 57272720;
	
	bit CLK_DIV;
	always @(posedge clk_sys) 
		CLK_DIV <= ~CLK_DIV;
	wire SYS_CE_R =  CLK_DIV;
	wire SYS_CE_F = ~CLK_DIV;
	
	wire YMZ_CE;	//Audio clock
	CEGen AUD_CEGen
	(
		.CLK(clk_sys),
		.RST_N(1),
		.IN_CLK(in_clk),
		.IN_CE(1),
		.OUT_CLK(16666666),
		.CE(YMZ_CE)
	);
	
	wire X32K_CE;	//RTC clock
	CEGen RTC_CEGen
	(
		.CLK(clk_sys),
		.RST_N(1),
		.IN_CLK(in_clk),
		.IN_CE(1),
		.OUT_CLK(32768),
		.CE(X32K_CE)
	);
	
	SKNS SKNS
	(
		.CLK(clk_sys),
		.RST_N(~rst_sys),
		.EN(1'b1),
		
		.SYS_CE_F(SYS_CE_F),
		.SYS_CE_R(SYS_CE_R),
		.YMZ_CE(YMZ_CE),
		.X32K_CE(X32K_CE),
		
		.RES_N(~status[0]),
		
		.ROM_A(ROM_A),
		.ROM_D(ROM_D),
		.ROM_OE_N(ROM_OE_N),
		.BIOS_CE_N(BIOS_CE_N),
		.GROM_CE_N(GROM_CE_N),
		
		.DRAM_A(DRAM_A),
		.DRAM_DI(DRAM_DI),
		.DRAM_DO(DRAM_DO),
		.DRAM_WE_N(DRAM_WE_N),
		.DRAM_RD_N(DRAM_RD_N),
		.DRAM_CE_N(DRAM_CE_N),
		
		.MEM_WAIT_N(MEM_WAIT_N),
		
		.SPR_ROM_A(SPR_ROM_A),
		.SPR_ROM_D(SPR_ROM_D),
		.SPR_ROM_RD_N(SPR_ROM_RD_N),
		.SPR_ROM_WAIT(SPR_ROM_WAIT),
		
		.SPR_FB0_A(SPR_FB0_A),
		.SPR_FB0_D(SPR_FB0_D),
		.SPR_FB0_Q(SPR_FB0_Q),
		.SPR_FB0_WE(SPR_FB0_WE),
		.SPR_FB1_A(SPR_FB1_A),
		.SPR_FB1_D(SPR_FB1_D),
		.SPR_FB1_Q(SPR_FB1_Q),
		.SPR_FB1_WE(SPR_FB1_WE),
		
		.BGA_ROM_A(BGA_ROM_A),
		.BGA_ROM_D(BGA_ROM_D),
		.BGA_ROM_RD_N(BGA_ROM_RD_N),
		
		.BGB_RAM_A(BGB_RAM_A),
		.BGB_RAM_WD(BGB_RAM_WD),
		.BGB_RAM_WE_N(BGB_RAM_WE_N),
		.BGB_RAM_RD_N(BGB_RAM_RD_N),
		.BGB_ROM_A(BGB_ROM_A),
		.BGB_ROM_D(BGB_ROM_D),
		.BGB_ROM_RD_N(BGB_ROM_RD_N),
		
		.SOUND_ROM_A(SOUND_ROM_A),
		.SOUND_ROM_D(SOUND_ROM_D),
		.SOUND_ROM_RD_N(SOUND_ROM_RD_N),
		
		.NVRAM_A(NVRAM_A),
		.NVRAM_DO(NVRAM_DO),
		.NVRAM_DI(NVRAM_DI),
		.NVRAM_WE_N(NVRAM_WE_N),
		.NVRAM_OE_N(NVRAM_OE_N),
		.NVRAM_CE_N(NVRAM_CE_N),
		
		.R(R),
		.G(G),
		.B(B),
		.DCLK(DCLK),
		.VS_N(VS_N),
		.HS_N(HS_N),
		.HBL_N(HBL_N),
		.VBL_N(VBL_N),
		
		.SOUND_L(SOUND_L),
		.SOUND_R(SOUND_R),
		
		.P0(p0),
		.P1(p1),
		.P2(p2),
		.P3(p3),
		.P4(p4),
		.P5(p5),
		.P6(p6),
		.P7(p7),
		.REGION(BOARD_REGION),
		.SPR_OFFSX(BOARD_SPR_OFFSX[9:0]),
		.SPR_OFFSY(BOARD_SPR_OFFSY[9:0]),
		
		.SCRN_EN(SCRN_EN),
		.SND_EN(SND_EN)
		
`ifdef DEBUG
		,
		.DBG_EXT(DBG_EXT),
		.DBG_PAUSE(DBG_BREAK)
`endif
	);

	assign AUDIO_L = SOUND_L;
	assign AUDIO_R = SOUND_R;

	
	//Sprite/BG/Sound ROM
	wire        sdr_rdy;
	wire [15:0] sdr_dout1,sdr_dout2,sdr_dout3;
	wire [15:0] sdr_dout4;
	sdram1 sdram1
	(
		.SDRAM_CLK(SDRAM_CLK),
		.SDRAM_A(SDRAM_A),
		.SDRAM_BA(SDRAM_BA),
		.SDRAM_DQ(SDRAM_DQ),
		.SDRAM_DQML(SDRAM_DQML),
		.SDRAM_DQMH(SDRAM_DQMH),
		.SDRAM_nCS(SDRAM_nCS),
		.SDRAM_nWE(SDRAM_nWE),
		.SDRAM_nRAS(SDRAM_nRAS),
		.SDRAM_nCAS(SDRAM_nCAS),
		.SDRAM_CKE(SDRAM_CKE),
		
		.clk(clk_ram),
		.init(status[0]),
		.init_done(sdr_rdy),
		.sync(loader_exec ? sdr_rom_wr : DCLK),
	
		.waddr(sdr_rom_addr),
		.wr  (loader_exec),
		.din (sdr_rom_data),
		
		.raddr1(SPR_ROM_A),
		.rd1   (1'b0/*~SPR_ROM_RD_N*/),
		.dout1 (sdr_dout1),
		
		.raddr2(BGA_ROM_A[23:1]),
		.rd2   (~BGA_ROM_RD_N),
		.dout2 (sdr_dout2),
		
		.raddr3(BGB_ROM_A[23:1]),
		.rd3   (~BGB_ROM_RD_N),
		.dout3 (sdr_dout3),
		
		.raddr4(SOUND_ROM_A[23:1]),
		.rd4   (~SOUND_ROM_RD_N),
		.dout4 (sdr_dout4),
		
		.addr5 (BGB_RAM_A),
		.din5  (BGB_RAM_WD),
		.we5   (~BGB_RAM_WE_N),
		.rd5   (~BGB_RAM_RD_N)
	);
	assign SPR_ROM_D = SPR_ROM_A[2:1] == 2'b00 ? ddr_rom_do[63:48] :
	                   SPR_ROM_A[2:1] == 2'b01 ? ddr_rom_do[47:32] :
							 SPR_ROM_A[2:1] == 2'b10 ? ddr_rom_do[31:16] :
							                           ddr_rom_do[15: 0];
	assign SPR_ROM_WAIT = ddr_rom_busy;
	assign {BGA_ROM_D,BGB_ROM_D} = {sdr_dout2,sdr_dout3};
	assign SOUND_ROM_D = !SOUND_ROM_A[0] ? sdr_dout4[15:8] : sdr_dout4[7:0];

	//BIOS/Game ROM, DRAM
	reg  [ 3: 0] loader_state = 0;	
	reg          loader_exec = 0;
	reg  [26: 3] ddr_rom_addr;
	reg  [63: 0] ddr_rom_do;
	reg          ddr_rom_rd;
	wire         ddr_rom_busy;
	reg  [26: 3] sdr_rom_addr;
	reg  [63: 0] sdr_rom_data;
	reg          sdr_rom_wr;
	reg  [12: 1] eeprom_addr;
	reg  [15: 0] eeprom_data;
	reg          eeprom_wr;
	always @(posedge clk_sys) begin				
		ioctl_wait <= (bios_download && bios_busy);
		
		if (conf_download || status[0]) begin
			ddr_rom_addr <= '0;
			ddr_rom_rd <= 0;
			sdr_rom_addr <= '0;
			sdr_rom_wr <= 0;
			eeprom_addr <= '0;
			eeprom_wr <= 0;
			loader_state = 4'd1;
			loader_exec <= 0;
			loader_rst <= 1;
		end
		else if (sdr_rdy) begin
			ddr_rom_rd <= 0;
			sdr_rom_wr <= 0;
			eeprom_wr <= 0;
			case (loader_state)
				4'd0: begin
					loader_exec <= 0;
				end
				
				4'd1: begin
					ddr_rom_rd <= 1;
					loader_exec <= 1;
					loader_state = 4'd2;
				end
				
				4'd2: if (!ddr_rom_busy) begin
					sdr_rom_data <= ddr_rom_do;
					sdr_rom_wr <= 1;
					ddr_rom_addr <= ddr_rom_addr + 1'd1;
					ddr_rom_rd <= 1;
					loader_state = 4'd3;
				end
				
				4'd3,4'd4,4'd5,4'd6,4'd7,4'd8: begin
					loader_state = loader_state + 4'd1;
				end
				
				4'd9: begin
					sdr_rom_addr <= sdr_rom_addr + 1'd1;
					if (ddr_rom_addr == (27'h4000000>>3)) begin
//						if (nvram_load_skip) begin
							loader_state = 4'd0; 
							loader_rst <= 0;
//						end else begin
//							loader_state = 4'd10; 
//						end
					end
					else  begin
						loader_state = 4'd2;
					end
				end
				
				4'd10: if (!ddr_rom_busy) begin
					ddr_rom_addr <= 27'h4C00000>>3;
					ddr_rom_rd <= 1;
					loader_state = 4'd11;
				end
				
				4'd11: if (!ddr_rom_busy) begin
					eeprom_data <= ddr_rom_do[63:48];
					eeprom_wr <= 1;
					loader_state = 4'd12;
				end
				
				4'd12: begin
					eeprom_addr <= eeprom_addr + 1'd1;
					eeprom_data <= ddr_rom_do[47:32];
					eeprom_wr <= 1;
					loader_state = 4'd13;
				end
				
				4'd13: begin
					eeprom_addr <= eeprom_addr + 1'd1;
					eeprom_data <= ddr_rom_do[31:16];
					eeprom_wr <= 1;
					loader_state = 4'd14;
				end
				
				4'd14: begin
					eeprom_addr <= eeprom_addr + 1'd1;
					eeprom_data <= ddr_rom_do[15:0];
					eeprom_wr <= 1;
					ddr_rom_addr <= ddr_rom_addr + 1'd1;
					ddr_rom_rd <= 1;
					loader_state = 4'd15;
				end
				
				4'd15: begin
					eeprom_addr <= eeprom_addr + 1'd1;
					if (ddr_rom_addr[6:3] == 4'h0) begin
						loader_state = 4'd0; 
						loader_rst <= 0;
					end
					else  begin
						loader_state = 4'd11;
					end
				end
			endcase
			
		end
	end
	
	wire [ 7:0] brom_do;
	wire [15:0] grom_do;
	wire [31:0] dram_do;
	wire        dram_busy,brom_busy,grom_busy,bios_busy;
	ddram ddram
	(
		.*,
		.clk(clk_ram),
		.rst(reset || rst_ram),
		
		//CPU bus (DRAM)
		.dram_addr(DRAM_A[19:2]),
		.dram_din (DRAM_DO),
		.dram_wr  (~{4{DRAM_CE_N}} & ~DRAM_WE_N),
		.dram_rd  (~DRAM_CE_N & ~DRAM_RD_N),
		.dram_dout(dram_do),
		.dram_busy(dram_busy),
	
		//CPU bus (BIOS ROM)
		.brom_addr(ROM_A[19:0]),
		.brom_rd  (~BIOS_CE_N & ~ROM_OE_N),
		.brom_dout(brom_do),
		.brom_busy(brom_busy),
	
		//CPU bus (Game ROM)
		.grom_addr(ROM_A[20:1]),
		.grom_rd  (~GROM_CE_N & ~ROM_OE_N),
		.grom_dout(grom_do),
		.grom_busy(grom_busy),
	
		//BIOS/Game ROM load
		.bios_addr(ioctl_addr[20:1]),
		.bios_din ({ioctl_data[7:0],ioctl_data[15:8]}),
		.bios_wr  ({2{bios_download & ioctl_wr}}),
		.bios_busy(bios_busy),
	
		//GFX/Sound ROM,EEPROM loader
		.rom_addr(loader_exec ? ddr_rom_addr : {3'b000,SPR_ROM_A[23:3]}),
		.rom_rd  (loader_exec ? ddr_rom_rd : ~SPR_ROM_RD_N),
		.rom_dout(ddr_rom_do),
		.rom_busy(ddr_rom_busy),
	
		//FB
		.fb_addr(fb_addr),
		.fb_din (fb_data),
		.fb_we  ({8{fb_we}}&fb_be),
		.fb_busy(fb_busy)
	);

	assign DRAM_DI = dram_do;
	assign ROM_D = !BIOS_CE_N ? {8'h00,brom_do} : grom_do;
	assign MEM_WAIT_N = (OSD_STATUS && status[18]) || status[19] ? 1'b0 :
	                    !DRAM_CE_N ? ~dram_busy : 
							  !BIOS_CE_N ? ~brom_busy : ~grom_busy;
							  
	//Sprite FB
	wire         FB0_EXT_SEL = SPR_FB0_A[9:1] >= 9'd320 || SPR_FB0_A[18:10] >= 9'd256;
	wire         FB1_EXT_SEL = SPR_FB1_A[9:1] >= 9'd320 || SPR_FB1_A[18:10] >= 9'd256;
	wire [17: 1] FB0_A = {SPR_FB0_A[9:1],SPR_FB0_A[17:10]};
	wire [17: 1] FB1_A = {SPR_FB1_A[9:1],SPR_FB1_A[17:10]};
	wire [15: 0] FB0_Q,FB1_Q;
	
	spc_fb_320x256x16 spc_fb0
	(
		.clock(clk_sys),
		.address(FB0_A),
		.data(SPR_FB0_D),
		.wren(SPR_FB0_WE & ~FB0_EXT_SEL),
		.q(FB0_Q)
	);

	spc_fb_320x256x16 spc_fb1
	(
		.clock(clk_sys),
		.address(FB1_A),
		.data(SPR_FB1_D),
		.wren(SPR_FB1_WE & ~FB1_EXT_SEL),
		.q(FB1_Q)
	);
	assign SPR_FB0_Q = !FB0_EXT_SEL ? FB0_Q : '0;
	assign SPR_FB1_Q = !FB1_EXT_SEL ? FB1_Q : '0;
	
	//NVRAM
	wire [15: 0] nvram_q;
	dpram_dif #(13,8,12,16," ") nvram
	(
		.clock(clk_sys),

		.address_a(NVRAM_A),
		.data_a(NVRAM_DO),
		.wren_a(~NVRAM_WE_N & ~NVRAM_CE_N),
		.q_a(NVRAM_DI),

		.address_b(nvram_download || nvram_upload ? ioctl_addr[12:1] : eeprom_addr),
		.data_b(nvram_download || nvram_upload ? ioctl_data : eeprom_data),
		.wren_b(nvram_download || nvram_upload ? ioctl_wr : eeprom_wr),
		.q_b(nvram_q)
	);
	
	reg nvram_save_req;	
	always @(posedge clk_sys) begin
		if (reset) begin
			nvram_save_req <= 0;
		end else begin
			if (nvram_upload) begin
				nvram_save_req <= 0;
			end else if (!NVRAM_WE_N && !NVRAM_CE_N) begin
				nvram_save_req <= 1;
			end
		end
	end

	assign ioctl_upload_req = (status[16] && nvram_save_req) || status[17];
	assign ioctl_din = (ioctl_index == 8'h04) ? nvram_q : '0;

/////////////////////////  Video  /////////////////////////////
	wire [1:0] ar = status[2:1];
	wire [2:0] scale = status[8:6];
	wire [2:0] sd = '0;//status[13:11];
	wire [2:0] sl = sd ? sd - 1'd1 : 3'd0;
	wire       scandoubler = 0;//(sd || forced_scandoubler);
	
	wire [1:0] rotate_sel = status[4:3];
	wire       rotate_en  = (rotate_sel != 2'd0);
	wire       rotate_ccw = (rotate_sel == 2'd1);
	wire       flip_180   = status[5];
	
	assign CLK_VIDEO = clk_sys;
	assign VGA_F1 = 0;
	assign VGA_SL = sl[1:0];

	reg DCE;
	always @(posedge clk_sys) begin
		reg [1:0] DCLK_old;
		
		DCLK_old[1] <= DCLK_old[0];
		DCLK_old[0] <= DCLK;
		DCE <= ~DCLK_old[0] & DCLK_old[1];
	end
	wire ce_pix = DCE;
	
	wire [11:0] orig_arx = (/*V240 ? (12'd4<<two_screen) :*/ (12'd10));
	wire [11:0] orig_ary = (/*V240 ? 12'd3               :*/ 12'd7);
	wire [11:0] arx = (!ar) ? (rotate_en ? orig_ary : orig_arx) : (ar - 1'd1);
	wire [11:0] ary = (!ar) ? (rotate_en ? orig_arx : orig_ary) : 12'd0;
	
	wire vga_de;
	video_freak video_freak
	(
		.CLK_VIDEO(CLK_VIDEO),
		.CE_PIXEL(CE_PIXEL),
		.VGA_VS(VGA_VS),
		.HDMI_WIDTH(HDMI_WIDTH),
		.HDMI_HEIGHT(HDMI_HEIGHT),
		.VGA_DE(VGA_DE),
		.VIDEO_ARX(VIDEO_ARX),
		.VIDEO_ARY(VIDEO_ARY),
		.VGA_DE_IN(vga_de),
		.ARX(arx),
		.ARY(ary),
		.CROP_SIZE(12'd0),
		.CROP_OFF(5'd0),
		.SCALE(scale) 
	);
	
	wire [31: 3] fb_addr;
	wire [63: 0] fb_data;
	wire         fb_we;
	wire [ 7: 0] fb_be;
	wire         fb_busy;
	screen_rotate_two screen_rotate_two
	(
		.CLK_VIDEO     (CLK_VIDEO),
		.CE_PIXEL      (ce_pix),

		.VGA_R         (VGA_R),
		.VGA_G         (VGA_G),
		.VGA_B         (VGA_B),
		.VGA_HS        (VGA_HS),
		.VGA_VS        (VGA_VS),
		.VGA_DE        (vga_de),

		.rotate_ccw    (rotate_ccw),
		.no_rotate     (~rotate_en),
		.flip          (flip_180),
		.two_screen    (1'b0),
		.video_rotated (),
		

		.FB_EN         (FB_EN),
		.FB_FORMAT     (FB_FORMAT),
		.FB_WIDTH      (FB_WIDTH),
		.FB_HEIGHT     (FB_HEIGHT),
		.FB_BASE       (FB_BASE),
		.FB_STRIDE     (FB_STRIDE),
		.FB_VBL        (FB_VBL),
		.FB_LL         (FB_LL),

		.DDRAM_CLK     (),
		.DDRAM_BUSY    (fb_busy),
		.DDRAM_BURSTCNT(),
		.DDRAM_ADDR    (fb_addr),
		.DDRAM_DIN     (fb_data),
		.DDRAM_BE      (fb_be),
		.DDRAM_WE      (fb_we),
		.DDRAM_RD      ()
	);

	video_mixer #(.LINE_LENGTH(8), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
	(
		.*,
	
		.ce_pix(ce_pix),	
		.scandoubler(scandoubler),
		.hq2x(sd == 3'h1),	
		.freeze_sync(),
	
		.VGA_DE(vga_de),
		.R(R),
		.G(G),
		.B(B),
	
		// Positive pulses.
		.HSync(~HS_N), 
		.VSync(~VS_N),  
		.HBlank(~HBL_N),
		.VBlank(~VBL_N) 
	);


	//debug
	reg  [ 5: 0] SCRN_EN = 6'b111111;
	reg  [ 2: 0] SND_EN = 3'b111;
	reg          DBG_PAUSE = 0;
	reg          DBG_BREAK = 0;
	reg          DBG_RUN = 0;
	
	reg  [ 7: 0] DBG_EXT = '0;
`ifdef DEBUG
	
	wire         pressed = ps2_key[9];
	wire [ 8: 0] code    = ps2_key[8:0];
	always @(posedge clk_sys) begin
		reg old_state = 0, VBL_N_OLD;
		
		VBL_N_OLD <= VBL_N;
		
		if (VBL_N && !VBL_N_OLD) begin
			if (DBG_PAUSE && !DBG_BREAK) DBG_BREAK <= 1;
			else if ((DBG_RUN || !DBG_PAUSE) && DBG_BREAK) DBG_BREAK <= 0;
			DBG_RUN <= 0;
		end
		
		DBG_EXT <= '0;
		
		old_state <= ps2_key[10];
		if((ps2_key[10] != old_state) && pressed) begin
			casex(code)
				'h005: begin SCRN_EN[0] <= ~SCRN_EN[0]; end 	// F1
				'h006: begin SCRN_EN[1] <= ~SCRN_EN[1]; end 	// F2
				'h004: begin SCRN_EN[2] <= ~SCRN_EN[2]; end 	// F3
				'h00C: begin SCRN_EN[3] <= ~SCRN_EN[3]; end 	// F4
				'h003: begin SCRN_EN[4] <= ~SCRN_EN[4]; end 	// F5
				'h00B: begin SCRN_EN[5] <= ~SCRN_EN[5]; end 	// F6
				'h083: begin SND_EN[0] <= ~SND_EN[0]; end 	// F7
				'h00A: begin SND_EN[1] <= ~SND_EN[1]; end 	// F8
				'h001: begin SND_EN[2] <= ~SND_EN[2]; end 	// F9
				'h009: begin SCRN_EN <= '1; SND_EN <= '1; DBG_EXT <= '0; end 	// F10
//				'h078: begin DBG_BREAK <= ~DBG_BREAK; end 	// F11
				'h078: begin DBG_RUN <= 1; end 	// F11
				'h177: begin DBG_PAUSE <= ~DBG_PAUSE; end 	// Pause
			endcase
		end
		
		if(pressed) begin
			casex(code)
				'h016: begin DBG_EXT[0] <= 1; end 	// 1
				'h01E: begin DBG_EXT[1] <= 1; end 	// 2
				'h026: begin DBG_EXT[2] <= 1; end 	// 3
				'h025: begin DBG_EXT[3] <= 1; end 	// 4
				'h02E: begin DBG_EXT[4] <= 1; end 	// 5
				'h036: begin DBG_EXT[5] <= 1; end 	// 6
				'h03D: begin DBG_EXT[6] <= 1; end 	// 7
				'h03E: begin DBG_EXT[7] <= 1; end 	// 8
				default:;
			endcase
		end
	end
`endif

endmodule
