module SKNS_SPC2
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
	input              CS_N,
	output             WAIT_N,
	
	output             INT,
	
	output     [23: 0] ROM_A,
	input      [15: 0] ROM_D,
	output             ROM_RD_N,
	input              ROM_WAIT,
	
	output     [18: 1] FB0_A,
	output     [15: 0] FB0_D,
	input      [15: 0] FB0_Q,
	output             FB0_WE,
	output     [18: 1] FB1_A,
	output     [15: 0] FB1_D,
	input      [15: 0] FB1_Q,
	output             FB1_WE,
	
	input              DOT_CE,
	input              HBL_N,
	input              VBL_N,
	output     [15: 0] OUT,
	
	input      [ 9: 0] SPR_OFFSX,
	input      [ 9: 0] SPR_OFFSY
	
`ifdef DEBUG
                      ,
	input      [ 7: 0] DBG_EXT,
	output reg [ 9: 0] DBG_SPR_SKIP,DBG_SPR_NUM,
	output reg         DBG_SPR_SKIP_EN,
	output             DBG_SPR_HIT,
	output reg [ 9: 0] DBG_SPR_OFFSX,DBG_SPR_OFFSY,
	output             DBG_DRAW_NEXT
`endif
);

	import SKNS_PKG::*;
	
	bit  [31: 0] SREG[16];
	
	bit          DECODE_RUN;
	
	
	wire         IO_SPRRAM_SEL = (A[24:0] >= (25'h000000) && A[24:0] <= (25'h003FFF) && !CS_N);
	wire         IO_SREG_SEL   = (A[24:0] >= (25'h100000) && A[24:0] <= (25'h10003F) && !CS_N);
	
	bit          WE_N_OLD;
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			SREG <= '{16{'0}};
		end else if (EN) begin
			if (CE_R) begin
				WE_N_OLD <= &WE_N;
				if (IO_SREG_SEL && !(&WE_N) && WE_N_OLD) begin
					if (!WE_N[3]) SREG[A[5:2]][31:24] <= DI[31:24];
					if (!WE_N[2]) SREG[A[5:2]][23:16] <= DI[23:16];
					if (!WE_N[1]) SREG[A[5:2]][15: 8] <= DI[15: 8];
					if (!WE_N[0]) SREG[A[5:2]][ 7: 0] <= DI[ 7: 0];
				end
			end
		end
	end
	assign DO = IO_SPRRAM_SEL ? IO_SPRRAM_DO :
	            IO_SREG_SEL ? SREG[A[5:2]] : 
					'0;
	assign WAIT_N = ~(IO_SPRRAM_SEL & IO_SPRRAM_WAIT) /*& ~(IO_GFX_SEL & IO_ROM_WAIT)*/;
	
	//Sprite ROM
	bit  [ 1: 0] ROM_STATE;
	bit  [26: 0] ROM_ADDR;
	bit          ROM_READ;
	
	bit          SPR_FIFO_INIT,SPR_FIFO_RDREQ;
	bit  [ 7: 0] SPR_FIFO_Q;
	bit          SPR_FIFO_EMPTY,SPR_FIFO_FULL;
	SKNS_SPRITE_FIFO SPR_FIFO
	(
		.CLK(CLK),
		.EN(EN),
		.RST(SPR_FIFO_INIT),
		
		.DATA(!ROM_ADDR[0] ? ROM_D[15:8] : ROM_D[7:0]),
		.WRREQ(ROM_STATE == 2'd2 && !ROM_WAIT),
		.RDREQ(SPR_FIFO_RDREQ),
		.Q(SPR_FIFO_Q),
		
		.EMPTY(SPR_FIFO_EMPTY),
		.FULL(SPR_FIFO_FULL)
	);
	
	always @(posedge CLK) begin
		if (SPR_FIFO_INIT) begin
			ROM_ADDR <= SPR_ADDR;
			ROM_READ <= 0;
			ROM_STATE <= 2'd0;
		end
		else begin
			ROM_READ <= 0;
//			if (CE_R) begin
				case (ROM_STATE) 
					2'd0: begin
						if (!ROM_WAIT) begin
							ROM_STATE <= 2'd1;
						end
					end
					
					2'd1: begin
						if (!SPR_FIFO_FULL) begin
							ROM_READ <= 1;
							ROM_STATE <= 2'd2;
						end
					end
					
					2'd2: begin
						if (!ROM_WAIT) begin
							ROM_ADDR <= ROM_ADDR + 1'd1;
							ROM_STATE <= 2'd1;
						end
					end
				endcase
//			end
		end
	end
	assign ROM_A = ROM_ADDR[23:0];
	assign ROM_RD_N = ~ROM_READ;
	
//	bit          SYNC;
//	always @(posedge CLK) begin
//		if (SPR_FIFO_INIT) begin
//			ROM_ADDR <= SPR_ADDR;
//			ROM_READ <= 0;
//			SYNC <= 1;
//		end
//		else if (DOT_CE) begin
//			ROM_READ <= 0;
//			SYNC <= 0;
//			if (SYNC) begin
//				ROM_READ <= 1;
//			end else if (!SPR_FIFO_FULL) begin
//				if (ROM_READ) ROM_ADDR <= ROM_ADDR + 1'd1;
//				ROM_READ <= 1;
//			end
//		end
//	end
	
	//Sprite RAM
	bit          SPR_RAM_FETCH;
	
	bit  [31: 0] IO_SPR_RAM_Q;
	bit  [31: 0] IO_SPRRAM_DO;
	bit          IO_SPRRAM_WAIT;
	bit          IO_SPRRAM_CYCLE;
	always @(posedge CLK or negedge RST_N) begin
		bit          IO_SPRRAM_SEL_OLD;
		
		if (!RST_N) begin
			IO_SPRRAM_WAIT <= 0;
			IO_SPRRAM_CYCLE <= 0;
		end else if (EN) begin
			IO_SPRRAM_SEL_OLD <= IO_SPRRAM_SEL;
			if (IO_SPRRAM_SEL && !IO_SPRRAM_SEL_OLD) begin
				IO_SPRRAM_WAIT <= 1;
			end
			if (CE_R) begin
				if (!SPR_RAM_FETCH) IO_SPRRAM_CYCLE <= IO_SPRRAM_WAIT;
				if (IO_SPRRAM_CYCLE) begin
					IO_SPRRAM_DO <= IO_SPR_RAM_Q;
					IO_SPRRAM_CYCLE <= 0;
					IO_SPRRAM_WAIT <= 0;
				end
			end
		end
	end
	
	bit  [11: 0] SPR_RAM_ADDR;
	bit  [31: 0] SPR_RAM_Q;
	SKNS_SPR_RAM SPR_RAM
	(
		.CLK(CLK), 
		.ADDR_A(A[13:2]), 
		.DATA_A(DI), 
		.WREN_A(~WE_N & {4{IO_SPRRAM_CYCLE & CE_R}}), 
		.Q_A(IO_SPR_RAM_Q), 
		
		.ADDR_B(SPR_RAM_ADDR), 
		.Q_B(SPR_RAM_Q)
	);
	
	typedef enum bit [2:0] {
		ST_IDLE,
		ST_SPR_NEXT,
		ST_DRAW_INIT,
		ST_DEC_ADDR,
		ST_DEC_INIT,
		ST_EXEC,
		ST_CONT,
		ST_NEXT
	} State_t;
	State_t      STATE;
	
	typedef enum bit [2:0] {
		DEC_IDLE,
		DEC_READ_CNT,
		DEC_READ_DATA,
		DEC_REPEAT
	} DecodeState_t;
	DecodeState_t DEC_ST;
	
	typedef enum bit [2:0] {
		DRAW_IDLE,
		DRAW_ROW,
		DRAW_NEXT
	} DrawState_t;
	DrawState_t  DRAW_ST;
	
	Sprite_t     SPR_ATTR;
	wire [15: 0] SPR_OFFS_X = {/*SREG[2][14],*/SREG[2][15:0]};
	wire [15: 0] SPR_OFFS_Y = {/*SREG[4][14],*/SREG[4][15:0]};
	wire [15: 0] SPR_ORIG_X[4] = '{SREG[6][15:0],SREG[8][15:0],SREG[10][15:0],SREG[12][15:0]};
	wire [15: 0] SPR_ORIG_Y[4] = '{SREG[7][15:0],SREG[9][15:0],SREG[11][15:0],SREG[13][15:0]};
	wire         SPR_ORIG_XY_EN = SREG[0][6];
	wire         SPR_DRAW_FLIPX = SREG[1][1];
	wire         SPR_DRAW_FLIPY = SREG[1][0];
//	wire [ 9: 0] SPR_LIST_NUM = SREG[3][9:0];
	
	SprCoord_t   SPR_SX,SPR_SY;
	SprCoord_t   SPR_X,SPR_Y;
	bit          SPR_FLIPX,SPR_FLIPY;
	bit  [ 1: 0] SPR_SIZEX,SPR_SIZEY;
	bit  [16: 0] SPR_ZOOMXD,SPR_ZOOMYD;
	bit  [16: 0] SPR_ZOOMXS,SPR_ZOOMYS;
	bit  [ 5: 0] SPR_PAL;
	bit  [ 1: 0] SPR_PRI;
	bit  [26: 0] SPR_ADDR;
	
	bit  [11: 0] SPR_BUF_WA,SPR_BUF_RA;
	bit  [ 7: 0] SPR_BUF_DATA,SPR_BUF_Q;
	bit          SPR_BUF_WE;
	SKNS_SPRITE_BUF SPR_BUF(CLK, SPR_BUF_WA[6:0], SPR_BUF_DATA, SPR_BUF_WE & CE_R, {DRAW_SRC_ROW[0],DRAW_SRC_DOT}, SPR_BUF_Q);
	
	bit          FRAME_DONE;
	bit          DECODE_DONE;
	bit  [ 5: 0] DECODE_ROW,DECODE_DOT;
	bit  [ 5: 0] DRAW_SRC_ROW,DRAW_SRC_DOT,DRAW_DST_DOT,DRAW_DST_ROW;
	bit  [ 7: 0] DRAW_SRC_ROW_FRAC,DRAW_SRC_DOT_FRAC,DRAW_DST_DOT_FRAC,DRAW_DST_ROW_FRAC;
	bit  [ 8: 0] DRAW_FB_Y,DRAW_FB_X;
	bit  [ 7: 0] DRAW_PIX;
	bit          DRAW_FB_WRITE;
	bit          DRAW_RUN;
	bit          DRAW_DONE;
	bit  [ 8: 0] DISP_FB_Y,DISP_FB_X;
	bit          FB_SEL;
	always @(posedge CLK or negedge RST_N) begin
		bit         VBL_N_OLD;
		bit [ 6: 0] DECODE_CNT;
		bit         DECODE_MODE;
		bit [ 9: 0] DRAW_OFFS_X,DRAW_OFFS_Y;
		bit [14: 0] DRAW_SRC_ROW_NEXT,DRAW_SRC_DOT_NEXT,DRAW_DST_DOT_NEXT,DRAW_DST_ROW_NEXT;
		bit         DRAW_STEP_X_MODE,DRAW_STEP_Y_MODE;
		SprCoord_t  DRAW_Y,DRAW_X;
		
		bit [ 7: 0] DBG_EXT_OLD;
		
		if (!RST_N) begin
			STATE <= ST_IDLE;
			FRAME_DONE <= 0;
			DEC_ST <= DEC_IDLE;
			DECODE_RUN <= 0;
			DECODE_DONE <= 0;
			DRAW_ST <= DRAW_IDLE;
			DRAW_RUN <= 0;
			
`ifdef DEBUG
			DBG_SPR_SKIP <= '1;
			{DBG_SPR_OFFSX,DBG_SPR_OFFSY} <= '0;
`endif
		end else if (EN) begin
			SPR_FIFO_RDREQ <= 0;
			
			if (CE_R) begin
				VBL_N_OLD <= VBL_N;
				case (STATE) 
					ST_IDLE: begin
					end
					
					ST_SPR_NEXT: begin
						FRAME_DONE <= 0;
						case (SPR_RAM_ADDR[1:0])
							2'h0: SPR_ATTR[127: 96] <= SPR_RAM_Q;
							2'h1: SPR_ATTR[ 95: 64] <= SPR_RAM_Q;
							2'h2: SPR_ATTR[ 63: 32] <= SPR_RAM_Q;
							2'h3: SPR_ATTR[ 31:  0] <= SPR_RAM_Q;
						endcase
						SPR_RAM_ADDR <= SPR_RAM_ADDR + 12'd1;
						if (SPR_RAM_ADDR[1:0] == 2'h3) begin
							STATE <= ST_DRAW_INIT;
						end
					end
					
					ST_DRAW_INIT : if (!DRAW_RUN) begin
						if (!SPR_ATTR.JOINT[0]) begin
							SPR_X <= SPR_ATTR.X;
							SPR_Y <= SPR_ATTR.Y;
						end else begin
							SPR_X <= SPR_X + SPR_ATTR.X;
							SPR_Y <= SPR_Y + SPR_ATTR.Y;
						end
`ifdef DEBUG
						SPR_SX <= (SPR_ORIG_XY_EN ? SPR_ORIG_X[SPR_ATTR.GROUP] + SPR_OFFS_X : 16'h0) + {SPR_OFFSX,6'h00} + {DBG_SPR_OFFSX,6'h00};
						SPR_SY <= (SPR_ORIG_XY_EN ? SPR_ORIG_Y[SPR_ATTR.GROUP] + SPR_OFFS_Y : 16'h0) + {SPR_OFFSY,6'h00} + {DBG_SPR_OFFSY,6'h00};
`else
						SPR_SX <= (SPR_ORIG_XY_EN ? SPR_ORIG_X[SPR_ATTR.GROUP] + SPR_OFFS_X : 16'h0) + {SPR_OFFSX,6'h00};
						SPR_SY <= (SPR_ORIG_XY_EN ? SPR_ORIG_Y[SPR_ATTR.GROUP] + SPR_OFFS_Y : 16'h0) + {SPR_OFFSY,6'h00};
`endif
						SPR_FLIPX <= SPR_ATTR.FLIPX;
						SPR_FLIPY <= SPR_ATTR.FLIPY;
						SPR_SIZEX <= SPR_ATTR.SIZEX;
						SPR_SIZEY <= SPR_ATTR.SIZEY;
						if (!SPR_ATTR.JOINT[1]) begin
							SPR_PAL <= SPR_ATTR.PAL;
						end
						if (!SPR_ATTR.JOINT[2]) begin
							SPR_PRI <= SPR_ATTR.PRI;
							SPR_ADDR <= SPR_ATTR.ADDR;
						end
						if (!SPR_ATTR.SHRINK) begin
							SPR_ZOOMXD <= {1'b0,~{SPR_ATTR.ZOOMXD,8'h00}} + 17'd1;
							SPR_ZOOMYD <= {1'b0,~{SPR_ATTR.ZOOMYD,8'h00}} + 17'd1;
							SPR_ZOOMXS <= {1'b0,~{SPR_ATTR.ZOOMXS,8'h00}} + 17'd1;
							SPR_ZOOMYS <= {1'b0,~{SPR_ATTR.ZOOMYS,8'h00}} + 17'd1;
						end else begin
							SPR_ZOOMXD <= {1'b0,~{SPR_ATTR.ZOOMXS,SPR_ATTR.ZOOMXD}} + 17'd1;
							SPR_ZOOMYD <= {1'b0,~{SPR_ATTR.ZOOMYS,SPR_ATTR.ZOOMYD}} + 17'd1;
							SPR_ZOOMXS <= 17'h10000;
							SPR_ZOOMYS <= 17'h10000;
						end
						
						STATE <= ST_DEC_INIT;
					end
					
					ST_DEC_INIT: begin
						STATE <= ST_EXEC;
					end
					
					ST_EXEC: begin
						if (!DECODE_RUN && !DRAW_RUN) begin
							STATE <= ST_CONT;
						end
					end
					
					ST_CONT: begin
						if (!DECODE_DONE && DECODE_ROW[0] != DRAW_SRC_ROW[0]) DECODE_RUN <= 1;
						if (DRAW_DONE) begin
							DRAW_DONE <= 0;
							STATE <= ST_NEXT;
						end else begin
							DRAW_RUN <= 1;
							STATE <= ST_EXEC;
						end
					end
					
					ST_NEXT: begin
						STATE <= ST_SPR_NEXT;
						
`ifdef DEBUG
//						if (DBG_SPR_HIT) begin
//							DRAW_RUN <= 0;
//							STATE <= ST_SPR_NEXT;
//						end
						DBG_SPR_NUM <= DBG_SPR_NUM + 10'd1;
`endif
						
						if (SPR_RAM_ADDR[11:2] == 10'h0) begin
							FRAME_DONE <= 1;
							STATE <= ST_IDLE;
						end
					end
				endcase
				
				SPR_BUF_WE <= 0;
				case (DEC_ST) 
					DEC_IDLE: begin
//						DEC_ST <= DEC_READ_CNT;
					end
					
					DEC_READ_CNT: if (DECODE_RUN) begin
						if (!SPR_FIFO_EMPTY) begin
							SPR_FIFO_RDREQ <= 1;
							{DECODE_MODE,DECODE_CNT} <= SPR_FIFO_Q;
							DEC_ST <= DEC_READ_DATA;
						end
					end
					
					DEC_READ_DATA: if (DECODE_RUN) begin
						if (!SPR_FIFO_EMPTY) begin
							SPR_FIFO_RDREQ <= 1;
							SPR_BUF_DATA <= SPR_FIFO_Q;
							SPR_BUF_WA <= {DECODE_ROW,DECODE_DOT};
							SPR_BUF_WE <= 1;
							DECODE_DOT <= DECODE_DOT + 6'd1;
							DECODE_CNT <= DECODE_CNT - 7'd1;
							if (DECODE_DOT == {SPR_ATTR.SIZEX,4'hF}) begin
								DECODE_DOT <= '0;
								DECODE_RUN <= 0;
								DECODE_ROW <= DECODE_ROW + 6'd1;
								if (DECODE_ROW == {SPR_ATTR.SIZEY,4'hF}) begin
									DECODE_DONE <= 1;
								end
							end
							if (DECODE_CNT == 7'd0) begin
								DEC_ST <= DEC_READ_CNT;
							end else begin
								DEC_ST <= DECODE_MODE ? DEC_READ_DATA : DEC_REPEAT;
							end
						end
					end
					
					DEC_REPEAT: if (DECODE_RUN) begin
						SPR_BUF_WA <= {DECODE_ROW,DECODE_DOT};
						SPR_BUF_WE <= 1;
						DECODE_DOT <= DECODE_DOT + 6'd1;
						DECODE_CNT <= DECODE_CNT - 7'd1;
						if (DECODE_DOT == {SPR_ATTR.SIZEX,4'hF}) begin
							DECODE_DOT <= '0;
							DECODE_RUN <= 0;
							DECODE_ROW <= DECODE_ROW + 6'd1;
							if (DECODE_ROW == {SPR_ATTR.SIZEY,4'hF}) begin
								DECODE_DONE <= 1;
							end
						end 
						if (DECODE_CNT == 7'd0) begin
							DEC_ST <= DEC_READ_CNT;
						end else begin
							DEC_ST <= DEC_REPEAT;
						end
					end
				endcase
				if (STATE == ST_DEC_INIT) begin
					{DECODE_ROW,DECODE_DOT} <= '0;
					DECODE_RUN <= 1;
					DECODE_DONE <= 0;
					DEC_ST <= DEC_READ_CNT;
				end
				
				DRAW_X = SPR_FLIPX ? SPR_SX + SPR_X - {DRAW_OFFS_X,6'b000000} : SPR_SX + SPR_X + {DRAW_OFFS_X,6'b000000};
				DRAW_Y = SPR_FLIPY ? SPR_SY + SPR_Y - {DRAW_OFFS_Y,6'b000000} : SPR_SY + SPR_Y + {DRAW_OFFS_Y,6'b000000};
				DRAW_FB_WRITE <= 0;
				case (DRAW_ST) 
					DRAW_IDLE: if (DRAW_RUN) begin
						{DRAW_SRC_DOT,DRAW_SRC_DOT_FRAC} <= /*!SPR_ZOOMXS[16] ? {6'h00,SPR_ZOOMXS[16:9]} :*/ '0;
						{DRAW_SRC_ROW,DRAW_SRC_ROW_FRAC} <= /*!SPR_ZOOMYS[16] ? {6'h00,SPR_ZOOMYS[16:9]} :*/ '0;
						{DRAW_DST_DOT,DRAW_DST_DOT_FRAC} <= /*!SPR_ZOOMXD[16] ? {6'h00,SPR_ZOOMXD[16:9]} :*/ '0;
						{DRAW_DST_ROW,DRAW_DST_ROW_FRAC} <= /*!SPR_ZOOMYD[16] ? {6'h00,SPR_ZOOMYD[16:9]} :*/ '0;
						{DRAW_OFFS_X,DRAW_OFFS_Y} <= '0;
						DRAW_DONE <= 0;
						DRAW_ST <= DRAW_ROW;
					end
					
					DRAW_ROW: if (DRAW_RUN) begin
						DRAW_SRC_DOT_NEXT = {1'b0,DRAW_SRC_DOT,DRAW_SRC_DOT_FRAC} + {1'b0,5'h00,SPR_ZOOMXS[16:8]};
						DRAW_DST_DOT_NEXT = {1'b0,DRAW_DST_DOT,DRAW_DST_DOT_FRAC} + {1'b0,5'h00,SPR_ZOOMXD[16:8]};
						
						{DRAW_SRC_DOT,DRAW_SRC_DOT_FRAC} <= DRAW_SRC_DOT_NEXT[13:0];
						if (DRAW_SRC_DOT_NEXT[14:8] > {1'b0,SPR_SIZEX,4'hF}) begin
							DRAW_RUN <= 0;
							DRAW_ST <= DRAW_NEXT;
						end
						
						{DRAW_DST_DOT,DRAW_DST_DOT_FRAC} <= DRAW_DST_DOT_NEXT[13:0];
//						if (DRAW_DST_DOT_NEXT[14:8] > {1'b0,SPR_SIZEX,4'hF}) begin
//							
//						end
						if (DRAW_DST_DOT != DRAW_DST_DOT_NEXT[13:8]) begin
							DRAW_OFFS_X <= DRAW_OFFS_X + 10'd1;
						end
						
						DRAW_FB_X <= DRAW_X.INT[8:0];
						DRAW_FB_Y <= DRAW_Y.INT[8:0];
						DRAW_PIX <= SPR_BUF_Q;
						DRAW_FB_WRITE <= !DRAW_Y.INT[9] && !DRAW_X.INT[9] && |SPR_BUF_Q;
					end
					
					DRAW_NEXT: begin
						{DRAW_SRC_DOT,DRAW_SRC_DOT_FRAC} <= /*!SPR_ZOOMXS[16] ? {6'h00,SPR_ZOOMXS[16:9]} :*/ '0;
						{DRAW_DST_DOT,DRAW_DST_DOT_FRAC} <= /*!SPR_ZOOMXD[16] ? {6'h00,SPR_ZOOMXD[16:9]} :*/ '0;
						
						DRAW_SRC_ROW_NEXT = {1'b0,DRAW_SRC_ROW,DRAW_SRC_ROW_FRAC} + {1'b0,5'h00,SPR_ZOOMYS[16:8]};
						DRAW_DST_ROW_NEXT = {1'b0,DRAW_DST_ROW,DRAW_DST_ROW_FRAC} + {1'b0,5'h00,SPR_ZOOMYD[16:8]};
						
						if (DRAW_DST_ROW != DRAW_DST_ROW_NEXT[13:8]) begin
							DRAW_OFFS_Y <= DRAW_OFFS_Y + 10'd1;
						end
						DRAW_ST <= DRAW_ROW;
						
						{DRAW_SRC_ROW,DRAW_SRC_ROW_FRAC} <= DRAW_SRC_ROW_NEXT[13:0];
						if (DRAW_SRC_ROW_NEXT[14:8] > {1'b0,SPR_SIZEY,4'hF}) begin
							DRAW_DONE <= 1;
							DRAW_ST <= DRAW_IDLE;
						end
						
						{DRAW_DST_ROW,DRAW_DST_ROW_FRAC} <= DRAW_DST_ROW_NEXT[13:0];
//						if (DRAW_DST_ROW_NEXT[14:8] > {1'b0,SPR_SIZEY,4'hF}) begin
//							
//						end
							
						DRAW_OFFS_X <= '0;
					end
				endcase
				
				VBL_N_OLD <= VBL_N;
				if (VBL_N && !VBL_N_OLD) begin
					SPR_RAM_ADDR <= '0;
					if (STATE != ST_IDLE) FRAME_DONE <= 1;
					STATE <= !SREG[1][3] ? ST_SPR_NEXT : ST_IDLE;
					DECODE_RUN <= 0;
					DECODE_DONE <= 0;
					DEC_ST <= DEC_IDLE;
					DRAW_RUN <= 0;
					DRAW_DONE <= 0;
					DRAW_ST <= DRAW_IDLE;
					{DRAW_SRC_DOT,DRAW_SRC_DOT_FRAC} <= 14'h0000;
					{DRAW_SRC_ROW,DRAW_SRC_ROW_FRAC} <= 14'h0000;
					{DRAW_DST_DOT,DRAW_DST_DOT_FRAC} <= 14'h0000;
					{DRAW_DST_ROW,DRAW_DST_ROW_FRAC} <= 14'h0000;
`ifdef DEBUG
					DBG_SPR_NUM <= '0;
`endif
				end
				
`ifdef DEBUG
				DBG_EXT_OLD <= DBG_EXT;
				if (DBG_EXT[0] && !DBG_EXT_OLD[0]) DBG_SPR_SKIP <= DBG_SPR_SKIP - 10'd1;
				if (DBG_EXT[1] && !DBG_EXT_OLD[1]) DBG_SPR_SKIP <= DBG_SPR_SKIP + 10'd1;
				if (DBG_EXT[2] && !DBG_EXT_OLD[2]) DBG_SPR_SKIP <= DBG_SPR_SKIP - 10'd10;
				if (DBG_EXT[3] && !DBG_EXT_OLD[3]) DBG_SPR_SKIP <= DBG_SPR_SKIP + 10'd10;
//				if (DBG_EXT[4] && !DBG_EXT_OLD[4]) DBG_SPR_SKIP_EN <= ~DBG_SPR_SKIP_EN;
				if (DBG_EXT[4] && !DBG_EXT_OLD[4]) DBG_SPR_OFFSX <= DBG_SPR_OFFSX - 10'd1;
				if (DBG_EXT[5] && !DBG_EXT_OLD[5]) DBG_SPR_OFFSX <= DBG_SPR_OFFSX + 10'd1;
				if (DBG_EXT[6] && !DBG_EXT_OLD[6]) DBG_SPR_OFFSY <= DBG_SPR_OFFSY - 10'd1;
				if (DBG_EXT[7] && !DBG_EXT_OLD[7]) DBG_SPR_OFFSY <= DBG_SPR_OFFSY + 10'd1;
`endif
			end
		end
	end
	assign SPR_FIFO_INIT = (STATE == ST_DEC_INIT && !SPR_ATTR.JOINT[2]);
	assign SPR_RAM_FETCH = (STATE == ST_SPR_NEXT);
	
`ifdef DEBUG
	assign DBG_SPR_HIT = (DBG_SPR_NUM == DBG_SPR_SKIP);
	assign DBG_DRAW_NEXT = (DRAW_ST == DRAW_NEXT);
`endif
	
	assign INT = FRAME_DONE;
	
	always @(posedge CLK or negedge RST_N) begin
		bit         HBL_N_OLD,VBL_N_OLD;
		
		if (!RST_N) begin
			DISP_FB_X <= '0;
			DISP_FB_Y <= '0;
			FB_SEL <= 0;
		end else if (EN) begin
			if (DOT_CE) begin
				HBL_N_OLD <= HBL_N;
				VBL_N_OLD <= VBL_N;
				if (HBL_N) begin
					DISP_FB_X <= DISP_FB_X + 9'd1;
				end
				if (!HBL_N && HBL_N_OLD) begin
					DISP_FB_X <= '0;
					if (VBL_N) DISP_FB_Y <= DISP_FB_Y + 9'd1;
				end
				if (!VBL_N && VBL_N_OLD) begin
					DISP_FB_Y <= '0;
					FB_SEL <= ~FB_SEL;
				end
			end
		end
	end
	wire [18: 1] DRAW_FB_A = {DRAW_FB_Y^{9{SPR_DRAW_FLIPY}},DRAW_FB_X^{9{SPR_DRAW_FLIPX}}};
	wire [15: 0] DRAW_FB_D = {SPR_PRI,SPR_PAL,DRAW_PIX};
`ifdef DEBUG
	wire         DRAW_FB_WE = DRAW_FB_WRITE & CE_R & ~DBG_SPR_HIT;
`else
	wire         DRAW_FB_WE = DRAW_FB_WRITE & CE_R;
`endif
	
	wire [18: 1] DISP_FB_A = {DISP_FB_Y,DISP_FB_X};
	wire         DISP_FB_WE = ~SREG[1][2] & VBL_N & HBL_N & DOT_CE;
	
	assign FB0_A  = !FB_SEL ? DRAW_FB_A  : DISP_FB_A;
	assign FB0_D  = !FB_SEL ? DRAW_FB_D  : 16'h0000;
	assign FB0_WE = !FB_SEL ? DRAW_FB_WE : DISP_FB_WE;
	
	assign FB1_A  =  FB_SEL ? DRAW_FB_A  : DISP_FB_A;
	assign FB1_D  =  FB_SEL ? DRAW_FB_D  : 16'h0000;
	assign FB1_WE =  FB_SEL ? DRAW_FB_WE : DISP_FB_WE;
	
	assign OUT = FB_SEL ? FB0_Q : FB1_Q;
	
endmodule
