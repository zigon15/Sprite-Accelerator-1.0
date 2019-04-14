`timescale 1ns / 1ps

module ClockDiv(
			input clk,
			input rst,
			input [31 : 0] ClockDiv,
			output toggle
    );

		reg toggle_d = 1'b0, toggle_q = 1'b0;
		reg [31:0] ctr_d = 32'b0, ctr_q = 32'b0;

		assign toggle = toggle_q;

		always @(*) begin
			toggle_d = toggle_q;
			ctr_d = ctr_q;

			if(ctr_q >= ((ClockDiv - 1) / 2) ) begin
				ctr_d = 31'b0;
				toggle_d = ~toggle_q;
			end else begin
				ctr_d = ctr_q + 1'b1;
			end
		end

 		always @(posedge clk) begin
    	if (rst) begin
      	ctr_q <= 1'b0;
				toggle_q <= 1'b0;
		 	end else begin
    		toggle_q <= toggle_d;
				ctr_q <= ctr_d;
			end
  	end
endmodule
