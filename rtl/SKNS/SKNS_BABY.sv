module SKNS_BABY
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_F,
	input              CE_R,
	
	output             DOT_CE,
	output reg [ 8: 0] HCNT,
	output reg [ 8: 0] VCNT,
	output             HBLANK_N,
	output             VBLANK_N,
	output             VINC_PRE_N,
	output             LAST_LINE_N,
	
	output             HSPC_N,
	
	output             DCLK,
	output             HS_N,
	output             VS_N,
	output             HBL_N,
	output             VBL_N
	
`ifdef DEBUG
	                   
`endif
);

	import SKNS_PKG::*;
	
	bit          DOT_CE_R;
	
	//Video generator
	bit          CLK_RES;
	always @(posedge CLK) begin
		bit          RST_N_OLD;
	
		if (CE_R) begin
			RST_N_OLD <= RST_N;
			CLK_RES <= RST_N & ~RST_N_OLD;
		end
	end
	
	bit  [ 1: 0] DOTCLK_DIV;
	always @(posedge CLK) begin
		if (CLK_RES) begin
			DOTCLK_DIV <= '0;
		end else if (CE_R) begin
			DOTCLK_DIV <= DOTCLK_DIV + 2'd1;
		end
	end
	assign DOT_CE_R = (DOTCLK_DIV == 3) & CE_R;
	
	wire [ 8: 0] DOT_PER_LINE = 9'd455;
	wire [ 8: 0] HSYNC_START = 9'h168 /*+ HS_OFFS*/;
	wire [ 8: 0] VINC_HPOS = 9'd385;
	wire [ 8: 0] VBLK_START = 9'h0F0;
	wire [ 8: 0] VSYNC_START = 9'd246;
//	bit  [ 8: 0] HCNT;
//	bit  [ 8: 0] VCNT;
	bit          HSYNC;
	bit          VSYNC;
	bit          HBLK;
	bit          VBLK;
	bit          HSPC,VSPC;
	always @(posedge CLK) begin		
		if (CLK_RES) begin
			HCNT <= '0;
			VCNT <= '0;
			HSYNC <= 1;
			VSYNC <= 1;
			HBLK <= 0;
			VBLK <= 0;
			HSPC <= 0;
		end else if (EN) begin
			if (DOT_CE_R) begin
				HCNT <= HCNT + 9'd1;
				if (HCNT == DOT_PER_LINE - 1) begin
					HCNT <= '0;
				end
				if (HCNT == VINC_HPOS - 1) begin
					VCNT <= VCNT + 9'd1;
					if (VCNT == 9'h100) begin
						VCNT <= 9'h1F9;
					end
					
					if (VCNT == VBLK_START - 9'd1) begin
						VBLK <= 1;
					end
					if (VCNT == 9'h1FF) begin
						VBLK <= 0;
					end
				end
				
				if (HCNT == HSYNC_START - 9'h1 && VCNT == VSYNC_START - 9'd1) begin
					VSYNC <= 1;
				end
				if (HCNT == HSYNC_START + 9'd32 - 9'h1 && VCNT == VSYNC_START + 9'd3 - 1) begin
					VSYNC <= 0;
				end
				
				if (HCNT == HSYNC_START - 9'h1) begin
					HSYNC <= 1;
				end
				if (HCNT == HSYNC_START + 9'd32 - 9'h1) begin
					HSYNC <= 0;
				end
				
				if (HCNT == 9'd320 - 1) begin
					HBLK <= 1;
				end
				if (HCNT == DOT_PER_LINE - 1) begin
					HBLK <= 0;
				end
				
				
				if (HCNT == 9'd320 - 2 - 1) begin
					HSPC <= 1;
				end
				if (HCNT == DOT_PER_LINE - 2 - 1) begin
					HSPC <= 0;
					if (VCNT == VBLK_START - 9'd1) begin
						VSPC <= 1;
					end
					if (VCNT == 9'h1FF) begin
						VSPC <= 0;
					end
				end
			end
		end
	end
	
	assign DOT_CE = DOT_CE_R;
	assign HBLANK_N = ~HBLK;
	assign VBLANK_N = ~VBLK;
	assign VINC_PRE_N = ~(HCNT == VINC_HPOS - 9'd2);
	assign LAST_LINE_N = ~(VCNT == 9'h1FF);
	assign HSPC_N = ~HSPC;
	
	assign DCLK = DOTCLK_DIV[1];
	assign HS_N = ~HSYNC;
	assign VS_N = ~VSYNC;
	assign HBL_N = ~HBLK;
	assign VBL_N = ~VBLK;
	
endmodule
