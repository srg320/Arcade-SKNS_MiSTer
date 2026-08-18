package SKNS_PKG; 

	

	//Background
	typedef struct packed
	{
		bit [10: 0] INT;
		bit [ 7: 0] FRAC;
	} BGCoord_t;
	
	typedef struct packed
	{
		bit         FLIPX;
		bit         FLIPY;
		bit [ 5: 0] PAL;
		bit [ 2: 0] PRI;
		bit [20: 0] NUM;
	} BGTile_t;
	
	function bit [7:0] BGPix(input bit [15:0] CHR, input bit [1:0] X, input bit FLIP, input bit BPP);
		bit [7:0] ret;
		
		if (BPP)
			case (X[1:0]^{2{FLIP}})
				2'h0: ret = {4'h0,CHR[11: 8]};
				2'h1: ret = {4'h0,CHR[15:12]};
				2'h2: ret = {4'h0,CHR[ 3: 0]};
				2'h3: ret = {4'h0,CHR[ 7: 4]};
			endcase
		else
			case (X[0:0]^{1{FLIP}})
				1'h0: ret = CHR[15: 8];
				1'h1: ret = CHR[ 7: 0];
			endcase
		
		return ret; 
	endfunction
	
	function bit [23:0] RGB888(input bit [15:0] RGB555);
		return {RGB555[14:10],3'b000,RGB555[9:5],3'b000,RGB555[4:0],3'b000}; 
	endfunction
	
	function bit [4:0] ColorBright(input bit [4:0] C, input bit [7:0] BR);
		bit [12:0] M;
		
		M = (C * BR) + {8'h00,C};
		return !BR ? 5'h00 : M[12:8]; 
	endfunction
	
	function [23:0] RGBBright(input bit [15:0] RGB555, input bit [23:0] BR, input bit APPLY);
		bit [4:0] R,G,B;
		
		R = APPLY ? ColorBright(RGB555[14:10], BR[23:16]) : RGB555[14:10];
		G = APPLY ? ColorBright(RGB555[ 9: 5], BR[15: 8]) : RGB555[ 9: 5];
		B = APPLY ? ColorBright(RGB555[ 4: 0], BR[ 7: 0]) : RGB555[ 4: 0];
		
		return {R[4:0],R[4:2],G[4:0],G[4:2],B[4:0],B[4:2]};
	endfunction
	
	function bit [7:0] ColorBlend(input bit [7:0] CT, input bit [7:0] CB, input bit [7:0] BT);
		bit [15:0] M;
		bit [8:0] S;
		
		M = (CT * BT);
		S = {1'b0,M[15:8]} + {1'b0,CB};
		
		return S[8] ? 8'hFF : S[7:0]; 
	endfunction
	
	function [23:0] RGBBlend(input bit [23:0] TOP, input bit [23:0] BOT, input bit [23:0] BT, input bit APPLY);
		bit [7:0] R,G,B;
		
		R = APPLY ? ColorBlend(TOP[23:16], BOT[23:16], BT[23:16]) : TOP[23:16];
		G = APPLY ? ColorBlend(TOP[15: 8], BOT[15: 8], BT[15: 8]) : TOP[15: 8];
		B = APPLY ? ColorBlend(TOP[ 7: 0], BOT[ 7: 0], BT[ 7: 0]) : TOP[ 7: 0];
		
		return {R,G,B};
	endfunction

	//Sprite
	typedef struct packed
	{
		bit [ 9: 0] INT;
		bit [ 5: 0] FRAC;
	} SprCoord_t;
	
	typedef struct packed
	{
		//0
		bit [ 1: 0] UNUSED4;
		bit [ 1: 0] SIZEY;
		bit [ 1: 0] UNUSED3;
		bit [ 1: 0] SIZEX;
		bit         SHRINK;
		bit [ 6: 0] UNUSED2;
		bit [ 2: 0] JOINT;
		bit [ 1: 0] GROUP;
		bit         UNUSED1;
		bit         FLIPX;
		bit         FLIPY;
		bit [ 1: 0] PRI;
		bit [ 5: 0] PAL;
		//4
		bit [ 4: 0] UNUSED0;
		bit [26: 0] ADDR;
		//8
		bit [ 7: 0] ZOOMXS;
		bit [ 7: 0] ZOOMXD;
		bit [15: 0] X;
		//C
		bit [ 7: 0] ZOOMYS;
		bit [ 7: 0] ZOOMYD;
		bit [15: 0] Y;
	} Sprite_t;
	
endpackage
