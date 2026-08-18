//license:BSD-3-Clause (derived from MAME's ymz280b)

package YMZ280B_PKG;
	
	typedef struct packed
	{
		bit [ 2: 0] SLOT;	//
		bit         RST;	//
		bit         KON;	//
		bit         KOFF;	//
		bit [ 8: 0] PHASE;
		bit [ 1: 0] MO;
		bit         LOOP;
	} OP2_t;
	parameter OP2_t OP2_RESET = '{3'h0,1'b0,1'b0,1'b0,9'h000,2'b00,1'b0};
	
	typedef struct packed
	{
		bit [ 2: 0] SLOT;	//
		bit         RST;	//
		bit         KON;	//
		bit         KOFF;	//
		bit         END;	//
		bit         PHASE_OVF;
		bit [ 8: 0] PHASE_FRAC;//Phase fractional
		bit [23: 0] SA;	//Sample address 24.0
		bit         SN;	//Sample nibble 0.1
		bit [ 1: 0] MO;
	} OP3_t;
	parameter OP3_t OP3_RESET = '{3'h0,1'b0,1'b0,1'b0,1'b0,1'b0,9'h000,24'h000000,1'b0,2'b00};
	
	typedef struct packed
	{
		bit [ 2: 0] SLOT;	//
		bit         RST;	//
		bit         KON;	//
		bit         KOFF;	//
		bit [ 5: 0] MODF;	//Modulation fractional
		bit         PHASE_OVF;
		bit [15: 0] WD;	//Wave form data
	} OP4_t;
	parameter OP4_t OP4_RESET = '{3'h0,1'b0,1'b0,1'b0,6'h00,1'b0,16'h0000};
	
	typedef struct packed
	{
		bit [ 2: 0] SLOT;	//
		bit         RST;	//
		bit         KON;	//
		bit         KOFF;	//
		bit [15: 0] WD;	//Wave form data
	} OP5_t;
	parameter OP5_t OP5_RESET = '{3'h0,1'b0,1'b0,1'b0,16'h0000};
	
	typedef struct packed
	{
		bit [ 2: 0] SLOT;	//
		bit         RST;	//
		bit         KON;	//
		bit         KOFF;	//
		bit [15: 0] SD;	//Slot out data
	} OP6_t;
	parameter OP6_t OP6_RESET = '{3'h00,1'b0,1'b0,1'b0,16'h0000};
	
	function bit signed [15:0] ADPCMSignalCalc(bit signed [15:0] SIGNAL, bit [14:0] STEP, bit [3:0] WD);
		bit [4:0] DIFF;
		bit [19:0] MULT;
		bit [16:0] SUM;
		
		DIFF = {WD[3],WD[2:0]^{3{WD[3]}},1'b1};
		MULT = $signed({1'b0,STEP}) * $signed(DIFF);
		SUM = $signed({SIGNAL[15],SIGNAL}) + $signed($signed(MULT)>>>3);
		
		return SUM[16:15] == 2'b01 ? 16'h7FFF : SUM[16:15] == 2'b10 ? 16'h8000 : SUM[15:0];
	endfunction
	
	function bit [14:0] ADPCMStepCalc(bit [14:0] STEP, bit [3:0] WD);
		bit [9:0] SCALE,SCALE_TBL[8];
		bit [24:0] MULT;
		bit [16:0] RET;
		
		SCALE_TBL = '{10'h0E6, 10'h0E6, 10'h0E6, 10'h0E6, 10'h133, 10'h199, 10'h200, 10'h266};
		
		SCALE = SCALE_TBL[WD[2:0]];
		MULT = $unsigned(STEP) * $unsigned(SCALE);
		RET = MULT[24:8];
		
		return RET > 17'h06000 ? 15'h6000 : RET < 17'h0007F ? 15'h007F : RET[14:0];
	endfunction
	
	function bit [15:0] Interpolate(input bit [15:0] WAVE0, input bit [15:0] WAVE1, bit [5:0] PHASE);
		bit [ 6:0] PHASE_NEG;
		bit [21:0] TEMP0,TEMP1;
		bit [21:0] SUM;
		
		PHASE_NEG = 7'h40 - PHASE;
		TEMP0 = $signed(WAVE0) * PHASE_NEG;
		TEMP1 = $signed(WAVE1) * PHASE;
		SUM = $signed(TEMP0) + $signed(TEMP1);
	
		return SUM[21:6];
	endfunction
	
	function bit signed [15:0] VolCalc(bit signed [15:0] WAVE, bit [7:0] LEVEL);
		bit [23:0] MULT;
		bit [23:0] RES;
		
		MULT = $signed(WAVE) * {1'b0,LEVEL};
		RES = $signed($signed(MULT)>>>9);
		
		return RES[15:0];
	endfunction
	
	function bit signed [15:0] PanLCalc(bit signed [15:0] WAVE, bit [3:0] PAN);
		bit [3:0] S;
		bit [15:0] TEMP;
		
		S = 4'd0 + PAN;
		TEMP = $signed($signed(WAVE)>>>{~PAN[2:0],1'b0});
		return PAN == 4'h0 ? 16'h0000 : PAN <= 4'h8 ? WAVE : $signed(TEMP);
	endfunction
	
	function bit signed [15:0] PanRCalc(bit signed [15:0] WAVE, bit [3:0] PAN);
		bit [3:0] S;
		bit [15:0] TEMP;
		
		S = 4'd0 - PAN;
		TEMP = $signed($signed(WAVE)>>>{PAN[2:0]-3'h1,1'b0});
		return PAN == 4'h0 ? 16'h0000 : PAN >= 4'h8 ? WAVE : $signed(TEMP);
	endfunction
	
	function bit signed [15:0] TrimWave(bit signed [17:0] WAVE);
		return WAVE[17] && WAVE[16:15] != 2'b11 ? 16'h8000 : !WAVE[17] && WAVE[16:15] != 2'b00 ? 16'h7FFF : WAVE[15:0];
	endfunction
	
endpackage
