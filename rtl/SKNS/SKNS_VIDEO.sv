module SKNS_VIEW3
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_F,
	input              CE_R,
	
	input              RES_N,
	
	input      [24: 0] A,
	input      [31: 0] DI,
	output     [31: 0] DO,
	input              RD_N,
	input      [ 3: 0] WE_N,
	input              CS1_N,
	input              CS2_N,
	output             WAIT_N,
	
	output             DOT_CE,
	output             HINT,
	output             VINT,
	
	output     [23: 0] BG0_ROM_A,
	input      [15: 0] BG0_ROM_D,
	output             BG0_ROM_RD_N,
	
	output     [23: 0] BG1_ROM_A,
	input      [15: 0] BG1_ROM_D,
	output             BG1_ROM_RD_N,
	
	output     [17: 1] BG1_RAM_A,
	output     [15: 0] BG1_RAM_WD,
	output     [ 1: 0] BG1_RAM_WE_N,
	output             BG1_RAM_RD_N,
	
	output             HSPC_N,
	input      [15: 0] SPC_DATA,
	
	output     [ 7: 0] R,
	output     [ 7: 0] G,
	output     [ 7: 0] B,
	output             DCLK,
	output             HS_N,
	output             VS_N,
	output             HBL_N,
	output             VBL_N,
	
	input      [ 2: 0] SCRN_EN
	
`ifdef DEBUG
	                   ,
	output     [10: 0] DBG_BG0_ROW_SX,DBG_BG0_ROW_SY,DBG_BG1_ROW_SX,DBG_BG1_ROW_SY,
	output             DBG_BG0_BPP,DBG_BG1_BPP
`endif
);

	import SKNS_PKG::*;

	bit  [31: 0] VREG[32];
	bit  [31: 0] PREG[8];
	
	bit          DOT_CE_R;
	
	wire         IO_VREG_SEL   = (A[24:0] >= (25'h400000) && A[24:0] <= (25'h40007F) && !CS1_N);
	wire         IO_TILE_SEL   = (A[24:0] >= (25'h500000) && A[24:0] <= (25'h507FFF) && !CS1_N);
	wire         IO_SCROLL_SEL = (A[24:0] >= (25'h600000) && A[24:0] <= (25'h607FFF) && !CS1_N);
	wire         IO_PREG_SEL   = (A[24:0] >= (25'hA00000) && A[24:0] <= (25'hA0001F) && !CS1_N);
	wire         IO_PAL_SEL    = (A[24:0] >= (25'hA40000) && A[24:0] <= (25'hA5FFFF) && !CS1_N);
	wire         IO_CG_SEL     = (A[24:23] == 2'b01 && !CS2_N);
	
	bit          WE_N_OLD;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			VREG <= '{32{'0}};
			PREG <= '{8{'0}};
		end else if (EN) begin
			if (CE_R) begin
				WE_N_OLD <= &WE_N;
				if (IO_VREG_SEL && !(&WE_N) && WE_N_OLD) begin
					if (!WE_N[3]) VREG[A[6:2]][31:24] <= DI[31:24];
					if (!WE_N[2]) VREG[A[6:2]][23:16] <= DI[23:16];
					if (!WE_N[1]) VREG[A[6:2]][15: 8] <= DI[15: 8];
					if (!WE_N[0]) VREG[A[6:2]][ 7: 0] <= DI[ 7: 0];
				end
				if (IO_PREG_SEL && !(&WE_N) && WE_N_OLD) begin
					if (!WE_N[3]) PREG[A[4:2]][31:24] <= DI[31:24];
					if (!WE_N[2]) PREG[A[4:2]][23:16] <= DI[23:16];
					if (!WE_N[1]) PREG[A[4:2]][15: 8] <= DI[15: 8];
					if (!WE_N[0]) PREG[A[4:2]][ 7: 0] <= DI[ 7: 0];
				end
			end
		end
	end
	assign DO = IO_VREG_SEL ? VREG[A[6:2]] : 
					IO_PREG_SEL ? PREG[A[4:2]] : 
	            IO_PAL_SEL  ? {16'h0000,IO_PAL_DO} : 
					IO_TILE_SEL ? IO_TILE_RAM_Q :
					IO_SCROLL_SEL ? IO_SCROLL_RAM_Q :
					IO_CG_SEL    ? {16'h0000,IO_BG1_RAM_DO} :
					'0;
	assign WAIT_N = ~(IO_CG_SEL & |{IO_BG1_RAM_WAIT,IO_BG1_RAM_RWAIT}) & ~(IO_PAL_SEL & IO_PAL_WAIT);
	
	//Palette
	bit  [15: 0] IO_PAL_DO;
	bit          IO_PAL_WAIT;
	bit          IO_PAL_CYCLE;
	always @(posedge CLK or negedge RST_N) begin
		bit          IO_PAL_SEL_OLD;
		
		if (!RST_N) begin
			IO_PAL_WAIT <= 0;
			IO_PAL_CYCLE <= 0;
		end else if (EN) begin
			IO_PAL_SEL_OLD <= IO_PAL_SEL;
			if (IO_PAL_SEL && !IO_PAL_SEL_OLD) begin
				IO_PAL_WAIT <= 1;
			end
			if (CE_R) begin
				if (DOTCLK_DIV == 2'b11) IO_PAL_CYCLE <= IO_PAL_WAIT;
				if (IO_PAL_CYCLE) begin
					IO_PAL_DO <= PAL_Q;
					IO_PAL_CYCLE <= 0;
					IO_PAL_WAIT <= 0;
				end
			end
		end
	end
	
	wire [14: 0] PAL_RA = DOTCLK_DIV == 2'b00 ? A[16:2] : BG_COLOR;
	bit  [15: 0] PAL_Q;
	SKNS_PAL_RAM PAL(CLK, A[16:2], DI[15:0], ~WE_N[1:0] & {2{IO_PAL_CYCLE & CE_R}}, PAL_RA, PAL_Q);
	
	//BGB char RAM
	bit          RENDER_BG1_CYCLE;
	bit  [17: 1] IO_BG1_RAM_ADDR;
	bit  [15: 0] IO_BG1_RAM_DATA;
	bit  [ 1: 0] IO_BG1_RAM_WE;
	bit          IO_BG1_RAM_RD;
	bit  [15: 0] IO_BG1_RAM_DO;
	bit          IO_BG1_RAM_WAIT;
	bit  [ 1: 0] IO_BG1_RAM_RWAIT;
	bit          IO_BG1_RAM_CYCLE;
	always @(posedge CLK or negedge RST_N) begin
		bit         CG_SEL_OLD;
		
		if (!RST_N) begin
			{IO_BG1_RAM_WAIT,IO_BG1_RAM_RWAIT} <= '0;
			IO_BG1_RAM_CYCLE <= 0;
			IO_BG1_RAM_WE <= '0;
			IO_BG1_RAM_RD <= 0;
		end else if (EN) begin
			CG_SEL_OLD <= IO_CG_SEL;
			if (IO_CG_SEL && !CG_SEL_OLD) begin
				IO_BG1_RAM_WAIT <= 1;
			end
			
			if (CE_R) begin
				IO_BG1_RAM_RWAIT <= {IO_BG1_RAM_RWAIT[0],1'b0};
			end
			if (DOT_CE_R) begin
				if (IO_BG1_RAM_WAIT) begin
					IO_BG1_RAM_ADDR <= A[17:1];
					IO_BG1_RAM_DATA <= DI[15: 0];
					IO_BG1_RAM_WE <= ~WE_N[1:0];
					IO_BG1_RAM_RD <= ~RD_N;
					IO_BG1_RAM_CYCLE <= 1;
				end
				if (IO_BG1_RAM_CYCLE && !RENDER_BG1_CYCLE) begin
					IO_BG1_RAM_WE <= '0;
					IO_BG1_RAM_RD <= 0;
					IO_BG1_RAM_CYCLE <= 0;
					IO_BG1_RAM_WAIT <= 0;
					IO_BG1_RAM_RWAIT[0] <= IO_BG1_RAM_RD;
				end
			end
			if (CE_R) begin
				if (IO_BG1_RAM_RWAIT[1]) begin
					IO_BG1_RAM_DO <= BG1_ROM_D;
				end
			end
		end
	end
	assign BG1_RAM_A = IO_BG1_RAM_ADDR;
	assign BG1_RAM_WD = IO_BG1_RAM_DATA;
	assign BG1_RAM_WE_N = ~IO_BG1_RAM_WE;
	assign BG1_RAM_RD_N = ~IO_BG1_RAM_RD;
	
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
	assign DOT_CE = DOT_CE_R;
	
	wire [ 8: 0] DOT_PER_LINE = 9'd456;
	wire [ 8: 0] HSYNC_START = 9'h168 /*+ HS_OFFS*/;
	wire [ 8: 0] VBLK_START = 9'h0F0;
	wire [ 8: 0] VSYNC_START = 9'd237+9'd16;
	bit  [ 8: 0] HCNT;
	bit  [ 8: 0] VCNT;
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
				
				if (HCNT == DOT_PER_LINE - 1 && VCNT == VSYNC_START - 9'd1) begin
					VSYNC <= 1;
				end
				if (HCNT == DOT_PER_LINE - 1 && VCNT == VSYNC_START + 9'd3 - 1) begin
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
	assign DCLK = DOTCLK_DIV[1];
	assign HS_N = ~HSYNC;
	assign VS_N = ~VSYNC;
	assign HBL_N = ~HBLK;
	assign VBL_N = ~VBLK;
	
	assign HINT = HBLK;
	assign VINT = VBLK;
	
	assign HSPC_N = ~HSPC;

	//BG
	wire         BG_FETCH_TIME = (HCNT >= 9'h1C3 & (VCNT == 9'h1FF | VCNT <= 9'h0EE)) | (HCNT <= 9'h13B && VCNT <= 9'h0EF);
	
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
			if (DOT_CE_R) begin;
				if (HCNT == 9'h1C1) begin
					for (int i=0;i<2;i++) begin
						BG_COL_SX[i] <= BG_COL_SX[i] + BG_COL_INCX[i];
						BG_COL_SY[i] <= BG_COL_SY[i] + BG_COL_INCY[i];
						if (VCNT == 9'h1FF) begin
							BG_COL_SX[i] <= BG_START_X[i];
							BG_COL_SY[i] <= BG_START_Y[i];
						end
					end
				end
				if (HCNT == 9'h1C2) begin
					BG_X <= '0;
					for (int i=0;i<2;i++) begin
						BG_ROW_SX[i] <= BG_COL_SX[i];
						BG_ROW_SY[i] <= BG_COL_SY[i];
					end
				end
				if (HCNT >= 9'h1C3 || HCNT <= 9'h13B) begin
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
			if (DOT_CE_R) begin
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
	assign RENDER_BG1_CYCLE = BG_CHR_FETCH_C1[1];
	
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
			if (DOT_CE_R) begin;
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
	bit  [ 1: 0] DOT_FST,DOT_SEC,DOT_THD;	
	always @(posedge CLK or negedge RST_N) begin	
		bit  [ 7: 0] BG_PIX[2];
		bit  [ 5: 0] BG_PAL[2];
		bit  [ 3: 0] BG_PRI[2];
		bit          BG_VIS[2];	
		bit  [ 3: 0] SPR_PRI;	
		bit          SPR_VIS;
		bit  [ 3: 0] FST_PRI,SEC_PRI,THD_PRI;
		bit  [ 1: 0] FST,SEC,THD;
		
		if (!RST_N) begin
			BG_OUT_PIX <= '{2{'0}};
			BG_OUT_PAL <= '{2{'0}};
			{DOT_FST,DOT_SEC,DOT_THD} <= '0;
		end else if (EN) begin		
			for (int i=0;i<2;i++) begin
				BG_PIX[i] = BGPix(BG_CHR_C3[i],BG_FINEX_C3[i],BG_FLIPX_C3[i],BG_BPP[i]);
				BG_PAL[i] = BG_PAL_C3[i];
				BG_PRI[i] = {BG_PRI_C3[i],BG_PRIL[i]};
				BG_VIS[i] = |BG_PIX[i] && BG_EN[i] && SCRN_EN[i];
			end
			SPR_PRI = {SPC_DATA[15:14],2'b11};
			SPR_VIS = |SPC_DATA[7:0] && SCRN_EN[2];
			
			if (DOT_CE_R) begin
				for (int i=0;i<2;i++) begin
					BG_OUT_PIX[i] <= BG_PIX[i];
					BG_OUT_PAL[i] <= BG_PAL[i];
				end
				SPR_OUT_PIX <= SPC_DATA[7:0];
				SPR_OUT_PAL <= SPC_DATA[13:8];
				
				{FST,SEC,THD} = {2'h3,2'h3,2'h3};
				{FST_PRI,SEC_PRI,THD_PRI} = {4'h0,4'h0,4'h0};
				     if (SPR_PRI >= FST_PRI && SPR_VIS) begin
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = FST;  SEC_PRI = FST_PRI;
					FST = 2'd2; FST_PRI = SPR_PRI;
				end 
				
				     if (BG_PRI[0] >= FST_PRI && BG_VIS[0]) begin
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = FST;  SEC_PRI = FST_PRI;
					FST = 2'd0; FST_PRI = BG_PRI[0];
				end 
				else if (BG_PRI[0] >= SEC_PRI && BG_VIS[0]) begin
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = 2'd0; SEC_PRI = BG_PRI[0];
				end 
				
				     if (BG_PRI[1] >= FST_PRI && BG_VIS[1]) begin
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = FST;  SEC_PRI = FST_PRI;
					FST = 2'd1; FST_PRI = BG_PRI[1];
				end 
				else if (BG_PRI[1] >= SEC_PRI && BG_VIS[1]) begin
					THD = SEC;  THD_PRI = SEC_PRI;
					SEC = 2'd1; SEC_PRI = BG_PRI[1];
				end 
				else if (BG_PRI[1] >= THD_PRI && BG_VIS[1]) begin
					THD = 2'd1; THD_PRI = BG_PRI[1];
				end
				
				DOT_FST <= FST;
				DOT_SEC <= SEC;
				DOT_THD <= THD;
			end
		end
	end
	
	//Cycle 4
	bit  [ 7: 0] BG_OUT_PIX[2];
	bit  [ 5: 0] BG_OUT_PAL[2];
	bit  [ 7: 0] SPR_OUT_PIX;
	bit  [ 5: 0] SPR_OUT_PAL;
	bit  [14: 0] BG_COLOR;
	always_comb begin
		case (DOTCLK_DIV)
			2'h0: BG_COLOR <= DOT_THD <= 2'h1 ? {1'b1,BG_OUT_PAL[DOT_THD[0]],BG_OUT_PIX[DOT_THD[0]]} : DOT_THD == 2'h2 ? {1'b0,SPR_OUT_PAL,SPR_OUT_PIX} : '0;
			2'h1: BG_COLOR <= DOT_SEC <= 2'h1 ? {1'b1,BG_OUT_PAL[DOT_SEC[0]],BG_OUT_PIX[DOT_SEC[0]]} : DOT_SEC == 2'h2 ? {1'b0,SPR_OUT_PAL,SPR_OUT_PIX} : '0;
			2'h2,
			2'h3: BG_COLOR <= DOT_FST <= 2'h1 ? {1'b1,BG_OUT_PAL[DOT_FST[0]],BG_OUT_PIX[DOT_FST[0]]} : DOT_FST == 2'h2 ? {1'b0,SPR_OUT_PAL,SPR_OUT_PIX} : '0;
		endcase
	end
	
	bit  [23: 0] OUT_RGB;
	always @(posedge CLK or negedge RST_N) begin
		bit  [23: 0] TOP_RGB, BOT_RGB, TEMP_RGB;
		bit  [ 1: 0] TOP, BOT;
		bit          BLEND;
	
		if (!RST_N) begin
			BOT_RGB <= '0;
			OUT_RGB <= '0;
		end else if (EN) begin
			if (BG_COLOR[14]) begin
				TEMP_RGB = RGBBright(PAL_Q[15:0], {PREG[6][7:0],PREG[5][7:0],PREG[7][7:0]}, PREG[4][0]);
			end else begin
				TEMP_RGB = RGBBright(PAL_Q[15:0], {PREG[2][7:0],PREG[1][7:0],PREG[3][7:0]}, PREG[0][0]);
			end
			
			if (CE_R) begin
				case (DOTCLK_DIV)
					2'h1: begin BOT_RGB <= TEMP_RGB; BOT <= DOT_SEC; end
					2'h2: begin TOP_RGB <= TEMP_RGB; TOP <= DOT_FST; BLEND <= PAL_Q[15]; end
					2'h3: OUT_RGB <= RGBBlend(TOP_RGB, BOT_RGB, {PREG[2][15:8],PREG[1][15:8],PREG[3][15:8]}, BLEND && TOP == 2'h2);
				endcase
			end
		end
	end
	assign {R,G,B} = OUT_RGB;
	
	
`ifdef DEBUG
	assign DBG_BG0_ROW_SX = BG_ROW_SX[0].INT;
	assign DBG_BG0_ROW_SY = BG_ROW_SY[0].INT;
	assign DBG_BG1_ROW_SX = BG_ROW_SX[1].INT;
	assign DBG_BG1_ROW_SY = BG_ROW_SY[1].INT;
	assign DBG_BG0_BPP = BG_BPP[0];
	assign DBG_BG1_BPP = BG_BPP[1];
`endif
	
endmodule
