module sdram1
(
	inout  reg [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [12:0] SDRAM_A,    // 13 bit multiplexed address bus
	output reg        SDRAM_DQML, // byte mask
	output reg        SDRAM_DQMH, // byte mask
	output reg  [1:0] SDRAM_BA,   // two banks
	output            SDRAM_nCS,  // a single chip select
	output reg        SDRAM_nWE,  // write enable
	output reg        SDRAM_nRAS, // row address select
	output reg        SDRAM_nCAS, // columns address select
	output            SDRAM_CLK,
	output            SDRAM_CKE,

	// cpu/chipset interface
	input             init,			// init signal after FPGA config to initialize RAM
	output reg        init_done,
	input             clk,			// sdram is accessed at up to 128MHz
	input             sync,			//

	input     [25: 3] waddr,
	input     [63: 0] din,
	input             wr,
	
	input     [23: 1] raddr1,
	input             rd1,
	output    [15: 0] dout1,
	
	input     [23: 1] raddr2,
	input             rd2,
	output    [15: 0] dout2,
	
	input     [23: 1] raddr3,
	input             rd3,
	output    [15: 0] dout3,
	
	input     [23: 1] raddr4,
	input             rd4,
	output    [15: 0] dout4,
	
	input     [17: 1] addr5,
	input     [15: 0] din5,
	input     [ 1: 0] we5,
	input             rd5
	
`ifdef DEBUG
	                   ,
	output [1:0] dbg_ctrl_bank,
	output [1:0] dbg_ctrl_cmd,
	output       dbg_ctrl_we,
	output       dbg_ctrl_rfs,
	output       dbg_ctrl_chip,
	output       dbg_data_read,
	output       dbg_out0_read
`endif
);

	localparam RASCAS_DELAY   = 3'd3; // tRCD=20ns -> 2 cycles@85MHz
	localparam BURST_1        = 3'd0; // 0=1, 1=2, 2=4, 3=8, 7=full page
	localparam BURST_2        = 3'd0; // 0=1, 1=2, 2=4, 3=8, 7=full page
	localparam ACCESS_TYPE    = 1'd0; // 0=sequential, 1=interleaved
	localparam CAS_LATENCY_1  = 3'd2; // 2/3 allowed
	localparam CAS_LATENCY_2  = 3'd2; // 2/3 allowed
	localparam OP_MODE        = 2'd0; // only 0 (standard operation) allowed
	localparam NO_WRITE_BURST = 1'd1; // 0=write burst enabled, 1=only single access write

	localparam bit [12:0] MODE[2] = '{{3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY_2, ACCESS_TYPE, BURST_2},
	                                  {3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY_1, ACCESS_TYPE, BURST_1}}; 
	
	localparam STATE_IDLE  = 3'd0;             // state to check the requests
	localparam STATE_START = STATE_IDLE+1'd1;  // state in which a new command is started
	localparam STATE_CONT  = STATE_START+RASCAS_DELAY;
	localparam STATE_READY = STATE_CONT+CAS_LATENCY_1+1'd1;
	localparam STATE_LAST  = STATE_READY;      // last state in cycle
	
	localparam MODE_NORMAL = 2'b00;
	localparam MODE_RESET  = 2'b01;
	localparam MODE_LDM    = 2'b10;
	localparam MODE_PRE    = 2'b11;

	// initialization 
	reg [2:0] init_state = '0;
	reg [1:0] mode;
	reg       init_chip = 0;
	always @(posedge clk) begin
		reg [4:0] reset = 5'h1f;
		reg init_old = 0;
		
		if(mode != MODE_NORMAL || init_state != STATE_IDLE || reset) begin
			init_state <= init_state + 1'd1;
			if (init_state == STATE_LAST) init_state <= STATE_IDLE;
		end

		init_old <= init;
		if (init_old & ~init) begin
			reset <= 5'h1f; 
			init_chip <= 0;
			init_done <= 0;
		end
		else if (init_state == STATE_LAST) begin
			if(reset != 0) begin
				reset <= reset - 5'd1;
				if (reset == 15 || reset == 14) begin mode <= MODE_PRE; init_chip <= (reset == 15); end
				else if(reset == 4 || reset == 3) begin mode <= MODE_LDM; init_chip <= (reset == 4); end
				else                mode <= MODE_RESET;
			end
			else begin
				mode <= MODE_NORMAL;
				init_chip <= 0;
				init_done <= 1;
			end
		end
	end
	
	localparam CTRL_IDLE = 2'd0;
	localparam CTRL_RAS = 2'd1;
	localparam CTRL_CAS = 2'd2;
	
	typedef struct packed
	{
		bit [ 1: 0] CMD;	//command
		bit         CHIP;	//chip n
		bit [ 1: 0] BANK;	//bank
		bit [23: 1] ADDR;	//read/write address
		bit [15: 0] DATA;	//write data
		bit         RD;		//read	
		bit         WE;		//write enable
		bit [ 1: 0] BE;		//write byte enable
		bit         RFS;	//refresh	
		bit [ 1: 0] CH;	//channel	
	} state_t;
	state_t state[6];
	reg [ 4: 0] st_num;
	
	reg [63: 0] data;
	reg         load,read_act,read1,read2,read3,read4,read5;
	reg [ 1: 0] write5;
	reg [15: 0] data5;
	always @(posedge clk) begin
		reg sync_old;
		reg [23: 1] raddr1_prev,raddr2_prev,raddr3_prev,raddr4_prev;
		
		sync_old <= sync;
		if (!init_done) begin
			st_num <= 5'd0;
		end else begin
			if (st_num < 5'd16) st_num <= st_num + 5'd1;
			
			if (!sync && sync_old) begin
				st_num <= 5'd1;
				data <= din;
				load <= wr;
				
				read_act <= 0; 
				{read1,read2,read3,read4} <= {rd1,rd2,rd3,rd4};
				if (rd1) begin
					raddr1_prev <= raddr1;
					if (raddr1 != raddr1_prev) read_act <= 1;
				end
				if (rd2) begin
					raddr2_prev <= raddr2;
					if (raddr2 != raddr2_prev) read_act <= 1;
				end
				if (rd3) begin
					raddr3_prev <= raddr3;
					if (raddr3 != raddr3_prev) read_act <= 1;
				end
				if (rd4) begin
					raddr4_prev <= raddr4;
					if (raddr4 != raddr4_prev) read_act <= 1;
				end
				
				read5 <= rd5;
				write5 <= we5;
				data5 <= din5;
			end
			if (st_num[3:0] == 4'h7) begin
//				read2 <= 0;
//				if (rd2) begin
//					raddr2_prev <= raddr2;
//					read2 <= (raddr2 != raddr2_prev);
//				end
			end
		end
	end
	
	always @(posedge clk) begin
		state[0] <= '0;
		if (!init_done) begin
			state[0].CMD <= init_state == STATE_START ? CTRL_RAS : 
			                init_state == STATE_CONT  ? CTRL_CAS : 
								                             CTRL_IDLE;
		end else begin
			if (load)
				case (st_num[3:0])
					4'd1:  begin state[0].CMD  <= CTRL_RAS;
									 state[0].ADDR <= {waddr[23:3],2'b00};
									 state[0].BANK <= waddr[25:24];
									 state[0].CHIP <= 0; end
									  
					4'd4:  begin state[0].CMD  <= CTRL_CAS;
									 state[0].ADDR <= {waddr[23:3],2'b00};
									 state[0].DATA <= data[63:48];
									 state[0].WE   <= 1;
									 state[0].BE   <= 2'b11;
									 state[0].BANK <= waddr[25:24];
									 state[0].CHIP <= 0; end
									 
					4'd5:  begin state[0].CMD  <= CTRL_CAS;
									 state[0].ADDR <= {waddr[23:3],2'b01};
									 state[0].DATA <= data[47:32];
									 state[0].WE   <= 1;
									 state[0].BE   <= 2'b11;
									 state[0].BANK <= waddr[25:24];
									 state[0].CHIP <= 0; end
									 
					4'd6:  begin state[0].CMD  <= CTRL_CAS;
									 state[0].ADDR <= {waddr[23:3],2'b10};
									 state[0].DATA <= data[31:16];
									 state[0].WE   <= 1;
									 state[0].BE   <= 2'b11;
									 state[0].BANK <= waddr[25:24];
									 state[0].CHIP <= 0; end
									 
					4'd7:  begin state[0].CMD  <= CTRL_CAS;
									 state[0].ADDR <= {waddr[23:3],2'b11};
									 state[0].DATA <= data[15:0];
									 state[0].WE   <= 1;
									 state[0].BE   <= 2'b11;
									 state[0].BANK <= waddr[25:24];
									 state[0].CHIP <= 0; end
									
					4'd10: begin state[0].CMD  <= CTRL_RAS;
									 state[0].RFS  <= 1;
									 state[0].CHIP <= 0; end
									
					default:;
				endcase
			else
				case (st_num[3:0])
					4'd1:  begin state[0].CMD  <= read1 && read_act ? CTRL_RAS : CTRL_IDLE;
									 state[0].ADDR <= {raddr1[23:1]};
									 state[0].BANK <= 2'h0;
									 state[0].CH   <= 2'h0;
									 state[0].CHIP <= 0; end
									 
					4'd2:  begin state[0].CMD  <= read2 && read_act ? CTRL_RAS : CTRL_IDLE;
									 state[0].ADDR <= {raddr2[23:1]};
									 state[0].BANK <= 2'h1;
									 state[0].CH   <= 2'h1;
									 state[0].CHIP <= 0; end
									 
					4'd3:  begin state[0].CMD  <= read3 && read_act ? CTRL_RAS : CTRL_IDLE;
									 state[0].ADDR <= {raddr3[23:1]};
									 state[0].BANK <= 2'h2;
									 state[0].CH   <= 2'h2;
									 state[0].CHIP <= 0; end
									 
					4'd4:  begin state[0].CMD  <= read4 && read_act ? CTRL_RAS : CTRL_IDLE;
									 state[0].ADDR <= {raddr4[23:1]};
									 state[0].BANK <= 2'h3;
									 state[0].CH   <= 2'h3;
									 state[0].CHIP <= 0; end
									  
					4'd5:  begin state[0].CMD  <= read1 && read_act ? CTRL_CAS : CTRL_IDLE;
									 state[0].ADDR <= {raddr1[23:1]};
									 state[0].RD   <= read1 && read_act;
									 state[0].BANK <= 2'h0;
									 state[0].CH   <= 2'h0;
									 state[0].CHIP <= 0; end
									 
					4'd6:  begin state[0].CMD  <= read2 && read_act ? CTRL_CAS : CTRL_IDLE;
									 state[0].ADDR <= {raddr2[23:1]};
									 state[0].RD   <= read2 && read_act;
									 state[0].BANK <= 2'h1;
									 state[0].CH   <= 2'h1;
									 state[0].CHIP <= 0; end
									 
					4'd7:  begin state[0].CMD  <= read3 && read_act ? CTRL_CAS : CTRL_IDLE;
									 state[0].ADDR <= {raddr3[23:1]};
									 state[0].RD   <= read3 && read_act;
									 state[0].BANK <= 2'h2;
									 state[0].CH   <= 2'h2;
									 state[0].CHIP <= 0; end
									 
					4'd8:  begin state[0].CMD  <= read4 && read_act ? CTRL_CAS : CTRL_IDLE;
									 state[0].ADDR <= {raddr4[23:1]};
									 state[0].RD   <= read4 && read_act;
									 state[0].BANK <= 2'h3;
									 state[0].CH   <= 2'h3;
									 state[0].CHIP <= 0; end
									
					4'd9:  begin state[0].CMD  <= !read_act && !write5 && !read5 ? CTRL_RAS : CTRL_IDLE;
									 state[0].RFS  <= !read_act && !write5 && !read5;
									 state[0].CHIP <= 0; end
									
					4'd12: begin state[0].CMD  <= write5 || read5 ? CTRL_RAS : CTRL_IDLE;
									 state[0].ADDR <= {6'b000000,addr5[17:1]};
									 state[0].BANK <= 2'h2;
									 state[0].CH   <= 2'h2;
									 state[0].CHIP <= 0; end
									
					4'd14: begin state[0].CMD  <= write5 || read5 ? CTRL_CAS : CTRL_IDLE;
									 state[0].ADDR <= {6'b000000,addr5[17:1]};
									 state[0].DATA <= data5;
									 state[0].RD   <= read5;
									 state[0].WE   <= |write5;
									 state[0].BE   <= write5;
									 state[0].BANK <= 2'h2;
									 state[0].CH   <= 2'h2;
									 state[0].CHIP <= 0; end
									
					default:;
				endcase
		end
	end
	always @(posedge clk) begin
		state[1] <= state[0];
		state[2] <= state[1];
		state[3] <= state[2];
		state[4] <= state[3];
		state[5] <= state[4];
	end
	
	wire [ 1: 0] ctrl_cmd  = state[0].CMD;
	wire [23: 1] ctrl_addr = state[0].ADDR;
	wire [15: 0] ctrl_data = state[0].DATA;
//	wire         ctrl_rd   = state[0].RD;
	wire         ctrl_we   = state[0].WE;
	wire [ 1: 0] ctrl_be   = state[0].BE;
	wire [ 1: 0] ctrl_bank = state[0].BANK;
	wire         ctrl_rfs  = state[0].RFS;
	wire         ctrl_chip = state[0].CHIP;
	
	wire         out0_read = state[4].RD;
	wire [ 1: 0] ch0_read  = state[4].CH;
	
	reg [15: 0] rbuf;
	always @(posedge clk) begin
		rbuf <= SDRAM_DQ;
		if (out0_read && ch0_read == 2'd0) dout1 <= rbuf;
		if (out0_read && ch0_read == 2'd1) dout2 <= rbuf;
		if (out0_read && ch0_read == 2'd2) dout3 <= rbuf;
		if (out0_read && ch0_read == 2'd3) dout4 <= rbuf;
	end
	

	localparam CMD_NOP             = 3'b111;
	localparam CMD_ACTIVE          = 3'b011;
	localparam CMD_READ            = 3'b101;
	localparam CMD_WRITE           = 3'b100;
	localparam CMD_BURST_TERMINATE = 3'b110;
	localparam CMD_PRECHARGE       = 3'b010;
	localparam CMD_AUTO_REFRESH    = 3'b001;
	localparam CMD_LOAD_MODE       = 3'b000;
	
	// SDRAM state machines
	wire [23:1] a = ctrl_addr;
	wire [15:0] d = ctrl_data;
	wire  [1:0] dqm = ~ctrl_be;
	wire        ra10 = 1;
	wire        wa10 = 1;
	always @(posedge clk) begin
		if (ctrl_cmd == CTRL_RAS || ctrl_cmd == CTRL_CAS) SDRAM_BA <= (mode == MODE_NORMAL) ? ctrl_bank : 2'b00;

		casex({init_done,ctrl_rfs,ctrl_we,mode,ctrl_cmd})
			{3'bX0X, MODE_NORMAL, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_ACTIVE,ctrl_chip};
			{3'bX1X, MODE_NORMAL, 2'bXX   }: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_AUTO_REFRESH,ctrl_chip};
			{3'b101, MODE_NORMAL, CTRL_CAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_WRITE,ctrl_chip};
			{3'b100, MODE_NORMAL, CTRL_CAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_READ,ctrl_chip};

			// init
			{3'bXXX,    MODE_LDM, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_LOAD_MODE, init_chip};
			{3'bXXX,    MODE_PRE, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_PRECHARGE, init_chip};

										   default: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_NOP,1'b1};
		endcase
		
		SDRAM_DQ <= 'Z;
		casex({init_done,ctrl_rfs,ctrl_we,mode,ctrl_cmd})
			{3'b101, MODE_NORMAL, CTRL_CAS}: begin SDRAM_DQ <= d; end
										   default: ;
		endcase

		if (mode == MODE_NORMAL) begin
			casex ({ctrl_we,ctrl_cmd})
				{1'bX,CTRL_RAS}: SDRAM_A <= {a[23:11]};
				{1'b0,CTRL_CAS}: SDRAM_A <= {2'b00,ra10,a[10:1]};
				{1'b1,CTRL_CAS}: SDRAM_A <= {dqm  ,wa10,a[10:1]};
			endcase;
		end
		else if (mode == MODE_LDM && ctrl_cmd == CTRL_RAS) SDRAM_A <= MODE[init_chip];
		else if (mode == MODE_PRE && ctrl_cmd == CTRL_RAS) SDRAM_A <= 13'b0010000000000;
		else SDRAM_A <= '0;
	end
	
	assign SDRAM_CKE = 1;
	assign {SDRAM_DQMH,SDRAM_DQML} = SDRAM_A[12:11];
	
`ifdef DEBUG
	assign dbg_ctrl_bank = ctrl_bank;
	assign dbg_ctrl_cmd = ctrl_cmd;
	assign dbg_ctrl_we = ctrl_we;
	assign dbg_ctrl_rfs = ctrl_rfs;
	assign dbg_ctrl_chip = ctrl_chip;
	assign dbg_out0_read = out0_read;
`endif

	altddio_out
	#(
		.extend_oe_disable("OFF"),
		.intended_device_family("Cyclone V"),
		.invert_output("OFF"),
		.lpm_hint("UNUSED"),
		.lpm_type("altddio_out"),
		.oe_reg("UNREGISTERED"),
		.power_up_high("OFF"),
		.width(1)
	)
	sdramclk_ddr
	(
		.datain_h(1'b0),
		.datain_l(1'b1),
		.outclock(clk),
		.dataout(SDRAM_CLK),
		.aclr(1'b0),
		.aset(1'b0),
		.oe(1'b1),
		.outclocken(1'b1),
		.sclr(1'b0),
		.sset(1'b0)
	);

endmodule
