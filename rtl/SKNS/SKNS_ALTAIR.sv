module SKNS_ALTAIR
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_F,
	input              CE_R,
	
	input              RES_N,
	
	input      [18: 2] A,
	input      [15: 0] DI,
	output     [15: 0] DO,
	input              RD_N,
	input      [ 1: 0] WE_N,
	input              CE_N,
	output             WAIT_N,
	
	input              DOT_CE,
	
	output     [14: 0] PAL_RAM_A,
	output     [15: 0] PAL_RAM_D,
	output             PAL_RAM_OE_N,
	output             PAL_RAM_WE_N,
	output             PAL_RAM_CE_N,
	input      [15: 0] PAL_RAM_Q,
	
	input      [15: 0] SPR_PIX,
	input      [17: 0] BG0_PIX,
	input      [17: 0] BG1_PIX,
	
	output     [ 7: 0] R,
	output     [ 7: 0] G,
	output     [ 7: 0] B,
	
	input      [ 2: 0] SCRN_EN
	
`ifdef DEBUG
	                   
`endif
);

	import SKNS_PKG::*;

	bit  [15: 0] PREG[8];
	
	wire         IO_PREG_SEL   = (!A[18] && !CE_N);
	wire         IO_PAL_SEL    = ( A[18] && !CE_N);
	
	bit          WE_N_OLD;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			PREG <= '{8{'0}};
		end else if (EN) begin
			if (CE_R) begin
				WE_N_OLD <= &WE_N;
				if (IO_PREG_SEL && !(&WE_N) && WE_N_OLD) begin
					if (!WE_N[1]) PREG[A[4:2]][15: 8] <= DI[15: 8];
					if (!WE_N[0]) PREG[A[4:2]][ 7: 0] <= DI[ 7: 0];
				end
			end
		end
	end
	assign DO = IO_PREG_SEL ? PREG[A[4:2]] : 
	            IO_PAL_SEL  ? IO_PAL_DO : 
					'0;
	assign WAIT_N = ~(IO_PAL_SEL & IO_PAL_WAIT);
	
	//Palette
	wire [14: 0] PAL_RA = DOTCLK_DIV == 2'b00 ? A[16:2] : BG_COLOR;
	
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
					IO_PAL_DO <= PAL_RAM_Q;
					IO_PAL_CYCLE <= 0;
					IO_PAL_WAIT <= 0;
				end
			end
		end
	end
	
//	bit  [15: 0] PAL_Q;
//	SKNS_PAL_RAM PAL(CLK, A[16:2], DI, ~WE_N & {2{IO_PAL_CYCLE & CE_R}}, PAL_RA, PAL_Q);
	
	assign PAL_RAM_A = PAL_RA;
	assign PAL_RAM_D = DI;
	assign PAL_RAM_OE_N = RD_N | ~IO_PAL_CYCLE;
	assign PAL_RAM_WE_N = &WE_N | ~IO_PAL_CYCLE;
	assign PAL_RAM_CE_N = ~IO_PAL_SEL;
	
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
	
	//Cycle 3
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
			{BG_PRI[0],BG_PAL[0],BG_PIX[0]} = BG0_PIX;
			{BG_PRI[1],BG_PAL[1],BG_PIX[1]} = BG1_PIX;
			for (int i=0;i<2;i++) begin
				BG_VIS[i] = |BG_PIX[i] && SCRN_EN[i];
			end
			
			SPR_PRI = {SPR_PIX[15:14],2'b11};
			SPR_VIS = |SPR_PIX[7:0] && SCRN_EN[2];
			
			if (DOT_CE) begin
				for (int i=0;i<2;i++) begin
					BG_OUT_PIX[i] <= BG_PIX[i];
					BG_OUT_PAL[i] <= BG_PAL[i];
				end
				SPR_OUT_PIX <= SPR_PIX[7:0];
				SPR_OUT_PAL <= SPR_PIX[13:8];
				
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
				TEMP_RGB = RGBBright(PAL_RAM_Q[15:0], {PREG[6][7:0],PREG[5][7:0],PREG[7][7:0]}, PREG[4][0]);
			end else begin
				TEMP_RGB = RGBBright(PAL_RAM_Q[15:0], {PREG[2][7:0],PREG[1][7:0],PREG[3][7:0]}, PREG[0][0]);
			end
			
			if (CE_R) begin
				case (DOTCLK_DIV)
					2'h1: begin BOT_RGB <= TEMP_RGB; BOT <= DOT_SEC; end
					2'h2: begin TOP_RGB <= TEMP_RGB; TOP <= DOT_FST; BLEND <= PAL_RAM_Q[15]; end
					2'h3: OUT_RGB <= RGBBlend(TOP_RGB, BOT_RGB, {PREG[2][15:8],PREG[1][15:8],PREG[3][15:8]}, BLEND && TOP == 2'h2);
				endcase
			end
		end
	end
	assign {R,G,B} = OUT_RGB;
	
endmodule
