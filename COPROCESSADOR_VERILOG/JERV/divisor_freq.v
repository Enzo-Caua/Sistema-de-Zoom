module divisor_freq (
   input  wire clk_in,
   input  wire reset,
   output reg clk_out
);

   always @(posedge clk_in or posedge reset) begin
      if (reset)
         clk_out <= 1'b0;
      else
         clk_out <= ~clk_out;
   end
	
endmodule