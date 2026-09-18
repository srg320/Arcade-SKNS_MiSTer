module SKNS_VEGA
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_F,
	input              CE_R,
	
	input              RES_N,
	
	input      [ 3: 0] A,
	input      [ 7: 0] DI,
	output     [ 7: 0] DO,
	input              OE_N,
	input              WE_N,
	input              CE_N,
	
	input              HBLANK_N,
	input              VB_INT,
	input              SPC_INT,
	input              VINC_PULSE,
	output     [ 3: 0] IRL_N,
	
	input      [ 7: 0] P0I,
	input      [ 7: 0] P1I,
	input      [ 7: 0] P2I,
	input      [ 7: 0] P3I,
	input      [ 7: 0] P4I,
	input      [ 7: 0] P5I,
	input      [ 7: 0] P7I,
	
	output reg [ 7: 0] P6O,
	output reg [ 7: 0] P8O
);

	//Ports
	always @(posedge CLK or negedge RST_N) begin
		bit          WE_N_OLD;
		
		if (!RST_N) begin
			DO <= '0;
		end 
		else if (!RES_N) begin
			P6O <= '0;
			P8O <= '0;
		end 
		else if (EN) begin
			if (CE_R) begin
				WE_N_OLD <= WE_N;
				if (!WE_N && WE_N_OLD) begin
					case (A[3:0])
						4'h6: P6O <= DI;
						4'h8: P8O <= DI;
						default: ;
					endcase
				end
				
				case (A[3:0])
					4'h0: DO <= P0I;
					4'h1: DO <= P1I;
					4'h2: DO <= P2I;
					4'h3: DO <= P3I;
					4'h4: DO <= P4I;
					4'h5: DO <= P5I;
//					4'h6: DO <= P6I;
					4'h7: DO <= P7I;
					default: DO <= '1;
				endcase
			end
		end
	end
	
	//Interrupts
	wire         IRQ_ACK = (!CE_N && A[3:0] == 4'hE && !WE_N);
	bit          VBI_IRQ,SPC_IRQ,HBI_IRQ,TM0_IRQ,TM1_IRQ;
	always @(posedge CLK or negedge RST_N) begin
		bit          HBLANK_N_OLD,VB_INT_OLD;
		bit          SPC_INT_OLD;
		bit          IRQ_ACK_OLD;
		bit  [ 6: 0] LINE_CNT;
		
		if (!RST_N) begin
			{HBI_IRQ,VBI_IRQ,SPC_IRQ,TM0_IRQ,TM1_IRQ} <= '0;
		end 
		else if (!RES_N) begin
			{HBI_IRQ,VBI_IRQ,SPC_IRQ,TM0_IRQ,TM1_IRQ} <= '0;
			LINE_CNT <= '0;
		end 
		else if (EN) begin
			if (CE_R) begin
				HBLANK_N_OLD <= HBLANK_N;
				VB_INT_OLD <= VB_INT;
				if (VINC_PULSE) begin
					HBI_IRQ <= 1;
				end
				if (VB_INT && !VB_INT_OLD) begin
					VBI_IRQ <= 1;
				end
				
				SPC_INT_OLD <= SPC_INT;
				if (SPC_INT && !SPC_INT_OLD) begin
					SPC_IRQ <= 1;
				end
				
				if (VINC_PULSE) begin
					LINE_CNT <= LINE_CNT + 7'd1;
				end
				if (!HBLANK_N && HBLANK_N_OLD) begin
					TM0_IRQ <= &LINE_CNT[4:0];
					TM1_IRQ <= &LINE_CNT[6:0];
				end
				
				IRQ_ACK_OLD <= IRQ_ACK;
				if (IRQ_ACK && !IRQ_ACK_OLD) begin
					if (!DI[0] && SPC_IRQ) SPC_IRQ <= 0;
					if (!DI[2] && VBI_IRQ) VBI_IRQ <= 0;
					if (!DI[4] && HBI_IRQ) HBI_IRQ <= 0;
					if (!DI[5] && TM1_IRQ) TM1_IRQ <= 0;
					if (!DI[7] && TM0_IRQ) TM0_IRQ <= 0;
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
	assign IRL_N = ~INT_LVL;

endmodule
