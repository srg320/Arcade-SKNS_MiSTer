module SKNS 
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              SYS_CE_F,
	input              SYS_CE_R,
	input              X33M_CE,
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
	
	output     [23: 1] SPR_ROM_A,
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
	output     [15: 0] BGB_RAM_DO,
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

	bit          DOT_CE;
	bit          HBLANK_N;
	bit          VBLANK_N;
	bit          VINC_PRE_N;
	bit          LAST_LINE_N;
	bit  [ 8: 0] BABY_HCNT;
	bit  [ 8: 0] BABY_VCNT;
	
	bit  [31: 0] VIEW3_DO;
	bit  [15: 0] ALTAIR_DO;
	bit          VIEW3_WAIT_N,ALTAIR_WAIT_N;
	bit          VIEW3_HINT,VIEW3_VINT;
	bit          HSPC_N;
	bit          BG1_RENDER;
	bit  [17: 0] BG0_PIX,BG1_PIX;
	
	bit  [31: 0] SPC_DO;
	bit          SPC_WAIT_N;
	bit  [15: 0] SPR_PIX;
	bit          SPC_INT;
	
	bit  [ 7: 0] YMZ_DO;
	bit          YMZ_CS_N;
	bit          YMZ_RES_N;
	bit          YMZ_IRQ_N;
	bit  [20: 0] YMZ_MA;
	bit  [ 9: 0] YMZ_MCS_N;

	bit  [ 3: 0] RTC_DO;
	
	bit  [ 7: 0] VEGA_DO;
	
	bit  [15: 0] HIT_DO;
	
	bit  [15: 0] CART_DO;
	bit          CART_WAIT_N;
	
	wire         BIOS_SEL  = (!CPU_CS0_N && CPU_A[24:22] == 3'b000);
	wire         IO_SEL    = (!CPU_CS0_N && CPU_A[24:22] == 3'b001);
	wire         NVRAM_SEL = (!CPU_CS0_N && CPU_A[24:22] == 3'b010);
	wire         YMZ_SEL   = (!CPU_CS0_N && CPU_A[24:22] == 3'b011);
	wire         RTC_SEL   = (!CPU_CS0_N && CPU_A[24:22] == 3'b100);
	wire         LOCK_SEL  = (!CPU_CS0_N && CPU_A[24:22] == 3'b110);
	wire         HIT_SEL   = (!CPU_CS1_N && CPU_A[24:20] == 5'b01111);
	wire         SPR_SEL   = (!CPU_CS1_N && CPU_A[24:22] == 3'b000);
	wire         VIEW3_SEL = (!CPU_CS1_N && CPU_A[24:22] == 3'b001);
	wire         ALTAIR_SEL= (!CPU_CS1_N && CPU_A[24:20] == 5'b01010);
	wire         GROM_SEL  = (!CPU_CS2_N && CPU_A[24:23] == 2'b00);
	wire         BGRAM_SEL = (!CPU_CS2_N && CPU_A[24:23] == 2'b01);
	
	
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
		
		.WAIT_N(VIEW3_WAIT_N & ALTAIR_WAIT_N & SPC_WAIT_N & CART_WAIT_N & MEM_WAIT_N),
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
						 IO_SEL ? {24'h000000,VEGA_DO} :
						 RTC_SEL ? {28'h0000000,RTC_DO} :
						 HIT_SEL    ? (LOCK ? 32'h00000000 : {16'h0000,HIT_DO}) :
						 SPR_SEL ? SPC_DO :
						 VIEW3_SEL ? VIEW3_DO :
						 ALTAIR_SEL ? {16'h0000,ALTAIR_DO} :
						 GROM_SEL ? {16'h0000,ROM_D} : 
						 BGRAM_SEL ? {16'h0000,CART_DO} : 
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
	
	
	SKNS_BABY BABY
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE_F(SYS_CE_F),
		.CE_R(SYS_CE_R),
		
		.DOT_CE(DOT_CE),
		.HCNT(BABY_HCNT),
		.VCNT(BABY_VCNT),
		.HBLANK_N(HBLANK_N),
		.VBLANK_N(VBLANK_N),
		.VINC_PRE_N(VINC_PRE_N),
		.LAST_LINE_N(LAST_LINE_N),
		
		.HSPC_N(HSPC_N),
		
		.DCLK(DCLK),
		.HS_N(HS_N),
		.VS_N(VS_N),
		.HBL_N(HBL_N),
		.VBL_N(VBL_N)
	);
	
	wire [ 1: 0] VIEW3_CE = CPU_A[21:20] | {2{~VIEW3_SEL}};
	SKNS_VIEW3 VIEW3
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE_F(SYS_CE_F),
		.CE_R(SYS_CE_R),
		
		.RES_N(RES_N),
		
		.A(CPU_A[14:2]),
		.DI(CPU_DO),
		.DO(VIEW3_DO),
		.RD_N(CPU_RD_N),
		.WE_N({4{CPU_WE_N[0]}}),
		.CE(VIEW3_CE),
		.WAIT_N(VIEW3_WAIT_N),
		
		.DOT_CE(DOT_CE),
		.HCNT(BABY_HCNT),
		.VCNT(BABY_VCNT),
		.BG1_RENDER(BG1_RENDER),
		
		.BG0_ROM_A(BGA_ROM_A),
		.BG0_ROM_D(BGA_ROM_D),
		.BG0_ROM_RD_N(BGA_ROM_RD_N),
		
		.BG1_ROM_A(BGB_ROM_A),
		.BG1_ROM_D(BGB_ROM_D),
		.BG1_ROM_RD_N(BGB_ROM_RD_N),
		
		.BG0_PIX(BG0_PIX),
		.BG1_PIX(BG1_PIX),
		
		.SCRN_EN(SCRN_EN[2:0])
	);
	
	SKNS_SPC2 SPC2
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE(X33M_CE),
		
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
		.OUT(SPR_PIX),
		
		.SPR_OFFSX(SPR_OFFSX),
		.SPR_OFFSY(SPR_OFFSY)
		
`ifdef DEBUG
      ,
		.DBG_EXT(DBG_EXT)
`endif
	);
	
	bit  [14: 0] PAL_RAM_A;
	bit  [15: 0] PAL_RAM_D,PAL_RAM_Q;
	bit          PAL_RAM_OE_N,PAL_RAM_WE_N,PAL_RAM_CE_N;
	SKNS_ALTAIR ALTAIR
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE_F(SYS_CE_F),
		.CE_R(SYS_CE_R),
		
		.RES_N(RES_N),
		
		.A(CPU_A[18:2]),
		.DI(CPU_DO[15:0]),
		.DO(ALTAIR_DO),
		.RD_N(CPU_RD_N),
		.WE_N(CPU_WE_N[1:0]),
		.CE_N(~ALTAIR_SEL),
		.WAIT_N(ALTAIR_WAIT_N),
		
		.DOT_CE(DOT_CE),
		
		.PAL_RAM_A(PAL_RAM_A),
		.PAL_RAM_D(PAL_RAM_D),
		.PAL_RAM_OE_N(PAL_RAM_OE_N),
		.PAL_RAM_WE_N(PAL_RAM_WE_N),
		.PAL_RAM_CE_N(PAL_RAM_CE_N),
		.PAL_RAM_Q(PAL_RAM_Q),
		
		.SPR_PIX(SPR_PIX),
		.BG0_PIX(BG0_PIX),
		.BG1_PIX(BG1_PIX),
		
		.R(R),
		.G(G),
		.B(B),
		
		.SCRN_EN(SCRN_EN[2:0])
	);
	
	SKNS_PAL_RAM PAL_RAM(CLK, PAL_RAM_A, PAL_RAM_D, {2{~PAL_RAM_CE_N & ~PAL_RAM_WE_N}}, PAL_RAM_A, PAL_RAM_Q);
	
	//Sound
	bit X33M_DIV;
	always @(posedge CLK) 
		X33M_DIV <= ~X33M_DIV;
		
	wire YMZ_CE = X33M_DIV & X33M_CE;
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

	//IO
	wire IO_WE_N = CPU_WE_N[0] | CPU_CS0_N;
	wire IO_OE_N = CPU_RD_N | CPU_CS0_N;
	wire VEGA_CE_N = ~IO_SEL;
	
	bit          VINC_PULSE;
	always @(posedge CLK or negedge RST_N) begin
		bit          VINC_PRE_N_OLD;
		
		if (!RST_N) begin
			VINC_PULSE <= 0;
		end else if (EN) begin
			if (SYS_CE_R) begin
				VINC_PRE_N_OLD <= VINC_PRE_N;
				VINC_PULSE <= VINC_PRE_N && !VINC_PRE_N_OLD;
			end
		end
	end
	
	SKNS_VEGA VEGA
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE_F(SYS_CE_F),
		.CE_R(SYS_CE_R),
		
		.RES_N(RES_N),
		
		.A(CPU_A[3:0]),
		.DI(CPU_DO[7:0]),
		.DO(VEGA_DO),
		.OE_N(IO_OE_N),
		.WE_N(IO_WE_N),
		.CE_N(VEGA_CE_N),
		
		.HBLANK_N(HBLANK_N),
		.VB_INT(~VBLANK_N),
		.SPC_INT(SPC_INT),
		.VINC_PULSE(VINC_PULSE),
		.IRL_N(CPU_IRL_N),
		
		.P0I(P0),
		.P1I(P1),
		.P2I(P2),
		.P3I(P3),
		.P4I(P4),
		.P5I(P5),
		.P7I(P7)
	);
	
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
	
	//Cartidge
	SKNS_CART CART
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.EN(EN),
		
		.CE_F(SYS_CE_F),
		.CE_R(SYS_CE_R),
		
		.RES_N(RES_N),
		
		.A(CPU_A[24:1]),
		.DI(CPU_DO[15:0]),
		.DO(CART_DO),
		.RD_N(CPU_RD_N),
		.WE_N(CPU_WE_N[1:0]),
		.CS_N(CPU_CS2_N),
		.WAIT_N(CART_WAIT_N),
		
		.DOT_CE(DOT_CE),
		.RENDER(BG1_RENDER),
		
		.BG1_RAM_A(BGB_RAM_A),
		.BG1_RAM_DI(BGB_ROM_D),
		.BG1_RAM_DO(BGB_RAM_DO),
		.BG1_RAM_WE_N(BGB_RAM_WE_N),
		.BG1_RAM_RD_N(BGB_RAM_RD_N)
	);
	
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
