//license:BSD-3-Clause (derived from MAME's ymz280b)

// synopsys translate_off
`define SIM
// synopsys translate_on

module YMZ280B
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE,
	
	input              A,
	input      [ 7: 0] DI,
	output     [ 7: 0] DO,
	input              RD_N,
	input              WR_N,
	input              CS_N,
	input              IC_N,
	
	output             IRQ_N,
	
	output     [23: 0] MA,
	input      [ 7: 0] MDI,
	output     [ 7: 0] MDO,
	output             MOE_N,
	output             MWR_N,
	output             MCE_N,
	
	output     [15: 0] OUT_L,
	output     [15: 0] OUT_R,
	
	input      [ 2: 0] SND_EN
	
`ifdef DEBUG
                      ,
	output signed [15:0] PAN_L_DBG,
	output signed [15:0] PAN_R_DBG
`endif
);

	import YMZ280B_PKG::*;
	
	bit  [23: 0] MEMADDR;
	bit  [ 7: 0] MEMDAT;
	bit  [ 7: 0] FLG,ENC;
	bit          KENB,MENB,IENB;
	bit  [ 1: 0] TST;
	
	OP2_t        OP2;
	OP3_t        OP3;
	OP4_t        OP4;
	OP5_t        OP5;
	OP6_t        OP6;
	
	bit  [23: 0] WD_ADDR;
	bit          WD_READ;
	
	bit  [23: 0] MEM_A;
	bit  [ 7: 0] MEM_D;
	bit  [ 7: 0] MEM_Q;
	bit          MEM_WR;
	bit          MEM_RD;
	
	bit  [ 7: 0] REG_A;
	bit  [ 7: 0] REG_D;
//	bit  [ 7: 0] REG_Q;
	bit          REG_WR;
	bit          REG_RD;
	
	bit  [ 7: 0] STATUS;
	
	wire         RES_N = IC_N;
	
	bit          CLK_RES;
	always @(posedge CLK) begin
		bit          RST_N_OLD;
	
		if (CE) begin
			RST_N_OLD <= RST_N;
			CLK_RES <= RST_N & ~RST_N_OLD;
		end
	end
	
	bit  [ 1: 0] CLK_DIV;
	bit  [ 2: 0] CYCLE_NUM;
	always @(posedge CLK) begin
		if (CLK_RES) begin
			CLK_DIV <= '0;
			CYCLE_NUM <= '0;
		end
		else if (CE) begin
			CLK_DIV <= CLK_DIV + 2'd1;
			if (CLK_DIV == 2'd2) begin
				CLK_DIV <= '0;
				CYCLE_NUM <= CYCLE_NUM + 3'd1;
			end
		end 
	end
	
	wire SLOT0_EN = (CYCLE_NUM[2:1] == 2'b01);
	wire SLOT1_EN = (CYCLE_NUM[2:1] == 2'b11);
	
	wire CYCLE0_CE = ~CYCLE_NUM[0] & CLK_DIV == 2'd2 & CE;
	wire CYCLE1_CE =  CYCLE_NUM[0] & CLK_DIV == 2'd2 & CE;
	wire SLOT0_CE = SLOT0_EN & CYCLE1_CE;
	wire SLOT1_CE = SLOT1_EN & CYCLE1_CE;
	
	//Operation 1: PG, KEY ON/OFF
	bit  [ 2: 0] SLOT;
	bit          RST;
	bit  [ 8: 0] OP1_FNUM;
	bit          OP1_KON;
	bit  [ 1: 0] OP1_MO;
	bit          OP1_LOOP;
	always @(posedge CLK or negedge RST_N) begin
		bit          REG_KON_OLD[8];
		bit  [ 8: 0] PHASE;
		
		if (!RST_N) begin
			OP1_FNUM <= '0;
			{OP1_KON,OP1_MO,OP1_LOOP} <= '0;
			REG_KON_OLD <= '{8{0}};
			SLOT <= '0;
			RST <= 1;
			OP2 <= OP2_RESET;
		end else if (!RES_N) begin
			OP1_FNUM <= '0;
			{OP1_KON,OP1_MO,OP1_LOOP} <= '0;
			REG_KON_OLD <= '{8{0}};
			SLOT <= '0;
			RST <= 1;
			OP2 <= OP2_RESET;
		end else begin
			if (CYCLE0_CE) begin
				OP1_FNUM <= {REG_KON_Q[0],REG_FN_Q};
				{OP1_KON,OP1_MO,OP1_LOOP} <= REG_KON_Q[7:4];
			end
			
			//Key on/off
			if (SLOT1_CE) begin
				OP2.KON <= OP1_KON && !REG_KON_OLD[SLOT] && KENB;
				OP2.KOFF <= !OP1_KON && REG_KON_OLD[SLOT];
				REG_KON_OLD[SLOT] <= OP1_KON;

				OP2.SLOT <= SLOT;
				OP2.RST <= RST;
				OP2.PHASE <= OP1_FNUM & {OP1_MO[1],8'hFF};
				OP2.MO <= OP1_MO;
				OP2.LOOP <= OP1_LOOP;

				SLOT <= SLOT + 3'd1;
				if (SLOT == 3'd7) begin
					RST <= 0;
				end
			end
		end
	end
	
	//Operation 2: MD read, ADP
	bit  [ 1: 0] OP2_DATA_BIT;
	bit  [23: 0] OP2_ST;
	bit  [23: 0] OP2_LS;
	bit  [23: 0] OP2_LE;	
	bit  [23: 0] OP2_EN;
	always @(posedge CLK or negedge RST_N) begin
		bit  [ 0: 0] PHASE_INT;	//New phase integer
		bit  [ 8: 0] PHASE_FRAC;	//New phase fractional
		bit  [ 8: 0] CUR_PHASE_FRAC;//Current phase fractional
		bit  [24: 0] CUR_SA;		//Sample address 24.1
		bit  [24: 0] NEXT_SA,NEW_SA;//Calc address 24.1
		bit  [24: 0] SA;
		bit          ALLOW,END;
		bit          NEW_PLAY,CUR_PLAY;
		
		if (!RST_N) begin
			OP3 <= OP3_RESET;
			OP2_ST <= '0;
			OP2_LS <= '0;
			OP2_LE <= '0;
			OP2_EN <= '0;
			WD_READ <= 0;
		end else if (!RES_N) begin
			OP3 <= OP3_RESET;
			OP2_ST <= '0;
			OP2_LS <= '0;
			OP2_LE <= '0;
			OP2_EN <= '0;
			WD_READ <= 0;
		end else begin
			if (CYCLE0_CE) begin
				OP2_ST <= REG_ST_Q;
				OP2_LS <= REG_LS_Q;
				OP2_LE <= REG_LE_Q;
				OP2_EN <= REG_EN_Q;
			end
		
			{CUR_PLAY,CUR_SA} = OP2.KON ? '0 : SA_RAM_Q;
			
			//Phase accum
			CUR_PHASE_FRAC = OP2.KON ? '0 : PHASE_FRAC_RAM_Q;
			
			if (OP2.RST)
				{PHASE_INT,PHASE_FRAC} = '0;
			else
				{PHASE_INT,PHASE_FRAC} = {1'b0,CUR_PHASE_FRAC} + {1'b0,OP2.PHASE + 9'd1};
				
			if (PHASE_INT)
				case (OP2.MO)
					2'b00: NEXT_SA = '0;
					2'b01: NEXT_SA = CUR_SA + 25'h1;
					2'b10: NEXT_SA = CUR_SA + 25'h2;
					2'b11: NEXT_SA = CUR_SA + 25'h4;
				endcase
			else
				NEXT_SA = CUR_SA;
						
			END = 0;
			NEW_PLAY = CUR_PLAY;
			NEW_SA = NEXT_SA;
			if (SLOT1_CE) begin
				if (OP2.RST || OP2.KOFF || OP2.MO == 2'b00) begin
					NEW_SA = '0;
					NEW_PLAY = 0;
				end else if (OP2.KON) begin
					NEW_SA = {OP2_ST,1'b0};
					NEW_PLAY = 1;
				end else begin
					if (NEXT_SA == {OP2_LE,~OP2.MO[1]} && OP2.LOOP) begin
						NEW_SA = {OP2_LS,1'b0};
					end
					else if (NEXT_SA == {OP2_EN,~OP2.MO[1]} && !OP2.LOOP) begin
						NEW_SA = {OP2_EN,1'b0};
						NEW_PLAY = 0;
						END = 1;
					end
				end
				SA_RAM_D <= {NEW_PLAY,NEW_SA};
				
				OP3.SLOT <= OP2.SLOT;
				OP3.RST <= OP2.RST;
				OP3.KON <= OP2.KON;
				OP3.KOFF <= OP2.KOFF;
				OP3.END <= END;
				OP3.MO <= OP2.MO;
				OP3.SA <= NEW_SA[24:1];
				OP3.SN <= NEW_SA[0];
				OP3.PHASE_OVF <= PHASE_INT;
				OP3.PHASE_FRAC <= PHASE_FRAC;
				
				WD_READ <= NEW_PLAY;
				
				PHASE_FRAC_RAM_D <= NEW_PLAY ? PHASE_FRAC : '0;
			end
		end
	end
	bit [25:0] SA_RAM_D;
	bit [25:0] SA_RAM_Q;
	YMZ_CH_RAM #(3,26) SA_RAM(CLK, OP3.SLOT, SA_RAM_D, SLOT1_CE, OP2.SLOT, SA_RAM_Q);
	
	bit  [ 8:0] PHASE_FRAC_RAM_D;
	bit  [ 8:0] PHASE_FRAC_RAM_Q;
	YMZ_CH_RAM #(3,9) PHASE_FRAC_RAM(CLK, OP3.SLOT, PHASE_FRAC_RAM_D, SLOT1_CE, OP2.SLOT, PHASE_FRAC_RAM_Q);
	
	//Operation 3: WD read,ADPCM 	
	assign WD_ADDR = OP3.SA + (!CYCLE_NUM[1] ? 24'd0 : 24'd1);
	
	always @(posedge CLK or negedge RST_N) begin
		bit  [15: 0] WD;
		bit  [15: 0] ADPCM_CUR_SIGNAL,ADPCM_NEW_SIGNAL;
		bit  [14: 0] ADPCM_CUR_STEP,ADPCM_NEW_STEP;
		bit  [15: 0] CUR_WAVE;
		
		if (!RST_N) begin
			OP4 <= OP4_RESET;
		end else if (!RES_N) begin
			OP4 <= OP4_RESET;
		end else begin
			if (CYCLE1_CE) begin
				case (CYCLE_NUM[2:1])
					2'h1: WD[15: 8] <= MEM_D;
					2'h2: WD[ 7: 0] <= MEM_D;
				endcase
			end
			
			if (SLOT1_CE) begin
				{ADPCM_CUR_STEP,ADPCM_CUR_SIGNAL} = ADPCM_RAM_Q;
				if (OP3.KON) begin
					{ADPCM_NEW_STEP,ADPCM_NEW_SIGNAL} = {15'h007F,16'h0000};
				end else if (OP3.PHASE_OVF) begin
					ADPCM_NEW_SIGNAL = ADPCMSignalCalc(ADPCM_CUR_SIGNAL, ADPCM_CUR_STEP, !OP3.SN ? WD[15:12] : WD[11:8]);
					ADPCM_NEW_STEP = ADPCMStepCalc(ADPCM_CUR_STEP, !OP3.SN ? WD[15:12] : WD[11:8]);
				end else begin
					{ADPCM_NEW_STEP,ADPCM_NEW_SIGNAL} = {ADPCM_CUR_STEP,ADPCM_CUR_SIGNAL};
				end
				ADPCM_RAM_D <= {ADPCM_NEW_STEP,ADPCM_NEW_SIGNAL};
			end
			
			case (OP3.MO)
				2'b00: CUR_WAVE = 16'h0000;
				2'b01: CUR_WAVE = ADPCM_NEW_SIGNAL;
				2'b10: CUR_WAVE = {WD[15:8],8'h00};
				2'b11: CUR_WAVE = WD;
			endcase
			
			if (SLOT1_CE) begin
				OP4.SLOT <= OP3.SLOT;
				OP4.RST <= OP3.RST;
				OP4.KON <= OP3.KON;
				OP4.KOFF <= OP3.KOFF;
				OP4.MODF <= OP3.PHASE_FRAC[8:3];
				OP4.PHASE_OVF <= OP3.PHASE_OVF;
				OP4.WD <= CUR_WAVE;
			end
		end
	end
	bit [30:0] ADPCM_RAM_D;
	bit [30:0] ADPCM_RAM_Q;
	YMZ_CH_RAM #(3,31) ADPCM_RAM(CLK, OP4.SLOT, ADPCM_RAM_D, SLOT1_CE, OP3.SLOT, ADPCM_RAM_Q);
	
	bit [15:0] PWD_RAM_D;
	bit [15:0] PREV_WAVE_RAM0_Q,PREV_WAVE_RAM1_Q;
	YMZ_CH_RAM #(3,16) PWD_RAM0(CLK, OP4.SLOT, OP4.WD          , OP4.PHASE_OVF & SLOT1_CE, OP4.SLOT, PREV_WAVE_RAM0_Q);
	YMZ_CH_RAM #(3,16) PWD_RAM1(CLK, OP4.SLOT, PREV_WAVE_RAM0_Q, OP4.PHASE_OVF & SLOT1_CE, OP4.SLOT, PREV_WAVE_RAM1_Q);
	
	//Operation 4: Interpolation
	always @(posedge CLK or negedge RST_N) begin
		bit  [15: 0] PWD;
		
		if (!RST_N) begin
			OP5 <= OP5_RESET;
		end else if (!RES_N) begin
			OP5 <= OP5_RESET;
		end else begin
			if (CYCLE1_CE) begin
				PWD <= OP4.PHASE_OVF ? PREV_WAVE_RAM0_Q : PREV_WAVE_RAM1_Q; 
			end
			if (SLOT1_CE) begin
				OP5.SLOT <= OP4.SLOT;
				OP5.RST <= OP4.RST;
				OP5.KON <= OP4.KON;
				OP5.KOFF <= OP4.KOFF;
				OP5.WD <= Interpolate(/*OP4.*/PWD, OP4.WD, OP4.MODF);
			end
		end
	end
	
	//Operation 5: Level calculation
	bit  [ 7: 0] OP5_TL;
	bit          OP5_LDIR;
	always @(posedge CLK or negedge RST_N) begin	
		if (!RST_N) begin
			OP6 <= OP6_RESET;
			OP5_TL <= '0;
		end else if (!RES_N) begin
			OP6 <= OP6_RESET;
			OP5_TL <= '0;
		end else begin
			if (CYCLE0_CE) begin
				OP5_TL <= REG_TL_Q;
			end
			
			if (SLOT1_CE) begin
				OP6.SLOT <= OP5.SLOT;
				OP6.RST <= OP5.RST;
				OP6.KON <= OP5.KON;
				OP6.KOFF <= OP5.KOFF;
				OP6.SD <= VolCalc(OP5.WD, OP5_TL);
			end
		end
	end
	
	//Operation 6: Accumulate
	bit  [ 3: 0] OP6_PAN;
	bit  [17: 0] ACC_L,ACC_R;
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] S;
		bit signed [15:0] TEMP;
		bit signed [15:0] PAN_L,PAN_R;
		
		if (!RST_N) begin
			OP6_PAN <= '0;
			ACC_L <= 0;
			ACC_R <= 0;
		end else if (!RES_N) begin
			OP6_PAN <= '0;
			ACC_L <= 0;
			ACC_R <= 0;
		end else begin
			if (CYCLE0_CE) begin
				OP6_PAN <= REG_PAN_Q[3:0];
			end
			
			S = OP6.SLOT;
			PAN_L = PanLCalc(OP6.SD,OP6_PAN);
			PAN_R = PanRCalc(OP6.SD,OP6_PAN);
			
			if (SLOT1_CE) begin
				if (S == 3'd0) begin
					ACC_L <= {{2{PAN_L[15]}},PAN_L[15:0]};
					ACC_R <= {{2{PAN_R[15]}},PAN_R[15:0]};
				end else begin
					ACC_L <= ACC_L + {{2{PAN_L[15]}},PAN_L[15:0]};
					ACC_R <= ACC_R + {{2{PAN_R[15]}},PAN_R[15:0]};
				end
			end
			
`ifdef DEBUG
			PAN_L_DBG <= PAN_L;
			PAN_R_DBG <= PAN_R;
`endif
		end
	end
	
	//Out
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			OUT_L <= '0;
			OUT_R <= '0;
		end else if (!RES_N) begin
			
		end else begin
			if (OP6.SLOT == 5'd0 && CYCLE_NUM[2:1] == 2'b00 && CYCLE1_CE) begin
				OUT_L <= (!SND_EN[0] ? 16'h0000 : TrimWave(ACC_L));
				OUT_R <= (!SND_EN[1] ? 16'h0000 : TrimWave(ACC_R));
			end
		end
	end
	
	//Memory/Registers
	bit          MEM_WREQ,MEM_RREQ;
	always @(posedge CLK or negedge RST_N) begin
		bit         WR_N_OLD,RD_N_OLD,CS_N_OLD;
		bit [ 1: 0] REG_RD_DELAY;
		bit         CH_PLAY,CH_PLAY_OLD[8];
		bit         MEM_START;
		
		if (!RST_N) begin
			MEMADDR <= '0;
			MEMDAT <= '0;
			KENB <= 0;
			MENB <= 0;
			IENB <= 0;
			TST <= '0;
			ENC <= '0;
			FLG <= '0;
//			REG_Q <= '0;
		end else begin
			if (!RES_N) begin
				MEMADDR <= '0;
				MEMDAT <= '0;
				KENB <= 0;
				MENB <= 0;
				IENB <= 0;
				TST <= '0;
				ENC <= '0;
				FLG <= '0;
				
				MEM_A <= '0;
				MEM_WR <= 0;
				MEM_RD <= 0;
			end else if (CE) begin
				//Register access
				if (CYCLE1_CE) begin
					REG_RD <= 0;
					REG_WR <= 0;
				end
				
				CH_PLAY = SA_RAM_Q[25];
				if (SLOT1_CE) begin
					CH_PLAY_OLD[OP2.SLOT] <= CH_PLAY;
					if (!CH_PLAY && CH_PLAY_OLD[OP2.SLOT]) FLG[OP2.SLOT] <= 1;
				end
				
				WR_N_OLD <= WR_N;
				RD_N_OLD <= RD_N;
				CS_N_OLD <= CS_N;
				if (!RD_N && RD_N_OLD && !CS_N && A == 1'b0) begin
					REG_RD <= 1;
				end
				if (!RD_N && RD_N_OLD && !CS_N && A == 1'b1) begin
					STATUS <= FLG;
					FLG <= '0;
				end
				if (!WR_N && WR_N_OLD && !CS_N) begin
					case (A)
						1'b0: REG_A <= DI;
						1'b1: begin
							REG_D <= DI;
							REG_WR <= 1;
						end
					endcase
				end
				
				REG_RD_DELAY[0] <= REG_RD;
				REG_RD_DELAY[1] <= REG_RD_DELAY[0];
				if (REG_WR && CYCLE1_CE) begin
					case (REG_A)
						8'h84: MEMADDR[23:16] <= REG_D;
						8'h85: MEMADDR[15:8] <= REG_D;
						8'h86: MEMADDR[7:0] <= REG_D;
						8'h87: MEMDAT <= REG_D; 
						8'hFE: ENC <= REG_D;
						8'hFF: {KENB,MENB,IENB,TST} <= {REG_D[7:6],REG_D[4],REG_D[1:0]};
						default:;
					endcase
					if (REG_A == 8'h87) MEM_WREQ <= 1;
					if (REG_A == 8'h86) MEM_RREQ <= 1;
				end
				if (REG_RD_DELAY == 2'b01) begin
					MEM_RREQ <= 1;
				end
				
				//Memory access
				if (CYCLE1_CE) begin
					if (MEM_RD && MENB) begin
						MEM_D <= MDI;
					end
//					if ((MEM_RD || MEM_WR) && MENB) begin
//						MEMDAT <= MDI;
//						MEMADDR <= MEMADDR + 24'd1;
//					end
					MEM_WR <= 0;
					MEM_RD <= 0;
				end
				
				MEM_START <= CYCLE1_CE;
				if (MEM_START && WD_READ && MENB) begin
					MEM_A <= WD_ADDR;
					MEM_WR <= 0;
					MEM_RD <= 1;
				end
//				else if (MEM_START && (MEM_WREQ || MEM_RREQ) && MENB) begin
//					MEM_A <= MEMADDR;
//					MEM_WR <= MEM_WREQ;
//					MEM_RD <= MEM_RREQ;
//					MEM_WREQ <= 0;
//					MEM_RREQ <= 0;
//				end
			end
		end
	end
	assign IRQ_N = IENB ? ~|(FLG & ENC) : 1'b1;
	assign DO = !A ? MEMDAT : STATUS;
	
	assign MA = MEM_A[23:0];
	assign MDO = MEMDAT;
	assign MWR_N = ~MEM_WR;
	assign MOE_N = ~MEM_RD;
	assign MCE_N = ~(MEM_WR | MEM_RD);


	wire         REG_FN_SEL = (REG_A ==? 8'b000???00);
	bit  [ 7: 0] REG_FN_Q;
	YMZ_REG_RAM #(3,8) REG_FN   (CLK,     RST ?     SLOT : REG_A[4:2],     RST ? '0 : REG_D,     RST ? 1'b1 : (REG_WR & REG_FN_SEL  & CYCLE1_CE),     SLOT, REG_FN_Q);
	
	wire         REG_KON_SEL = (REG_A ==? 8'b000???01);
	bit  [ 7: 0] REG_KON_Q;
	YMZ_REG_RAM #(3,8) REG_KON  (CLK,     RST ?     SLOT : REG_A[4:2],     RST ? '0 : REG_D,     RST ? 1'b1 : (REG_WR & REG_KON_SEL & CYCLE1_CE),     SLOT, REG_KON_Q);
	
	wire        REG_TL_SEL = (REG_A ==? 8'b000???10);
	bit [ 7: 0] REG_TL_Q;
	YMZ_REG_RAM #(3,8) REG_TL   (CLK,     RST ? OP5.SLOT : REG_A[4:2],     RST ? '0 : REG_D,     RST ? 1'b1 : (REG_WR & REG_TL_SEL  & CYCLE1_CE), OP5.SLOT, REG_TL_Q);
	
	wire        REG_PAN_SEL = (REG_A ==? 8'b000???11);
	bit [ 7: 0] REG_PAN_Q;
	YMZ_REG_RAM #(3,8) REG_PAN  (CLK,     RST ? OP6.SLOT : REG_A[4:2],     RST ? '0 : REG_D,     RST ? 1'b1 : (REG_WR & REG_PAN_SEL & CYCLE1_CE), OP6.SLOT, REG_PAN_Q);
	
	wire        REG_STH_SEL = (REG_A ==? 8'b001???00);
	wire        REG_STM_SEL = (REG_A ==? 8'b010???00);
	wire        REG_STL_SEL = (REG_A ==? 8'b011???00);
	bit [23: 0] REG_ST_Q;
	YMZ_REG_RAM #(3,8) REG_STH  (CLK, OP2.RST ? OP2.SLOT : REG_A[4:2], OP2.RST ? '0 : REG_D, OP2.RST ? 1'b1 : (REG_WR & REG_STH_SEL & CYCLE1_CE), OP2.SLOT, REG_ST_Q[23:16]);
	YMZ_REG_RAM #(3,8) REG_STM  (CLK, OP2.RST ? OP2.SLOT : REG_A[4:2], OP2.RST ? '0 : REG_D, OP2.RST ? 1'b1 : (REG_WR & REG_STM_SEL & CYCLE1_CE), OP2.SLOT, REG_ST_Q[15:8]);
	YMZ_REG_RAM #(3,8) REG_STL  (CLK, OP2.RST ? OP2.SLOT : REG_A[4:2], OP2.RST ? '0 : REG_D, OP2.RST ? 1'b1 : (REG_WR & REG_STL_SEL & CYCLE1_CE), OP2.SLOT, REG_ST_Q[7:0]);
	
	wire        REG_LSH_SEL = (REG_A ==? 8'b001???01);
	wire        REG_LSM_SEL = (REG_A ==? 8'b010???01);
	wire        REG_LSL_SEL = (REG_A ==? 8'b011???01);
	bit [23: 0] REG_LS_Q;
	YMZ_REG_RAM #(3,8) REG_LSH  (CLK, OP2.RST ? OP2.SLOT : REG_A[4:2], OP2.RST ? '0 : REG_D, OP2.RST ? 1'b1 : (REG_WR & REG_LSH_SEL & CYCLE1_CE), OP2.SLOT, REG_LS_Q[23:16]);
	YMZ_REG_RAM #(3,8) REG_LSM  (CLK, OP2.RST ? OP2.SLOT : REG_A[4:2], OP2.RST ? '0 : REG_D, OP2.RST ? 1'b1 : (REG_WR & REG_LSM_SEL & CYCLE1_CE), OP2.SLOT, REG_LS_Q[15:8]);
	YMZ_REG_RAM #(3,8) REG_LSL  (CLK, OP2.RST ? OP2.SLOT : REG_A[4:2], OP2.RST ? '0 : REG_D, OP2.RST ? 1'b1 : (REG_WR & REG_LSL_SEL & CYCLE1_CE), OP2.SLOT, REG_LS_Q[7:0]);
	
	wire        REG_LEH_SEL = (REG_A ==? 8'b001???10);
	wire        REG_LEM_SEL = (REG_A ==? 8'b010???10);
	wire        REG_LEL_SEL = (REG_A ==? 8'b011???10);
	bit [23: 0] REG_LE_Q;
	YMZ_REG_RAM #(3,8) REG_LEH  (CLK, OP2.RST ? OP2.SLOT : REG_A[4:2], OP2.RST ? '0 : REG_D, OP2.RST ? 1'b1 : (REG_WR & REG_LEH_SEL & CYCLE1_CE), OP2.SLOT, REG_LE_Q[23:16]);
	YMZ_REG_RAM #(3,8) REG_LEM  (CLK, OP2.RST ? OP2.SLOT : REG_A[4:2], OP2.RST ? '0 : REG_D, OP2.RST ? 1'b1 : (REG_WR & REG_LEM_SEL & CYCLE1_CE), OP2.SLOT, REG_LE_Q[15:8]);
	YMZ_REG_RAM #(3,8) REG_LEL  (CLK, OP2.RST ? OP2.SLOT : REG_A[4:2], OP2.RST ? '0 : REG_D, OP2.RST ? 1'b1 : (REG_WR & REG_LEL_SEL & CYCLE1_CE), OP2.SLOT, REG_LE_Q[7:0]);
	
	wire        REG_ENH_SEL = (REG_A ==? 8'b001???11);
	wire        REG_ENM_SEL = (REG_A ==? 8'b010???11);
	wire        REG_ENL_SEL = (REG_A ==? 8'b011???11);
	bit [23: 0] REG_EN_Q;
	YMZ_REG_RAM #(3,8) REG_ENH  (CLK, OP2.RST ? OP2.SLOT : REG_A[4:2], OP2.RST ? '0 : REG_D, OP2.RST ? 1'b1 : (REG_WR & REG_ENH_SEL & CYCLE1_CE), OP2.SLOT, REG_EN_Q[23:16]);
	YMZ_REG_RAM #(3,8) REG_ENM  (CLK, OP2.RST ? OP2.SLOT : REG_A[4:2], OP2.RST ? '0 : REG_D, OP2.RST ? 1'b1 : (REG_WR & REG_ENM_SEL & CYCLE1_CE), OP2.SLOT, REG_EN_Q[15:8]);
	YMZ_REG_RAM #(3,8) REG_ENL  (CLK, OP2.RST ? OP2.SLOT : REG_A[4:2], OP2.RST ? '0 : REG_D, OP2.RST ? 1'b1 : (REG_WR & REG_ENL_SEL & CYCLE1_CE), OP2.SLOT, REG_EN_Q[7:0]); 
	
endmodule

module YMZ_CH_RAM
#(
	parameter aw = 3, dw = 8
)
(
	input            CLK,
	
	input  [aw-1: 0] WRADDR,
	input  [dw-1: 0] DATA,
	input            WREN,
	input  [aw-1: 0] RDADDR,
	output [dw-1: 0] Q
);

`ifdef SIM
	
	reg [dw-1:0] MEM [2**aw];
	
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
		Q <= MEM[RDADDR];
	end
	
`else

	wire [dw-1:0] sub_wire0;
	
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RDADDR),
				.wraddress (WRADDR),
				.wren (WREN),
				.byteena (1'b1),
				.q (sub_wire0),
				.aclr (1'b0),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
//		altdpram_component.byte_size = 8,
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = dw,
		altdpram_component.widthad = aw,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
	
	/*
	altsyncram	altsyncram_component (
				.address_a (WRADDR),
				.byteena_a (1'b1),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (WREN),
				.address_b (RDADDR),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({dw{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
//		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**aw,
		altsyncram_component.numwords_b = 2**aw,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = aw,
		altsyncram_component.widthad_b = aw,
		altsyncram_component.width_a = dw,
		altsyncram_component.width_b = dw,
		altsyncram_component.width_byteena_a = 1;
	*/
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module YMZ_REG_RAM
#(
	parameter aw = 3, dw = 8
)
(
	input            CLK,
	
	input  [aw-1: 0] WRADDR,
	input  [dw-1: 0] DATA,
	input            WREN,
	input  [aw-1: 0] RDADDR,
	output [dw-1: 0] Q
);

`ifdef SIM
	
	reg [dw-1:0] MEM [2**aw];
	
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
		Q <= MEM[RDADDR];
	end
	
`else

	wire [dw-1:0] sub_wire0;
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RDADDR),
				.wraddress (WRADDR),
				.wren (WREN),
				.byteena (1'b1),
				.q (sub_wire0),
				.aclr (1'b0),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
//		altdpram_component.byte_size = 8,
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = dw,
		altdpram_component.widthad = aw,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
	
	/*
	altsyncram	altsyncram_component (
				.address_a (WRADDR),
				.byteena_a (1'b1),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (WREN),
				.address_b (RDADDR),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({dw{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
//		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**aw,
		altsyncram_component.numwords_b = 2**aw,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = aw,
		altsyncram_component.widthad_b = aw,
		altsyncram_component.width_a = dw,
		altsyncram_component.width_b = dw,
		altsyncram_component.width_byteena_a = 1;
	*/
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

