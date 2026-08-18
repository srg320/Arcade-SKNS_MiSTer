module spc_fb_320x256x16
(
	input             clock,
	input      [16:0] address,
	input      [15:0] data,
	input             wren,
	output     [15:0] q
);
	
	wire [15:0] ram64Kx16_q,ram16Kx16_q;
	spram #(16,16)	ram64Kx16l
	(
		.clock(clock),
		.address(address[15:0]),
		.data(data),
		.wren(wren & ~address[16]),
		.q(ram64Kx16_q)
	);
	
	spram #(14,16)	ram16Kx16l
	(
		.clock(clock),
		.address(address[13:0]),
		.data(data),
		.wren(wren & address[16] & ~address[15] & ~address[14]),
		.q(ram16Kx16_q)
	);
	
	assign q = !address[16] ? ram64Kx16_q : ram16Kx16_q;

endmodule
