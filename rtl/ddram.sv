
module ddram
(
	output         DDRAM_CLK,
	input          DDRAM_BUSY,
	output [ 7: 0] DDRAM_BURSTCNT,
	output [28: 0] DDRAM_ADDR,
	input  [63: 0] DDRAM_DOUT,
	input          DDRAM_DOUT_READY,
	output         DDRAM_RD,
	output [63: 0] DDRAM_DIN,
	output [ 7: 0] DDRAM_BE,
	output         DDRAM_WE,
	
	input          clk,
	input          rst,

	input  [19: 2] dram_addr,
	output [31: 0] dram_dout,
	input  [31: 0] dram_din,
	input          dram_rd,
	input  [ 3: 0] dram_wr,
	output         dram_busy,
	
	input  [19: 0] brom_addr,
	output [ 7: 0] brom_dout,
	input          brom_rd,
	output         brom_busy,
	
	input  [20: 1] grom_addr,
	output [15: 0] grom_dout,
	input          grom_rd,
	output         grom_busy,

	input  [20: 1] bios_addr,
	input  [15: 0] bios_din,
	input  [ 1: 0] bios_wr,
	output         bios_busy,
	
	input  [26: 3] rom_addr,
	output [63: 0] rom_dout,
	input          rom_rd,
	output         rom_busy,

	input  [31: 3] fb_addr,
	input  [63: 0] fb_din,
	input  [ 7: 0] fb_we,
	output         fb_busy
);

reg  [ 31:  3] ram_address;
reg  [ 63:  0] ram_din;
reg  [  7:  0] ram_be;
reg  [  7:  0] ram_burst;
reg            ram_read = 0;
reg            ram_write = 0;
reg  [  3:  0] ram_chan;

reg  [ 19:  2] dram_rcache_addr,dram_write_addr;
reg  [ 31:  0] dram_write_data;
reg  [  3:  0] dram_write_be;
reg            dram_write_busy;
reg            dram_rcache_dirty;
reg            dram_rcache_busy;
reg            dram_read_busy;

reg  [ 19:  0] brom_rcache_addr;
reg            brom_rcache_dirty;
reg            brom_rcache_busy;
reg            brom_read_busy;

reg  [ 20:  1] grom_rcache_addr;
reg            grom_rcache_dirty;
reg            grom_rcache_busy;
reg            grom_read_busy;

reg  [ 20:  1] bios_write_addr;
reg  [ 15:  0] bios_write_data;
reg  [  1:  0] bios_be;
reg            bios_write_busy;

reg  [ 26:  3] rom_rcache_addr;
reg            rom_rcache_busy;
reg            rom_read_busy;

reg  [  2:  0] state = 0;

reg  [  6:  0] cache_wraddr;
reg            cache_update;

reg            old_rst;
reg            dram_rd_old,dram_wr_old;
reg            brom_rd_old;
reg            grom_rd_old;
reg            bios_wr_old;
reg            rom_rd_old;
reg            fb_we_old;
always @(posedge clk) begin
	{dram_rd_old,dram_wr_old} <= {dram_rd,|dram_wr};
	brom_rd_old <= brom_rd;
	grom_rd_old <= grom_rd;
	bios_wr_old <= |bios_wr;
	rom_rd_old <= rom_rd;
	fb_we_old <= |fb_we;
	old_rst <= rst;
end
wire           rst_pulse = (rst && !old_rst);

wire           fb_fifo_wrreq,fb_fifo_rdreq;
always_comb begin
	fb_fifo_wrreq = (|fb_we && !fb_we_old);
	fb_fifo_rdreq = (state == 3'h1 && !DDRAM_BUSY && ram_chan == 4'd5);
end

wire [100:  0] fb_fifo_dout;
wire           fb_fifo_empty,fb_fifo_full;

ddr_infifo #(4) ramh_fifo (clk, rst_pulse, {fb_addr,fb_we,fb_din}, fb_fifo_wrreq, fb_fifo_rdreq, fb_fifo_dout, fb_fifo_empty, fb_fifo_full);

wire [ 31:  3] fb_write_addr;
wire [ 63:  0] fb_write_data;
wire [  7:  0] fb_write_be;

assign {fb_write_addr,fb_write_be,fb_write_data} = fb_fifo_dout;

always @(posedge clk) begin
	bit write,read,burst_read;
	bit [3:0] chan;
	bit [6:0] word_cnt;

	{dram_rcache_busy,brom_rcache_busy,grom_rcache_busy,rom_rcache_busy} <= '0;
	if (rst_pulse) begin		
		{dram_rcache_dirty,brom_rcache_dirty,grom_rcache_dirty} <= '1;
	end
	else begin
		if (dram_rd && !dram_rd_old) begin
			if (dram_addr[19:5] != dram_rcache_addr[19:5] || dram_rcache_dirty) begin
				dram_read_busy <= 1;
			end
			dram_rcache_addr <= dram_addr[19:2];
			dram_rcache_busy <= 1;
			dram_rcache_dirty <= 0; 
		end
		
		if (brom_rd && !brom_rd_old) begin
			if (brom_addr[19:5] != brom_rcache_addr[19:5] || brom_rcache_dirty) begin
				brom_read_busy <= 1;
			end
			brom_rcache_addr <= brom_addr;
			brom_rcache_busy <= 1;
			brom_rcache_dirty <= 0;
		end
		
		if (grom_rd && !grom_rd_old) begin
			if (grom_addr[20:5] != grom_rcache_addr[20:5] || grom_rcache_dirty) begin
				grom_read_busy <= 1;
			end
			grom_rcache_addr <= grom_addr;
			grom_rcache_busy <= 1;
			grom_rcache_dirty <= 0;
		end
		
		if (rom_rd && !rom_rd_old) begin
			if (rom_addr[26:5] != rom_rcache_addr[26:5]) begin
				rom_read_busy <= 1;
			end
			rom_rcache_addr <= rom_addr;
			rom_rcache_busy <= 1;
		end
	end
		
	if (rst_pulse) begin
		{dram_write_busy,bios_write_busy/*,fb_write_busy*/} <= 0;
	end
	else begin
		if (|dram_wr && !dram_wr_old) begin
			if (dram_addr[19:5] == dram_rcache_addr[19:5]) begin
				dram_rcache_dirty <= 1;
			end
			dram_write_addr <= dram_addr;
			dram_write_data <= dram_din;
			dram_write_be <= dram_wr;
			dram_write_busy <= 1;
		end
		
		if (|bios_wr && !bios_wr_old) begin
			bios_write_addr <= bios_addr;
			bios_write_data <= bios_din;
			bios_be <= bios_wr;
			bios_write_busy <= 1;	
		end
	end
	
	if (rst_pulse) begin
		state <= '0;
		ram_write <= 0;
		ram_read  <= 0;
	end
	else if(!DDRAM_BUSY) begin
		ram_write <= 0;
		ram_read  <= 0;

		case (state)
			0: begin
				if (dram_write_busy) begin
					dram_write_busy <= 0;
					ram_address <= {5'b00110,7'b1001111,dram_write_addr[19:3]};
					ram_din		<= {2{dram_write_data}};
					case (dram_write_addr[2])
						1'b0: ram_be <= {dram_write_be,4'b0000};
						1'b1: ram_be <= {4'b0000,dram_write_be};
					endcase
					ram_write 	<= 1;
					ram_burst   <= 1;
					ram_chan    <= 4'd0;
					state       <= 3'h1;
				end
				else if (dram_read_busy) begin
					ram_address <= {5'b00110,7'b1001111,dram_rcache_addr[19:5],2'b00};
					ram_be      <= 8'hFF;
					ram_read    <= 1;
					ram_burst   <= 4;
					ram_chan    <= 4'd0;
					cache_wraddr<= '0;
					word_cnt    <= '0;
					state       <= 3'h2;
				end
				else if (brom_read_busy) begin
					ram_address <= {5'b00110,6'b100000,1'b0,brom_rcache_addr[19:5],2'b00};
					ram_be      <= 8'hFF;
					ram_read    <= 1;
					ram_burst   <= 4;
					ram_chan    <= 4'd1;
					cache_wraddr<= '0;
					word_cnt    <= '0;
					state       <= 3'h2;
				end
				else if (grom_read_busy) begin
					ram_address <= {5'b00110,6'b100001,grom_rcache_addr[20:5],2'b00};
					ram_be      <= 8'hFF;
					ram_read    <= 1;
					ram_burst   <= 4;
					ram_chan    <= 4'd2;
					cache_wraddr<= '0;
					word_cnt    <= '0;
					state       <= 3'h2;
				end
				else if (bios_write_busy) begin
					bios_write_busy <= 0;
					ram_address <= {5'b00110,6'b100000,bios_write_addr[20:3]};
					ram_din		<= {4{bios_write_data}};
					case (bios_write_addr[2:1])
						2'b00: ram_be <= {bios_be,6'b000000};
						2'b01: ram_be <= {2'b00,bios_be,4'b0000};
						2'b10: ram_be <= {4'b0000,bios_be,2'b00};
						2'b11: ram_be <= {6'b000000,bios_be};
					endcase
					ram_write 	<= 1;
					ram_burst   <= 1;
					ram_chan    <= 4'd3;
					state       <= 3'h1;
				end
				else if (rom_read_busy) begin
					ram_address <= {5'b00110,rom_rcache_addr[26:5],2'b00};
					ram_be      <= 8'hFF;
					ram_read    <= 1;
					ram_burst   <= 4;
					ram_chan    <= 4'd4;
					cache_wraddr<= '0;
					word_cnt    <= '0;
					state       <= 3'h2;
				end
				else if (!fb_fifo_empty) begin
					ram_address <= fb_write_addr;
					ram_din		<= fb_write_data;
					ram_be      <= fb_write_be;
					ram_write 	<= 1;
					ram_burst   <= 1;
					ram_chan    <= 4'd5;
					state       <= 3'h1;
				end
			end

			3'h1: begin
				state <= 0;
			end
		
			3'h2: if (DDRAM_DOUT_READY) begin
				cache_wraddr <= cache_wraddr + 7'd1;
				word_cnt <= word_cnt + 7'd1;
				if (word_cnt == ram_burst[6:0] - 7'd1) begin
					if (ram_chan == 4'd0 ) begin dram_read_busy <= 0; dram_rcache_busy <= 1; end
					if (ram_chan == 4'd1 ) begin brom_read_busy <= 0; brom_rcache_busy <= 1; end
					if (ram_chan == 4'd2 ) begin grom_read_busy <= 0; grom_rcache_busy <= 1; end
					if (ram_chan == 4'd4 ) begin rom_read_busy <= 0; rom_rcache_busy <= 1; end
					state <= 0;
				end
			end
		endcase
	end
end

wire           cache_wren = (state == 3'h2) && DDRAM_DOUT_READY && !DDRAM_BUSY;
wire [ 63:  0] dram_cache_q,brom_cache_q,grom_cache_q,rom_cache_q;

ddr_cache_ram #(2) cache0 (clk, cache_wraddr[1:0], DDRAM_DOUT, cache_wren & ram_chan == 0, dram_addr[4:3], dram_cache_q);
ddr_cache_ram #(2) cache1 (clk, cache_wraddr[1:0], DDRAM_DOUT, cache_wren & ram_chan == 1, brom_addr[4:3], brom_cache_q);
ddr_cache_ram #(2) cache2 (clk, cache_wraddr[1:0], DDRAM_DOUT, cache_wren & ram_chan == 2, grom_addr[4:3], grom_cache_q);
ddr_cache_ram #(2) cache4 (clk, cache_wraddr[1:0], DDRAM_DOUT, cache_wren & ram_chan == 4, rom_addr[4:3], rom_cache_q);

always_comb begin
	case (dram_rcache_addr[2])
		1'b0: dram_dout = dram_cache_q[63:32];
		1'b1: dram_dout = dram_cache_q[31:00];
	endcase
	dram_busy = dram_write_busy | dram_read_busy | dram_rcache_busy;
	
	case (brom_rcache_addr[2:0])
		3'b000: brom_dout = brom_cache_q[63:56];
		3'b001: brom_dout = brom_cache_q[55:48];
		3'b010: brom_dout = brom_cache_q[47:40];
		3'b011: brom_dout = brom_cache_q[39:32];
		3'b100: brom_dout = brom_cache_q[31:24];
		3'b101: brom_dout = brom_cache_q[23:16];
		3'b110: brom_dout = brom_cache_q[15:08];
		3'b111: brom_dout = brom_cache_q[07:00];
	endcase
	brom_busy = brom_read_busy | brom_rcache_busy;
	
	case (grom_rcache_addr[2:1])
		2'b00: grom_dout = grom_cache_q[63:48];
		2'b01: grom_dout = grom_cache_q[47:32];
		2'b10: grom_dout = grom_cache_q[31:16];
		2'b11: grom_dout = grom_cache_q[15:00];
	endcase
	grom_busy = grom_read_busy | grom_rcache_busy;
	
	rom_dout = rom_cache_q;
	rom_busy = rom_read_busy | rom_rcache_busy;
	
	fb_busy = fb_fifo_full;
end

assign DDRAM_CLK      = clk;
assign DDRAM_BURSTCNT = ram_burst;
assign DDRAM_BE       = ram_be;
assign DDRAM_ADDR     = ram_address; // RAM at 0x24000000,0x30000000
assign DDRAM_RD       = ram_read;
assign DDRAM_DIN      = ram_din;
assign DDRAM_WE       = ram_write;

endmodule

module ddr_cache_ram #(parameter wa = 2) (
	clock,
	wraddress,
	data,
	wren,
	rdaddress,
	q);

	input	  clock;
	input	[wa-1:0]  wraddress;
	input	[63:0] data;
	input	       wren;
	input	[wa-1:0]  rdaddress;
	output	[63:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0	  wren;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire [63:0] sub_wire0;
	wire [63:0] q = sub_wire0;

	altsyncram	altsyncram_component (
				.address_a (wraddress),
				.byteena_a (1'b1),
				.clock0 (clock),
				.data_a (data),
				.wren_a (wren),
				.address_b (rdaddress),
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
				.data_b ({64{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**wa,
		altsyncram_component.numwords_b = 2**wa,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = wa,
		altsyncram_component.widthad_b = wa,
		altsyncram_component.width_a = 64,
		altsyncram_component.width_b = 64,
		altsyncram_component.width_byteena_a = 1;

endmodule


module ddr_infifo 
#(parameter l = 3)
(
	input	          CLK,
	input           RST,
	
	input	 [100: 0] DATA,
	input	          WRREQ,
	
	input	          RDREQ,
	output [100: 0] Q,
	output	       EMPTY,
	output	       FULL
);

	wire [100: 0] sub_wire0;
	bit  [l-1: 0] RADDR;
	bit  [l-1: 0] WADDR;
	bit  [  l: 0] AMOUNT;
	
	always @(posedge CLK) begin
		if (RST) begin
			AMOUNT <= '0;
			RADDR <= '0;
			WADDR <= '0;
		end
		else begin
			if (WRREQ && !AMOUNT[l]) begin
				WADDR <= WADDR + 1'd1;
			end
			if (RDREQ && AMOUNT) begin
				RADDR <= RADDR + 1'd1;
			end
			
			if (WRREQ && !RDREQ && !AMOUNT[l]) begin
				AMOUNT <= AMOUNT + 1'd1;
			end else if (!WRREQ && RDREQ && AMOUNT) begin
				AMOUNT <= AMOUNT - 1'd1;
			end
		end
	end
	assign EMPTY = ~|AMOUNT;
	assign FULL = AMOUNT[l];
	
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RADDR),
				.wraddress (WADDR),
				.wren (WRREQ),
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
		altdpram_component.width = 101,
		altdpram_component.widthad = l,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
		
	assign Q = sub_wire0;

endmodule
