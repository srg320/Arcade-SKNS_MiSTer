// synopsys translate_off
`define SIM
// synopsys translate_on

module SKNS_SPR_RAM
(
	input          CLK,
	input  [13: 2] ADDR_A,
	input  [31: 0] DATA_A,
	input  [ 3: 0] WREN_A,
	output [31: 0] Q_A,
	
	input  [13: 2] ADDR_B,
	output [31: 0] Q_B
);

`ifdef SIM
	
	reg [31:0] MEM [2**13];
	initial begin
		MEM <= '{2**13{'0}};
	end
	always @(posedge CLK) begin
		if (WREN[0]) begin
			MEM[WRADDR][31:24] <= DATA[31:24];
		end
		if (WREN[1]) begin
			MEM[WRADDR][23:16] <= DATA[23:16];
		end
		if (WREN[2]) begin
			MEM[WRADDR][15:8] <= DATA[15:8];
		end
		if (WREN[3]) begin
			MEM[WRADDR][7:0] <= DATA[7:0];
		end
		
		Q <= MEM[RDADDR];
	end
	
`else

	wire [31:0] sub_wire0;
	wire [31:0] sub_wire1;

	altsyncram	altsyncram_component (
				.clock0 (CLK),
				.wren_a (|WREN_A),
				.address_b (ADDR_B),
				.data_b (32'h0),
				.wren_b (1'b0),
				.address_a (ADDR_A),
				.data_a (DATA_A),
				.q_a (sub_wire0),
				.q_b (sub_wire1),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (WREN_A),
				.byteena_b (4'h0),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.eccstatus (),
				.rden_a (1'b1),
				.rden_b (1'b1));
	defparam
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byteena_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.indata_reg_b = "CLOCK0",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**12,
		altsyncram_component.numwords_b = 2**12,
		altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = 12,
		altsyncram_component.widthad_b = 12,
		altsyncram_component.width_a = 32,
		altsyncram_component.width_b = 32,
		altsyncram_component.width_byteena_a = 4,
		altsyncram_component.width_byteena_b = 4,
		altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK0";
		
	assign Q_A = sub_wire0;
	assign Q_B = sub_wire1;
	
`endif
	
endmodule


module SKNS_TILE_RAM
(
	input          CLK,
	
	input  [14: 2] ADDR_A,
	input  [31: 0] DATA_A,
	input  [ 3: 0] WREN_A,
	output [31: 0] Q_A,
	
	input  [14: 2] ADDR_B,
	output [31: 0] Q_B
);

`ifdef SIM
	
	reg [31:0] MEM [2**13];
	initial begin
		MEM <= '{2**13{'0}};
	end
	always @(posedge CLK) begin
		if (WREN[0]) begin
			MEM[WRADDR][31:24] <= DATA[31:24];
		end
		if (WREN[1]) begin
			MEM[WRADDR][23:16] <= DATA[23:16];
		end
		if (WREN[2]) begin
			MEM[WRADDR][15:8] <= DATA[15:8];
		end
		if (WREN[3]) begin
			MEM[WRADDR][7:0] <= DATA[7:0];
		end
		
		Q <= MEM[RDADDR];
	end
	
`else

	wire [31:0] sub_wire0;
	wire [31:0] sub_wire1;

	altsyncram	altsyncram_component (
				.clock0 (CLK),
				.wren_a (|WREN_A),
				.address_b (ADDR_B),
				.data_b (32'h0),
				.wren_b (1'b0),
				.address_a (ADDR_A),
				.data_a (DATA_A),
				.q_a (sub_wire0),
				.q_b (sub_wire1),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (WREN_A),
				.byteena_b (4'h0),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.eccstatus (),
				.rden_a (1'b1),
				.rden_b (1'b1));
	defparam
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byteena_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.indata_reg_b = "CLOCK0",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**13,
		altsyncram_component.numwords_b = 2**13,
		altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = 13,
		altsyncram_component.widthad_b = 13,
		altsyncram_component.width_a = 32,
		altsyncram_component.width_b = 32,
		altsyncram_component.width_byteena_a = 4,
		altsyncram_component.width_byteena_b = 4,
		altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK0";
		
	assign Q_A = sub_wire0;
	assign Q_B = sub_wire1;
	
`endif
	
endmodule

module SKNS_PAL_RAM
(
	input          CLK,
	input  [14: 0] WRADDR,
	input  [15: 0] DATA,
	input  [ 1: 0] WREN,
	input  [14: 0] RDADDR,
	output [15: 0] Q
);

`ifdef SIM
	
	reg [15:0] MEM [2**15];
	initial begin
		MEM <= '{2**15{'0}};
	end
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
		
		Q <= MEM[RDADDR];
	end
	
`else

	wire [15:0] sub_wire0;
	
	altsyncram	altsyncram_component (
				.address_a (WRADDR),
				.byteena_a (WREN),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (|WREN),
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
				.data_b ({16{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**15,
		altsyncram_component.numwords_b = 2**15,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = 15,
		altsyncram_component.widthad_b = 15,
		altsyncram_component.width_a = 16,
		altsyncram_component.width_b = 16,
		altsyncram_component.width_byteena_a = 2;
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module SKNS_SPRITE_BUF
(
	input          CLK,
	input  [ 6: 0] WRADDR,
	input  [ 7: 0] DATA,
	input          WREN,
	input  [ 6: 0] RDADDR,
	output [ 7: 0] Q
);

`ifdef SIM
	
	reg [7:0] MEM [2**7];
	initial begin
		MEM <= '{2**7{'0}};
	end
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
	end
	assign Q < MEM[RDADDR];
	
`else

	wire [7:0] sub_wire0;
	
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
		altdpram_component.width = 8,
		altdpram_component.widthad = 7,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module SKNS_SPRITE_FIFO (
	input	         CLK,
	input          EN,
	input          RST,
	
	input	 [ 7: 0] DATA,
	input	         WRREQ,
	input	         RDREQ,
	output [ 7: 0] Q,
	
	output	      EMPTY,
	output	      FULL
);

	wire [ 7: 0] sub_wire0;
	bit  [ 7: 0] RADDR;
	bit  [ 7: 0] WADDR;
	bit  [ 8: 0] AMOUNT;
	
	always @(posedge CLK) begin
		if (RST) begin
			AMOUNT <= '0;
			RADDR <= '0;
			WADDR <= '0;
		end
		else if (EN) begin
			if (WRREQ && !AMOUNT[8]) begin
				WADDR <= WADDR + 8'd1;
			end
			if (RDREQ && AMOUNT) begin
				RADDR <= RADDR + 8'd1;
			end
			
			if (WRREQ && !RDREQ && !AMOUNT[8]) begin
				AMOUNT <= AMOUNT + 9'd1;
			end else if (!WRREQ && RDREQ && AMOUNT) begin
				AMOUNT <= AMOUNT - 9'd1;
			end
		end
	end
	assign EMPTY = ~|AMOUNT;
	assign FULL = AMOUNT[8];

`ifdef SIM

	reg [7:0]  MEM[256];
	initial begin
		MEM <= '{256{'0}};
	end
	
	always @(posedge CLK) begin
		if (EN) begin
			if (WRREQ) begin
				MEM[WADDR] <= DATA;
			end
		end
	end

	assign Q = MEM[RADDR];
											  	
`else 
	
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RADDR),
				.wraddress (WADDR),
				.wren (WRREQ && EN),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
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
		altdpram_component.width = 8,
		altdpram_component.widthad = 8,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
		
	assign Q = RADDR == WADDR && WRREQ ? DATA : sub_wire0;

`endif

endmodule

