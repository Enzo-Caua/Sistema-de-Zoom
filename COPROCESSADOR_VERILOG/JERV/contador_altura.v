module contador_altura (
   input  wire clock,
   input  wire reset,
   input  wire enable,
   input  wire config_mudou,
   input  wire [9:0] altura_max,
   output reg  [9:0] cont_altura,
   output wire done
);

   assign done = (cont_altura == (altura_max - 1));

   always @(posedge clock) begin
      if (reset || config_mudou) begin
         cont_altura <= 10'd0;
      end else if (enable) begin
         if (cont_altura == (altura_max - 1))
            cont_altura <= 10'd0;
         else
            cont_altura <= cont_altura + 10'd1;
      end
   end
endmodule
