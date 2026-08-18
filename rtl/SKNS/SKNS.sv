module SKNS 
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              SYS_CE_F,
	input              SYS_CE_R,
	input              YMZ_CE,
	input              X32K_CE,
	
	input              RES_N,
	
	output     [20: 0] ROM_A,
	input      [15: 0] ROM_D,
	output             ROM_OE_N,
	output             BIOS_CE_N,
	output             GROM_CE_N,
	
	output     [19: 2] DRAM_A,
	input      [31: 0] DRAM_DI,
	output     [31: 0] DRAM_DO,
	output     [ 3: 0] DRAM_WE_N,
	output             DRAM_RD_N,
	output             DRAM_CE_N,
	
	input              MEM_WAIT_N,
	
	output     [23: 0] SPR_ROM_A,
	input      [15: 0] SPR_ROM_D,
	output             SPR_ROM_RD_N,
	input              SPR_ROM_WAIT,
	
	output     [18: 1] SPR_FB0_A,
	output     [15: 0] SPR_FB0_D,
	input      [15: 0] SPR_FB0_Q,
	output             SPR_FB0_WE,
	output     [18: 1] SPR_FB1_A,
	output     [15: 0] SPR_FB1_D,
	input      [15: 0] SPR_FB1_Q,
	output             SPR_FB1_WE,
	
	output     [23: 0] BGA_ROM_A,
	input      [15: 0] BGA_ROM_D,
	output             BGA_ROM_RD_N,
	
	output     [17: 1] BGB_RAM_A,
	output     [15: 0] BGB_RAM_WD,
	output     [ 1: 0] BGB_RAM_WE_N,
	output             BGB_RAM_RD_N,
	
	output     [23: 0] BGB_ROM_A,
	input      [15: 0] BGB_ROM_D,
	output             BGB_ROM_RD_N,
	
	output     [23: 0] SOUND_ROM_A,
	input      [ 7: 0] SOUND_ROM_D,
	output             SOUND_ROM_RD_N,
	
	output     [12: 0] NVRAM_A,
	output     [ 7: 0] NVRAM_DO,
	input      [ 7: 0] NVRAM_DI,
	output             NVRAM_WE_N,
	output             NVRAM_OE_N,
	output             NVRAM_CE_N,
	
	output     [ 7: 0] R,
	output     [ 7: 0] G,
	output     [ 7: 0] B,
	output             DCLK,
	output             HS_N,
	output             VS_N,
	output             HBL_N,
	output             VBL_N,
	
	output     [15: 0] SOUND_L,
	output     [15: 0] SOUND_R,
	
	input      [ 7: 0] P0,
	input      [ 7: 0] P1,
	input      [ 7: 0] P2,
	input      [ 7: 0] P3,
	input      [ 7: 0] P4,
	input      [ 7: 0] P5,
	input      [ 7: 0] P6,
	input      [ 7: 0] P7,
	input      [ 7: 0] REGION,
	
	input      [ 9: 0] SPR_OFFSX,
	input      [ 9: 0] SPR_OFFSY,
	
	input      [ 5: 0] SCRN_EN,
	input      [ 2: 0] SND_EN
	
`ifdef DEBUG
                      ,
	input      [ 7: 0] DBG_EXT,
	input              DBG_PAUSE,
	output reg [15: 0] DBG_CLKDIV
`endif
);


	bit  [26: 0] CPU_A;
	bit  [31: 0] CPU_DI;
	bit  [31: 0] CPU_DO;
	bit  [ 3: 0] CPU_WE_N;
	bit          CPU_RD_N;
	bit          CPU_RD_WR_N;
	bit          CPU_CS0_N;
	bit          CPU_CS1_N;
	bit          CPU_CS2_N;
	bit          CPU_CS3_N;
	bit  [ 3: 0] CPU_IRL_N;

	bit  [31: 0] VIEW3_DO,SPC_DO;
	bit          VIEW3_WAIT_N,SPC_WAIT_N;
	bit          VIEW3_HINT,VIEW3_VINT;
	bit          HSPC_N;
	bit  [15: 0] SPC_DATA;
	bit          SPC_INT;
	bit          DOT_CE;

	bit  [ 3: 0] RTC_DO;
	
	bit  [ 7: 0] YMZ_DO;
	bit          YMZ_CS_N;
	bit          YMZ_RES_N;
	bit          YMZ_IRQ_N;
	bit  [20: 0] YMZ_MA;
	bit  [ 9: 0] YMZ_MCS_N;
	
	bit  [ 7: 0] IO_DO;
	bit  [15: 0] HIT_DO;
	
	bit          VBI_IRQ,SPC_IRQ,HBI_IRQ,TM0_IRQ,TM1_IRQ;
	
	wire         BIOS_SEL  = (!CPU_CS0_N && CPU_A[24:22] == 3'b000);
	wire         IO_SEL    = (!CPU_CS0_N && CPU_A[24:22] == 3'b001);
	wire         NVRAM_SEL = (!CPU_CS0_N && CPU_A[24:22] == 3'b010);
	wire         YMZ_SEL   = (!CPU_CS0_N && CPU_A[24:22] == 3'b011);
	wire         RTC_SEL   = (!CPU_CS0_N && CPU_A[24:22] == 3'b100);
	wire         LOCK_SEL  = (!CPU_CS0_N && CPU_A[24:22] == 3'b110);
	wire         HIT_SEL   = (!CPU_CS1_N && CPU_A[24:20] == 5'b01111);
	wire         SPR_SEL   = (!CPU_CS1_N && CPU_A[24:22] == 3'b000);
	wire         VID_SEL   = (!CPU_CS1_N && CPU_A[24:22] != 3'b000) || (!CPU_CS2_N && CPU_A[24:23] == 2'b01);
	wire         GROM_SEL  = (!CPU_CS2_N && CPU_A[24:23] == 2'b00);
	
	
	SH7604 #(.UBC_DISABLE(1), .SCI_DISABLE(1), .BUS_AREA_TIMIMG({1'b1,3'b111})) CPU
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(SYS_CE_R),
		.CE_F(SYS_CE_F),
`ifdef DEBUG
		.EN(EN & ~DBG_PAUSE),
`else
		.EN(EN),
`endif
		
		.RES_N(RES_N),
		.NMI_N(1'b1),
		
		.IRL_N(CPU_IRL_N),
		
		.A(CPU_A),
		.DI(CPU_DI),
		.DO(CPU_DO),
		.BS_N(),
		.CS0_N(CPU_CS0_N),
		.CS1_N(CPU_CS1_N),
		.CS2_N(CPU_CS2_N),
		.CS3_N(CPU_CS3_N),
		.RD_WR_N(CPU_RD_WR_N),
		.WE_N(CPU_WE_N),
		.RD_N(CPU_RD_N),
		.IVECF_N(),
		.RFS(),
		
		.EA('0),
		.EDI(),
		.EDO('0),
		.EBS_N(1'b1),
		.ECS0_N(1'b1),
		.ECS1_N(1'b1),
		.ECS2_N(1'b1),
		.ECS3_N(1'b1),
		.ERD_WR_N(1'b1),
		.EWE_N('1),
		.ERD_N(1'b1),
		.ECE_N(1'b1),
		.EOE_N(1'b1),
		.EIVECF_N(1'b1),
		
		.WAIT_N(VIEW3_WAIT_N & SPC_WAIT_N & MEM_WAIT_N),
		.IVECF_N(),
		.BRLS_N(1'b1),
		.BGR_N(),
		
		.DREQ0(1'b1),
		.DREQ1(1'b1),
		
		.FTCI(1'b1),
		.FTI(1'b1),
		
		.RXD(1'b1),
		.TXD(),
		.SCKO(),
		.SCKI(1'b1),
		
		.MD(6'b000110),
		
		.FAST(1'b0)
		
`ifdef DEBUG
		,
		.DBG_REGN('0),
		.DBG_REGQ(),
		.DBG_RUN(1),
		.DBG_BREAK()
`endif
	);
	assign CPU_DI = !BIOS_CE_N ? {24'h000000,ROM_D[7:0]} : 
	                NVRAM_SEL  ? {24'h000000,NVRAM_DI} : 
	                YMZ_SEL ? {24'h000000,YMZ_DO} :
						 IO_SEL ? {24'h000000,IO_DO} :
						 RTC_SEL ? {28'h0000000,RTC_DO} :
						 HIT_SEL    ? (LOCK ? 32'h00000000 : {16'h0000,HIT_DO}) :
						 SPR_SEL ? SPC_DO :
						 VID_SEL ? VIEW3_DO :
						 !GROM_CE_N ? {16'h0000,ROM_D} : 
	                !CPU_CS3_N ? DRAM_DI : 
						 32'h00000000;
	
	assign ROM_A = CPU_A[20:0];
	assign ROM_OE_N = CPU_RD_N;
	assign BIOS_CE_N = ~BIOS_SEL;
	assign GROM_CE_N = ~GROM_SEL;
	
	assign DRAM_A = CPU_A[19:2];
	assign DRAM_DO = CPU_DO;
	assign DRAM_WE_N = CPU_WE_N;
	assign DRAM_RD_N = CPU_RD_N;
	assign DRAM_CE_N = CPU_CS3_N;
	
	assign NVRAM_A = CPU_A[12:0];
	assign NVRAM_DO = CPU_DO[7:0];
	assign NVRAM_WE_N = CPU_WE_N[0];
	assign NVRAM_OE_N = CPU_RD_N;
	assign NVRAM_CE_N = ~NVRAM_SEL;
	
	////
	SKNS_VIEW3 VIEW3
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE_F(SYS_CE_F),
		.CE_R(SYS_CE_R),
		
		.RES_N(RES_N),
		
		.A(CPU_A[24:0]),
		.DI(CPU_DO),
		.DO(VIEW3_DO),
		.RD_N(CPU_RD_N),
		.WE_N(CPU_WE_N),
		.CS1_N(CPU_CS1_N),
		.CS2_N(CPU_CS2_N),
		.WAIT_N(VIEW3_WAIT_N),
		
		.DOT_CE(DOT_CE),
		.HINT(VIEW3_HINT),
		.VINT(VIEW3_VINT),
		
		.BG0_ROM_A(BGA_ROM_A),
		.BG0_ROM_D(BGA_ROM_D),
		.BG0_ROM_RD_N(BGA_ROM_RD_N),
		
		.BG1_ROM_A(BGB_ROM_A),
		.BG1_ROM_D(BGB_ROM_D),
		.BG1_ROM_RD_N(BGB_ROM_RD_N),
		
		.BG1_RAM_A(BGB_RAM_A),
		.BG1_RAM_WD(BGB_RAM_WD),
		.BG1_RAM_WE_N(BGB_RAM_WE_N),
		.BG1_RAM_RD_N(BGB_RAM_RD_N),
		
		.HSPC_N(HSPC_N),
		.SPC_DATA(SPC_DATA),
		
		.R(R),
		.G(G),
		.B(B),
		.DCLK(DCLK),
		.HS_N(HS_N),
		.VS_N(VS_N),
		.HBL_N(HBL_N),
		.VBL_N(VBL_N),
		
		.SCRN_EN(SCRN_EN[2:0])
	);
	
	SKNS_SPC2 SPC2
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE_F(SYS_CE_F),
		.CE_R(SYS_CE_R),
		
		.RES_N(RES_N),
		
		.A(CPU_A[24:0]),
		.DI(CPU_DO),
		.DO(SPC_DO),
		.RD_N(CPU_RD_N),
		.WE_N(CPU_WE_N),
		.CS_N(CPU_CS1_N),
		.WAIT_N(SPC_WAIT_N),
		
		.INT(SPC_INT),
		
		.ROM_A(SPR_ROM_A),
		.ROM_D(SPR_ROM_D),
		.ROM_RD_N(SPR_ROM_RD_N),
		.ROM_WAIT(SPR_ROM_WAIT),
		
		.FB0_A(SPR_FB0_A),
		.FB0_D(SPR_FB0_D),
		.FB0_Q(SPR_FB0_Q),
		.FB0_WE(SPR_FB0_WE),
		.FB1_A(SPR_FB1_A),
		.FB1_D(SPR_FB1_D),
		.FB1_Q(SPR_FB1_Q),
		.FB1_WE(SPR_FB1_WE),
		
		.DOT_CE(DOT_CE),
		.HBL_N(HSPC_N),
		.VBL_N(VBL_N),
		.OUT(SPC_DATA),
		
		.SPR_OFFSX(SPR_OFFSX),
		.SPR_OFFSY(SPR_OFFSY)
		
`ifdef DEBUG
      ,
		.DBG_EXT(DBG_EXT)
`endif
	);
	
	assign YMZ_CS_N = ~YMZ_SEL;
	YMZ280B YMZ280B
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE(YMZ_CE),
		
		.A(CPU_A[0]),
		.DI(CPU_DO[7:0]),
		.DO(YMZ_DO),
		.RD_N(CPU_RD_N),
		.WR_N(CPU_WE_N[0]),
		.CS_N(YMZ_CS_N),
		.IC_N(1'b1),
	
		.IRQ_N(YMZ_IRQ_N),
		
		.MA(SOUND_ROM_A),
		.MDI(SOUND_ROM_D),
		.MDO(),
		.MOE_N(SOUND_ROM_RD_N),
		.MWR_N(),
		.MCE_N(),
	
		.OUT_L(SOUND_L),
		.OUT_R(SOUND_R),
		
		.SND_EN(SND_EN)
	);

	//Interrupts
	wire         IRQ_ACK = (IO_SEL && CPU_A[3:0] == 4'hE && !CPU_WE_N[0]);
	always @(posedge CLK or negedge RST_N) begin
		bit          HINT_OLD,VINT_OLD;
		bit          SPC_INT_OLD;
		bit          IRQ_ACK_OLD;
		bit  [17: 0] TM0_CNT,TM1_CNT;
		
		if (!RST_N) begin
			{HBI_IRQ,VBI_IRQ,SPC_IRQ,TM0_IRQ,TM1_IRQ} <= '0;
		end else if (EN) begin
			if (SYS_CE_R) begin
				HINT_OLD <= VIEW3_HINT;
				VINT_OLD <= VIEW3_VINT;
				if (VIEW3_HINT && !HINT_OLD) begin
					HBI_IRQ <= 1;
				end
				if (VIEW3_VINT && !VINT_OLD) begin
					VBI_IRQ <= 1;
				end
				
				SPC_INT_OLD <= SPC_INT;
				if (SPC_INT && !SPC_INT_OLD) begin
					SPC_IRQ <= 1;
				end
				
				
				TM0_CNT <= TM0_CNT + 1'd1;
				if (TM0_CNT == 18'd57272-1) begin
					TM0_CNT <= '0;
					TM0_IRQ <= 1;
				end
				
				TM1_CNT <= TM1_CNT + 1'd1;
				if (TM1_CNT == 18'd229088-1) begin
					TM1_CNT <= '0;
					TM1_IRQ <= 1;
				end
				
				IRQ_ACK_OLD <= IRQ_ACK;
				if (IRQ_ACK && !IRQ_ACK_OLD) begin
					if (!CPU_DO[0] && SPC_IRQ) SPC_IRQ <= 0;
					if (!CPU_DO[2] && VBI_IRQ) VBI_IRQ <= 0;
					if (!CPU_DO[4] && HBI_IRQ) HBI_IRQ <= 0;
					if (!CPU_DO[5] && TM1_IRQ) TM1_IRQ <= 0;
					if (!CPU_DO[7] && TM0_IRQ) TM0_IRQ <= 0;
				end
			end
		end
	end
	
	bit  [ 3: 0] INT_LVL;
	always_comb begin
		if (SPC_IRQ)
			INT_LVL <= 4'h1;
		else if (VBI_IRQ)
			INT_LVL <= 4'h5;
		else if (HBI_IRQ)
			INT_LVL <= 4'h9;
		else if (TM1_IRQ)
			INT_LVL <= 4'hB;
		else if (TM0_IRQ)
			INT_LVL <= 4'hF;
		else
			INT_LVL <= 4'h0;
	end
	assign CPU_IRL_N = ~INT_LVL;
	
	//RTC
	MSM6242 RTC
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.X32K_CE(X32K_CE),
		
		.CE(SYS_CE_R),
		.A(CPU_A[3:0]),
		.DI(CPU_DO[3:0]),
		.DO(RTC_DO),
		.WR_N(CPU_WE_N[0]),
		.RD_N(CPU_RD_N),
		.CS0_N(~RTC_SEL),
		.CS1(1'b1),
		.ALE(1'b1),
		
		.STDP()
	);
	
	//Protection
	SKNS_HIT HIT
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE_F(SYS_CE_F),
		.CE_R(SYS_CE_R),
		
		.A(CPU_A[8:0]),
		.DI(CPU_DO[15:0]),
		.DO(HIT_DO),
		.RD_N(CPU_RD_N),
		.WE_N(CPU_WE_N),
		.CS_N(~HIT_SEL),
		.WAIT_N()
	);

	bit          LOCK;
	always @(posedge CLK) begin
		bit          CPU_WE0_N_OLD;
		
		if (!RST_N) begin
			LOCK <= (REGION != 8'h41);
		end else if (EN) begin
			if (SYS_CE_R) begin
				CPU_WE0_N_OLD <= CPU_WE_N[0];
				if (LOCK_SEL && CPU_A[1:0] == 2'b00 && !CPU_WE_N[0] && CPU_WE0_N_OLD) begin
					case (REGION)
						8'h4A: LOCK <= ~(CPU_DO[7:0] == 8'h00);
						8'h55: LOCK <= ~(CPU_DO[7:0] == 8'h01);
						8'h4B: LOCK <= ~(CPU_DO[7:0] == 8'h02);
						8'h45: LOCK <= ~(CPU_DO[7:0] == 8'h03);
						8'h41: LOCK <= ~(CPU_DO[7:0] == 8'h01 || CPU_DO[7:0] == 8'h00);
						default:LOCK <= 0;
					endcase
				end
				
			end
		end
	end
	
	//IO
//	bit  [15: 0] HIT_REG0,HIT_REG2,HIT_REG14;
//	bit  [16: 0] HIT_RND;
//	always @(posedge CLK or negedge RST_N) begin
//		bit          CPU_RD_N_OLD,CPU_WE_N_OLD;
//		
//		if (!RST_N) begin
//			{HIT_REG0,HIT_REG2,HIT_REG14} <= '0;
//			HIT_RND <= 17'h00001;
//		end else if (EN) begin
//			if (SYS_CE_R) begin
//				CPU_WE_N_OLD <= &CPU_WE_N[1:0];
//				CPU_RD_N_OLD <= CPU_RD_N;
//				if (HIT_SEL && CPU_WE_N[1:0] != 2'b11 && CPU_WE_N_OLD) begin
//					case ({CPU_A[6:2],2'b00})
//						7'h00: HIT_REG0 <= CPU_DO[15:0];
//						7'h08: HIT_REG2 <= CPU_DO[15:0];
//						7'h38: HIT_REG14 <= CPU_DO[15:0];
//						default:;
//					endcase
//				end
//				if (HIT_SEL /*&& {CPU_A[6:2],2'b00} == 7'h28*/ && !CPU_RD_N && CPU_RD_N_OLD) begin
//					HIT_RND <= {HIT_RND[5]^HIT_RND[0],HIT_RND[16:1]};
//				end
//			end
//		end
//	end
//	
//	bit  [15: 0] HIT_DO;
//	always_comb begin
//		case ({CPU_A[6:2],2'b00})
//			7'h28: HIT_DO <= HIT_RND[15:0];//TODO
//			7'h40: HIT_DO <= HIT_REG0;
//			7'h48: HIT_DO <= HIT_REG2;
//			7'h50: HIT_DO <= HIT_REG14;
//			default: HIT_DO <= '0;
//		endcase
//	end
	
	always_comb begin
		case (CPU_A[2:0])
			3'h0: IO_DO <= P0;
			3'h1: IO_DO <= P1;
			3'h2: IO_DO <= P2;
			3'h3: IO_DO <= P3;
			3'h4: IO_DO <= P4;
			3'h5: IO_DO <= P5;
			3'h6: IO_DO <= P6;
			3'h7: IO_DO <= P7;
			default: IO_DO <= '1;
		endcase
	end
	
`ifdef DEBUG
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DBG_CLKDIV <= 0;
		end else if (EN) begin
			if (SYS_CE_R) begin
				DBG_CLKDIV <= DBG_CLKDIV + 1'd1;
			end
		end
	end
`endif

endmodule
