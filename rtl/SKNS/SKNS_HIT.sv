module SKNS_HIT
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_F,
	input              CE_R,
	
	input      [ 7: 0] A,
	input      [15: 0] DI,
	output     [15: 0] DO,
	input              RD_N,
	input      [ 3: 0] WE_N,
	input              CS_N,
	output             WAIT_N
);
	
	function bit [15:0] CalcLOrig(input bit [15:0] p, input bit [15:0] s, input bit [1:0] org);
		bit [15:0] ret;
		
		case (org)
			2'h0: ret = p;
			2'h1: ret = p + (s>>1);
			2'h2: ret = p;
			2'h3: ret = p + s;
		endcase
		return ret; 
	endfunction
	
	function bit [15:0] CalcROrig(input bit [15:0] p, input bit [15:0] s, input bit [1:0] org);
		bit [15:0] ret;
		
		case (org)
			2'h0: ret = p + s;
			2'h1: ret = p - (s>>1);
			2'h2: ret = p - s;
			2'h3: ret = p - s;
		endcase
		return ret; 
	endfunction
	
	bit  [15: 0] X1P,X2P;
	bit  [15: 0] Y1S,Y2S;
	bit  [15: 0] Z1P,Z2P;
	bit  [15: 0] X1S,X2S;
	bit  [15: 0] Y1P,Y2P;
	bit  [15: 0] Z1S,Z2S;
	bit  [15: 0] ORG;
	
	bit  [15: 0] X1_P1,Y1_P1,Z1_P1;
	bit  [15: 0] X1_P2,Y1_P2,Z1_P2;
	bit  [15: 0] X2_P1,Y2_P1,Z2_P1;
	bit  [15: 0] X2_P2,Y2_P2,Z2_P2;
	bit  [15: 0] X1toX2,Y1toY2,Z1toZ2;
	bit  [15: 0] X_IN,Y_IN,Z_IN;
	bit  [15: 0] FLAG;
	
	
	bit  [15: 0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		bit          RD_N_OLD,WE_N_OLD;
		bit  [15: 0] X1L,X1R,X2L,X2R;
		bit  [15: 0] Y1L,Y1R,Y2L,Y2R;
		bit  [15: 0] Z1L,Z1R,Z2L,Z2R;
		bit  [16: 0] RND;
		
		if (!RST_N) begin
			{X1P,X2P,X1S,X2S,Y1P,Y2P,Y1S,Y2S,Z1P,Z2P,Z1S,Z2S,ORG} <= '0;
			RND <= 17'h00001;
		end else if (EN) begin
			/*X1L = CalcLOrig(X1P, X1S, ORG[1:0]);*/ X1R = CalcROrig(X1P, X1S, ORG[1:0]);
			/*Y1L = CalcLOrig(Y1P, Y1S, ORG[1:0]);*/ Y1R = CalcROrig(Y1P, Y1S, ORG[1:0]);
			/*Z1L = CalcLOrig(Z1P, Z1S, ORG[1:0]);*/ Z1R = CalcROrig(Z1P, Z1S, ORG[1:0]);
			X2L = CalcLOrig(X2P, X2S, ORG[9:8]); /*X2R = CalcROrig(X2P, X2S, ORG[9:8]);*/
			Y2L = CalcLOrig(Y2P, Y2S, ORG[9:8]); /*Y2R = CalcROrig(Y2P, Y2S, ORG[9:8]);*/
			Z2L = CalcLOrig(Z2P, Z2S, ORG[9:8]); /*Z2R = CalcROrig(Z2P, Z2S, ORG[9:8]);*/
			
			X1_P1 = X1P; X2_P1 = X2P; 
			Y1_P1 = Y1P; Y2_P1 = Y2P;
			Z1_P1 = Z1P; Z2_P1 = Z2P;
			
			X1_P2 = X1R; X2_P2 = X2L;
			Y1_P2 = Y1R; Y2_P2 = Y2L;
			Z1_P2 = Z1R; Z2_P2 = Z2L;
			
			X1toX2 = X2P - X1P;
			Y1toY2 = Y2P - Y1P;
			Z1toZ2 = Z2P - Z1P;
			
			X_IN = X1R - X2L;
			Y_IN = Y1R - Y2L;
			Z_IN = Z1R - Z2L;
			
			FLAG = {Y2P > Y1P, Y2P == Y1P, Y2P < Y1P, Y_IN[15],
			         X2P > X1P, X2P == X1P, X2P < X1P, X_IN[15],
						Z2P > Z1P, Z2P == Z1P, Z2P < Z1P, Z_IN[15],
						~Y_IN[15]&~X_IN[15]&~Z_IN[15],
						~X_IN[15]&~Z_IN[15],
						~Y_IN[15]&~Z_IN[15],
						~X_IN[15]&~Y_IN[15]};
			
			if (CE_R) begin
				WE_N_OLD <= &WE_N[1:0];
				RD_N_OLD <= RD_N;
				if (!CS_N && WE_N[1:0] != 2'b11 && WE_N_OLD) begin
					case ({A[7:2],2'b00})
						8'h00,
						8'h28: X1P <= DI;
						8'h08,
						8'h30: Y1P <= DI;
						8'h38,
						8'h50: Z1P <= DI;
						8'h04,
						8'h2C: X1S <= DI;
						8'h0C,
						8'h34: Y1S <= DI;
						8'h3C,
						8'h54: Z1S <= DI;
						8'h10,
						8'h58: X2P <= DI;
						8'h18,
						8'h60: Y2P <= DI;
						8'h20,
						8'h68: Z2P <= DI;
						8'h14,
						8'h5C: X2S <= DI;
						8'h1C,
						8'h64: Y2S <= DI;
						8'h24,
						8'h6C: Z2S <= DI;
						8'h70: ORG <= DI;
						default:;
					endcase
				end
				if (!CS_N && !RD_N && RD_N_OLD) begin
					case ({A[7:2],2'b00})
						8'h00,
						8'h10: REG_DO <= X_IN;
						8'h04,
						8'h14: REG_DO <= Y_IN;
						8'h18: REG_DO <= Z_IN;
						8'h08,
						8'h1C: REG_DO <= FLAG;
						8'h28: REG_DO <= RND[15:0];
						8'h40: REG_DO <= X1P;
						8'h48: REG_DO <= Y1P;
						8'h50: REG_DO <= Z1P;
						8'h44: REG_DO <= X1S;
						8'h4C: REG_DO <= Y1S;
						8'h54: REG_DO <= Z1S;
						8'h58: REG_DO <= X2P;
						8'h60: REG_DO <= Y2P;
						8'h68: REG_DO <= Z2P;
						8'h5C: REG_DO <= X2S;
						8'h64: REG_DO <= Y2S;
						8'h6C: REG_DO <= Z2S;
						8'h70: REG_DO <= ORG;
						
						8'h80: REG_DO <= X1toX2;
						8'h84: REG_DO <= Y1toY2;
						8'h88: REG_DO <= Z1toZ2;
						8'h90: REG_DO <= X1_P1;
						8'h94: REG_DO <= X2_P1;
						8'h98: REG_DO <= X1_P2;
						8'h9C: REG_DO <= X2_P2;
						8'hA0: REG_DO <= Y1_P1;
						8'hA4: REG_DO <= Y2_P1;
						8'hA8: REG_DO <= Y1_P2;
						8'hAC: REG_DO <= Y2_P2;
						8'hB0: REG_DO <= Z1_P1;
						8'hB4: REG_DO <= Z2_P1;
						8'hB8: REG_DO <= Z1_P2;
						8'hBC: REG_DO <= Z2_P2;
						default: REG_DO <= '0;
					endcase
					RND <= {RND[5]^RND[0],RND[16:1]};
				end
			end
		end
	end
	assign DO = REG_DO;
	assign WAIT_N = 1;

endmodule
