module SKNS_CART
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              CE_F,
	input              CE_R,
	
	input              RES_N,
	
	input      [24: 1] A,
	input      [15: 0] DI,
	output     [15: 0] DO,
	input              RD_N,
	input      [ 1: 0] WE_N,
	input              CS_N,
	output             WAIT_N,
	
	input              DOT_CE,
	input              RENDER,
	
	output     [17: 1] BG1_RAM_A,
	input      [15: 0] BG1_RAM_DI,
	output     [15: 0] BG1_RAM_DO,
	output     [ 1: 0] BG1_RAM_WE_N,
	output             BG1_RAM_RD_N
);

	import SKNS_PKG::*;
	
	wire         IO_CG_SEL = (A[24:23] == 2'b01 && !CS_N);
	
	//BGB char RAM
//	bit          RENDER_BG1_CYCLE = 0;
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
			if (DOT_CE) begin
				if (IO_BG1_RAM_WAIT) begin
					IO_BG1_RAM_ADDR <= A[17:1];
					IO_BG1_RAM_DATA <= DI;
					IO_BG1_RAM_WE <= ~WE_N;
					IO_BG1_RAM_RD <= ~RD_N;
					IO_BG1_RAM_CYCLE <= 1;
				end
				if (IO_BG1_RAM_CYCLE && !RENDER) begin
					IO_BG1_RAM_WE <= '0;
					IO_BG1_RAM_RD <= 0;
					IO_BG1_RAM_CYCLE <= 0;
					IO_BG1_RAM_WAIT <= 0;
					IO_BG1_RAM_RWAIT[0] <= IO_BG1_RAM_RD;
				end
			end
			if (CE_R) begin
				if (IO_BG1_RAM_RWAIT[1]) begin
					IO_BG1_RAM_DO <= BG1_RAM_DI;
				end
			end
		end
	end
	assign BG1_RAM_A = IO_BG1_RAM_ADDR;
	assign BG1_RAM_DO = IO_BG1_RAM_DATA;
	assign BG1_RAM_WE_N = ~IO_BG1_RAM_WE;
	assign BG1_RAM_RD_N = ~IO_BG1_RAM_RD;
	
	assign DO = IO_CG_SEL ? IO_BG1_RAM_DO : '0;
	assign WAIT_N = ~(IO_CG_SEL & |{IO_BG1_RAM_WAIT,IO_BG1_RAM_RWAIT});
	
endmodule
