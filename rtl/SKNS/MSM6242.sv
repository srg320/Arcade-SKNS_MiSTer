module MSM6242 
(
	input              CLK,
	input              RST_N,
	input              EN,
	
	input              X32K_CE,
	
	input              CE,
	input      [ 3: 0] A,
	input      [ 3: 0] DI,
	output reg [ 3: 0] DO,
	input              WR_N,
	input              RD_N,
	input              CS0_N,
	input              CS1,
	input              ALE,
	
	output             STDP
);

	bit  [ 7: 0] SEC,MIN,HOUR;
	bit  [ 3: 0] WEEK;
	bit  [ 7: 0] DAY,MONTH,YEAR;
	bit  [ 3: 0] REGD,REGE,REGF;
	bit  [14: 0] COUNTER;
	
	
	always @(posedge CLK or negedge RST_N) begin
		bit          RD_N_OLD,WR_N_OLD;
		bit  [ 3: 0] ADDR;
		bit          PULSE,PULSE_OLD;
		bit          SEL;
		bit          SEC_TICK,MIN_TICK,HOUR_TICK,DAY_TICK,MONTH_TICK,YEAR_TICK;
		
		if (!RST_N) begin
			{SEC,MIN,HOUR,DAY,WEEK,MONTH,YEAR} <= {8'h00,8'h00,8'h01,8'h01,4'h4,8'h01,8'h26};
			REGD <= 4'h0;
			REGE <= 4'h6;
			REGF <= 4'h4;
			COUNTER <= '0;
			ADDR <= '0;
			SEL <= 0;
		end else if (EN) begin
			if (CE) begin
				{SEC_TICK,MIN_TICK,HOUR_TICK,DAY_TICK,MONTH_TICK,YEAR_TICK} <= '0;
				if (SEC_TICK) begin
					SEC[3:0] <= SEC[3:0] + 4'd1;
					if (SEC[3:0] == 4'h9) begin
						SEC[3:0] <= 4'h0;
						SEC[7:4] <= SEC[7:4] + 4'd1;
						if (SEC[7:4] == 4'h5) begin
							SEC[7:4] <= 4'h0;
							MIN_TICK <= 1;
						end
					end
				end
				
				if (REGD[3]) begin
					if (SEC[7:4] >= 4'h3) begin
						SEC[7:4] <= SEC[7:4] - 4'd3;
						MIN_TICK <= 1;
					end else if (SEC[7:4] == 4'h4) begin
						SEC[7:4] <= SEC[7:4] + 4'd3;
					end
					REGD[3] <= 0;
				end
				
				if (MIN_TICK) begin
					MIN[3:0] <= MIN[3:0] + 4'd1;
					if (MIN[3:0] == 4'h9) begin
						MIN[3:0] <= 4'h0;
						MIN[7:4] <= MIN[7:4] + 4'd1;
						if (MIN[7:4] == 4'h5) begin
							MIN[7:4] <= 4'h0;
							HOUR_TICK <= 1;
						end
					end
				end
				
				if (HOUR_TICK) begin
					HOUR[3:0] <= HOUR[3:0] + 4'd1;
					if (HOUR[3:0] == 4'h9) begin
						HOUR[3:0] <= 4'h0;
						HOUR[5:4] <= HOUR[5:4] + 2'd1;
						if (HOUR[5:0] == 6'h11 && !REGF[2]) begin
							HOUR[6] <= ~HOUR[6];
						end
						if ((           HOUR[5:0] == 6'h23 &&  REGF[2]) ||
						    (HOUR[6] && HOUR[5:0] == 6'h11 && !REGF[2])) begin
							HOUR[5:0] <= 6'h00;
							DAY_TICK <= 1;
						end
					end
				end
				
				if (DAY_TICK) begin
					DAY[3:0] <= DAY[3:0] + 4'd1;
					if (DAY[3:0] == 4'h9) begin
						DAY[3:0] <= 4'h0;
						DAY[5:4] <= DAY[5:4] + 2'd1;
						if ((DAY[5:0] == 6'h31 && MONTH[4:0] == 5'h01) ||
						    (DAY[5:0] == 6'h28 && MONTH[4:0] == 5'h02) ||
							 (DAY[5:0] == 6'h31 && MONTH[4:0] == 5'h03) ||
							 (DAY[5:0] == 6'h30 && MONTH[4:0] == 5'h04) ||
							 (DAY[5:0] == 6'h31 && MONTH[4:0] == 5'h05) ||
							 (DAY[5:0] == 6'h30 && MONTH[4:0] == 5'h06) ||
							 (DAY[5:0] == 6'h31 && MONTH[4:0] == 5'h07) ||
							 (DAY[5:0] == 6'h31 && MONTH[4:0] == 5'h08) ||
							 (DAY[5:0] == 6'h30 && MONTH[4:0] == 5'h09) ||
							 (DAY[5:0] == 6'h31 && MONTH[4:0] == 5'h10) ||
							 (DAY[5:0] == 6'h30 && MONTH[4:0] == 5'h11) ||
							 (DAY[5:0] == 6'h31 && MONTH[4:0] == 5'h12)) begin
							DAY[5:0] <= 6'h01;
							MONTH_TICK <= 1;
						end
					end
					
					WEEK[2:0] <= WEEK[2:0] + 3'd1;
					if (WEEK[2:0] == 3'h6) begin
						WEEK[2:0] <= 3'd0;
					end
				end
				
				if (MONTH_TICK) begin
					MONTH[3:0] <= MONTH[3:0] + 4'd1;
					if (MONTH[3:0] == 4'h9) begin
						MONTH[3:0] <= 4'h0;
						MONTH[4:4] <= MONTH[4:4] + 1'd1;
						if (MONTH[4:0] == 5'h12) begin
							MONTH[4:0] <= 5'h01;
							YEAR_TICK <= 1;
						end
					end
				end
				
				if (YEAR_TICK) begin
					YEAR[3:0] <= YEAR[3:0] + 4'd1;
					if (YEAR[3:0] == 4'h9) begin
						YEAR[3:0] <= 4'h0;
						YEAR[7:4] <= YEAR[7:4] + 4'd1;
						if (YEAR[7:4] == 4'h9) begin
							YEAR[7:4] <= 4'h0;
						end
					end
				end
			end
			
			if (X32K_CE) begin
				if (!REGF[1]) COUNTER <= COUNTER + 15'd1;
				if (COUNTER == 15'h7FFF) begin
					SEC_TICK <= 1;
				end
				if (REGF[0]) begin
					COUNTER <= '0;
					if (CS1) REGF[0] <= 0;
				end
			end
				
			if (CE) begin
				case (REGE[3:2])
					2'b00: PULSE = COUNTER[9];
					2'b01: PULSE = COUNTER[14];
					2'b10: PULSE = SEC[7];
					2'b11: PULSE = MIN[7];
				endcase
				PULSE_OLD <= PULSE;
				REGD[2] <= (REGE[1] ? PULSE : PULSE && PULSE_OLD) | REGE[0];
			end
			
			//IO
			if (ALE && CS1) begin
				ADDR <= A;
				SEL <= ~CS0_N;
			end
			if (CE) begin
				WR_N_OLD <= WR_N;
				if (!WR_N && WR_N_OLD && CS1 && SEL) begin
					case (ADDR)
						4'h0: SEC[3:0] <= DI;
						4'h1: SEC[7:4] <= DI;
						4'h2: MIN[3:0] <= DI;
						4'h3: MIN[7:4] <= DI;
						4'h4: HOUR[3:0] <= DI;
						4'h5: HOUR[7:4] <= DI;
						4'h6: DAY[3:0] <= DI;
						4'h7: DAY[7:4] <= DI;
						4'h8: MONTH[3:0] <= DI;
						4'h9: MONTH[7:4] <= DI;
						4'hA: YEAR[3:0] <= DI;
						4'hB: YEAR[7:4] <= DI;
						4'hC: WEEK[3:0] <= DI;
						4'hD: REGD <= DI;
						4'hE: REGE <= DI;
						4'hF: REGF <= DI;
					endcase
				end
				
				RD_N_OLD <= RD_N;
				if (!RD_N && RD_N_OLD && CS1 && SEL) begin
					case (ADDR)
						4'h0: DO <= SEC[3:0];
						4'h1: DO <= SEC[7:4];
						4'h2: DO <= MIN[3:0];
						4'h3: DO <= MIN[7:4];
						4'h4: DO <= HOUR[3:0];
						4'h5: DO <= HOUR[7:4];
						4'h6: DO <= DAY[3:0];
						4'h7: DO <= DAY[7:4];
						4'h8: DO <= MONTH[3:0];
						4'h9: DO <= MONTH[7:4];
						4'hA: DO <= YEAR[3:0];
						4'hB: DO <= YEAR[7:4];
						4'hC: DO <= WEEK[3:0];
						4'hD: DO <= REGD;
						4'hE: DO <= REGE;
						4'hF: DO <= REGF;
					endcase
				end
			end
			
			STDP <= ~REGD[2];
		end
	end

endmodule
