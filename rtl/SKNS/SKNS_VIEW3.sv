module SKNS_VIEW3
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_F,
	input              CE_R,
	
	input              RES_N,
	
	input      [14: 2] A,
	input      [31: 0] DI,
	output     [31: 0] DO,
	input              RD_N,
	input      [ 3: 0] WE_N,
	input      [ 1: 0] CE,
	output             WAIT_N,
	
	input              DOT_CE,
	input      [ 8: 0] HCNT,
	input      [ 8: 0] VCNT,
	output             BG1_RENDER,
	
	output     [23: 0] BG0_ROM_A,
	input      [15: 0] BG0_ROM_D,
	output             BG0_ROM_RD_N,
	
	output     [23: 0] BG1_ROM_A,
	input      [15: 0] BG1_ROM_D,
	output             BG1_ROM_RD_N,
	
	output     [17: 0] BG0_PIX,
	output     [17: 0] BG1_PIX,
	
	input      [ 2: 0] SCRN_EN
	
`ifdef DEBUG
	                   ,
	output     [10: 0] DBG_BG0_ROW_SX,DBG_BG0_ROW_SY,DBG_BG1_ROW_SX,DBG_BG1_ROW_SY,
	output             DBG_BG0_BPP,DBG_BG1_BPP
`endif
);

	import SKNS_PKG::*;

	bit  [31: 0] VREG[32];
	
	wire         IO_VREG_SEL   = (CE == 2'b00);
	wire         IO_TILE_SEL   = (CE == 2'b01);
	wire         IO_SCROLL_SEL = (CE == 2'b10);
	
	bit          WE_N_OLD;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			VREG <= '{32{'0}};
		end else if (EN) begin
			if (CE_R) begin
				WE_N_OLD <= &WE_N;
				if (IO_VREG_SEL && !(&WE_N) && WE_N_OLD) begin
					if (!WE_N[3]) VREG[A[6:2]][31:24] <= DI[31:24];
					if (!WE_N[2]) VREG[A[6:2]][23:16] <= DI[23:16];
					if (!WE_N[1]) VREG[A[6:2]][15: 8] <= DI[15: 8];
					if (!WE_N[0]) VREG[A[6:2]][ 7: 0] <= DI[ 7: 0];
				end
			end
		end
	end
	assign DO = IO_VREG_SEL ? VREG[A[6:2]] : 
					IO_TILE_SEL ? IO_TILE_RAM_Q :
					IO_SCROLL_SEL ? IO_SCROLL_RAM_Q :
					'0;
	assign WAIT_N = 1;
	
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
	
//	wire [ 8: 0] DOT_PER_LINE = 9'd455;
//	bit  [ 8: 0] HCNT;
//	bit  [ 8: 0] VCNT;
//	always @(posedge CLK) begin		
//		if (CLK_RES) begin
//			HCNT <= '0;
//			VCNT <= '0;
//		end else if (EN) begin
//			if (DOT_CE) begin
//				HCNT <= HCNT + 9'd1;
//				if (HCNT == DOT_PER_LINE - 1) begin
//					HCNT <= '0;
//					
//					VCNT <= VCNT + 9'd1;
//					if (VCNT == 9'h100) begin
//						VCNT <= 9'h1F9;
//					end
//				end
//			end
//		end
//	end

	//BG
	wire         BG_FETCH_TIME = (HCNT >= 9'h1C2 & (VCNT == 9'h1FF | VCNT <= 9'h0EE)) | (HCNT <= 9'h13B && VCNT <= 9'h0EF);
	
	wire         BG_EN[2] = '{VREG[4][0],VREG[13][0]};
	wire         BG_PRIL[2] = '{VREG[4][1],VREG[13][1]};
	wire         BG_SCRL_MODE[2] = '{VREG[3][1],VREG[3][9]};
	wire         BG_BPP[2] = '{VREG[3][0],VREG[3][8]};
	wire [18: 0] BG_START_X[2] = '{VREG[7][18:0],VREG[16][18:0]};
	wire [18: 0] BG_START_Y[2] = '{VREG[8][18:0],VREG[17][18:0]};
	wire [18: 0] BG_ROW_INCX[2] = '{VREG[9][18:0],VREG[18][18:0]};
	wire [18: 0] BG_ROW_INCY[2] = '{VREG[10][18:0],VREG[19][18:0]};
	wire [18: 0] BG_COL_INCX[2] = '{VREG[11][18:0],VREG[20][18:0]};
	wire [18: 0] BG_COL_INCY[2] = '{VREG[12][18:0],VREG[21][18:0]};
	
	bit  [12: 0] TILE_ADDR;
	bit  [31: 0] IO_TILE_RAM_Q,TILE_RAM_Q;
	SKNS_TILE_RAM TILE_RAM(CLK, A[14:2], DI, ~WE_N & {4{IO_TILE_SEL & WE_N_OLD & CE_R}}, IO_TILE_RAM_Q, TILE_ADDR, TILE_RAM_Q);
	
	bit  [12: 0] SCROLL_ADDR = '0;
	bit  [31: 0] IO_SCROLL_RAM_Q,SCROLL_RAM_Q;
	SKNS_TILE_RAM SCROLL_RAM(CLK, A[14:2], DI, ~WE_N & {4{IO_SCROLL_SEL & WE_N_OLD & CE_R}}, IO_SCROLL_RAM_Q, SCROLL_ADDR, SCROLL_RAM_Q);
	
	//Cycle 0
	bit  [ 8: 0] BG_X;
	BGCoord_t    BG_ROW_SX[2],BG_ROW_SY[2];
	BGCoord_t    BG_COL_SX[2],BG_COL_SY[2];
	always @(posedge CLK or negedge RST_N) begin	
		if (!RST_N) begin
			BG_X <= '0;
			BG_ROW_SX <= '{2{'0}};
			BG_ROW_SY <= '{2{'0}};
			BG_COL_SX <= '{2{'0}};
			BG_COL_SY <= '{2{'0}};
		end else if (EN) begin
			if (DOT_CE) begin;
				if (HCNT == 9'h1C0) begin
					for (int i=0;i<2;i++) begin
						BG_COL_SX[i] <= BG_COL_SX[i] + BG_COL_INCX[i];
						BG_COL_SY[i] <= BG_COL_SY[i] + BG_COL_INCY[i];
						if (VCNT == 9'h0) begin
							BG_COL_SX[i] <= BG_START_X[i];
							BG_COL_SY[i] <= BG_START_Y[i];
						end
					end
				end
				if (HCNT == 9'h1C1) begin
					BG_X <= '0;
					for (int i=0;i<2;i++) begin
						BG_ROW_SX[i] <= BG_COL_SX[i];
						BG_ROW_SY[i] <= BG_COL_SY[i];
					end
				end
				if (HCNT >= 9'h1C2 || HCNT <= 9'h13B) begin
					BG_X <= BG_X + 9'd1;
					for (int i=0;i<2;i++) begin
						BG_ROW_SX[i] <= BG_ROW_SX[i] + BG_ROW_INCX[i];
						BG_ROW_SY[i] <= BG_ROW_SY[i] + BG_ROW_INCY[i];
					end
				end
				for (int i=0;i<2;i++) begin
					BG_CHR_FETCH_C1[i] <= BG_EN[i] & BG_FETCH_TIME;
				end
			end
		end
	end
	
	bit  [10: 0] OFFS_X[2],OFFS_Y[2];
	always_comb begin
		bit          N;
		
		N = DOTCLK_DIV[0];
		case (BG_SCRL_MODE[N])
			1'b0: SCROLL_ADDR <= {2'b00,N,BG_ROW_SY[N].INT[9:0]};
			1'b1: SCROLL_ADDR <= {2'b00,N,BG_ROW_SX[N].INT[9:0]};
		endcase
		
		for (int i=0;i<2;i++) begin
			OFFS_X[i] <= BG_ROW_SX[i].INT - (!BG_SCRL_MODE[i] ? BG_SCROLL[i] : 11'h0);
			OFFS_Y[i] <= BG_ROW_SY[i].INT - ( BG_SCRL_MODE[i] ? BG_SCROLL[i] : 11'h0);
		end
	end
	
	always_comb begin
		bit          N;
		bit  [ 5: 0] TILE_X,TILE_Y;
		
		N = ~DOTCLK_DIV[0];
		TILE_X = OFFS_X[N][9:4];
		TILE_Y = OFFS_Y[N][9:4];
		case (DOTCLK_DIV)
			2'b01: TILE_ADDR <= {1'b0,TILE_Y,TILE_X};
			2'b10: TILE_ADDR <= {1'b1,TILE_Y,TILE_X};
			default: TILE_ADDR <= '0;
		endcase
		
	end
	
	//Cycle 1
	bit          BG_CHR_FETCH_C1[2];
	BGTile_t     BG_TILE[2];
	bit  [10: 0] BG_SCROLL[2];
	always @(posedge CLK or negedge RST_N) begin	
		bit  [ 3: 0] DOT_X[2],DOT_Y[2];
		
		if (!RST_N) begin
			BG_TILE <= '{2{'0}};
			BG_CHR_ADDR_C2 <= '{2{'0}};
			BG_CHR_FETCH_C2 <= '{2{0}};
			BG_PAL_C2 <= '{2{'0}};
			BG_FINEX_C2 <= '{2{'0}};
		end else if (EN) begin
			if (CE_R) begin
				case (DOTCLK_DIV)
					2'b00: BG_SCROLL[0] <= SCROLL_RAM_Q[10:0];
					2'b01: BG_SCROLL[1] <= SCROLL_RAM_Q[10:0];
				endcase
				case (DOTCLK_DIV)
					2'b01: BG_TILE[0] <= TILE_RAM_Q;
					2'b10: BG_TILE[1] <= TILE_RAM_Q;
				endcase
			end
			if (DOT_CE) begin
				for (int i=0;i<2;i++) begin
					DOT_X[i] = OFFS_X[i][3:0] ^ {4{BG_TILE[i].FLIPX}};
					DOT_Y[i] = OFFS_Y[i][3:0] ^ {4{BG_TILE[i].FLIPY}};
					case (BG_BPP[i])
						1'b0: BG_CHR_ADDR_C2[i] <= {BG_TILE[i].NUM[14:0],DOT_Y[i],DOT_X[i][3:0]};
						1'b1: BG_CHR_ADDR_C2[i] <= {BG_TILE[i].NUM[15:0],DOT_Y[i],DOT_X[i][3:1]};
					endcase
					BG_CHR_FETCH_C2[i] <= BG_CHR_FETCH_C1[i];
					BG_PAL_C2[i] <= BG_TILE[i].PAL;
					BG_PRI_C2[i] <= BG_TILE[i].PRI;
					BG_FINEX_C2[i] <= OFFS_X[i][1:0];
					BG_FLIPX_C2[i] <= BG_TILE[i].FLIPX;
				end
			end
		end
	end
	assign BG1_RENDER = 0;//BG_CHR_FETCH_C1[1];
	
	//Cycle 2
	bit  [23: 0] BG_CHR_ADDR_C2[2];
	bit          BG_CHR_FETCH_C2[2];
	assign {BG0_ROM_A,BG1_ROM_A} = {BG_CHR_ADDR_C2[0],BG_CHR_ADDR_C2[1]};
	assign {BG0_ROM_RD_N,BG1_ROM_RD_N} = ~{BG_CHR_FETCH_C2[0],BG_CHR_FETCH_C2[1]};
	
	bit  [ 5: 0] BG_PAL_C2[2];
	bit  [ 2: 0] BG_PRI_C2[2];
	bit  [ 1: 0] BG_FINEX_C2[2];
	bit          BG_FLIPX_C2[2];
	always @(posedge CLK or negedge RST_N) begin	
		if (!RST_N) begin
			BG_CHR_C3 <= '{2{'0}};
			BG_PAL_C3 <= '{2{'0}};
			BG_FINEX_C3 <= '{2{'0}};
		end else if (EN) begin
			if (DOT_CE) begin;
				BG_CHR_C3 <= '{BG0_ROM_D,BG1_ROM_D};
				BG_PAL_C3 <= BG_PAL_C2;
				BG_PRI_C3 <= BG_PRI_C2;
				BG_FINEX_C3 <= BG_FINEX_C2;
				BG_FLIPX_C3 <= BG_FLIPX_C2;
			end
		end
	end
	
	//Cycle 3
	bit  [15: 0] BG_CHR_C3[2];
	bit  [ 5: 0] BG_PAL_C3[2];
	bit  [ 2: 0] BG_PRI_C3[2];
	bit  [ 1: 0] BG_FINEX_C3[2];
	bit          BG_FLIPX_C3[2];
	always_comb begin	
		BG0_PIX <= BG_EN[0] ? {{BG_PRI_C3[0],BG_PRIL[0]}, BG_PAL_C3[0], BGPix(BG_CHR_C3[0],BG_FINEX_C3[0],BG_FLIPX_C3[0],BG_BPP[0])} : '0;
		BG1_PIX <= BG_EN[1] ? {{BG_PRI_C3[1],BG_PRIL[1]}, BG_PAL_C3[1], BGPix(BG_CHR_C3[1],BG_FINEX_C3[1],BG_FLIPX_C3[1],BG_BPP[1])} : '0;
	end
	
`ifdef DEBUG
	assign DBG_BG0_ROW_SX = BG_ROW_SX[0].INT;
	assign DBG_BG0_ROW_SY = BG_ROW_SY[0].INT;
	assign DBG_BG1_ROW_SX = BG_ROW_SX[1].INT;
	assign DBG_BG1_ROW_SY = BG_ROW_SY[1].INT;
	assign DBG_BG0_BPP = BG_BPP[0];
	assign DBG_BG1_BPP = BG_BPP[1];
`endif
	
endmodule
