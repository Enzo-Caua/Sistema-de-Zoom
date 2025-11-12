module contador_largura (
   input  wire clock,
   input  wire reset,
   input  wire enable,
   input  wire config_mudou,
   input  wire [9:0] largura_max,
   output reg  [9:0] cont_largura,
   output wire done
);

   assign done = (cont_largura == (largura_max - 1));

   always @(posedge clock) begin
      if (reset || config_mudou) begin
         cont_largura <= 10'd0;
      end else if (enable) begin
         if (cont_largura == (largura_max - 1))
            cont_largura <= 10'd0;
         else
            cont_largura <= cont_largura + 10'd1;
      end
   end
endmodule