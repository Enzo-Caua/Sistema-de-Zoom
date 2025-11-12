// Mapeia as coordenadas da nova imagem, com base na original
module zoom_out_nni (
   input  wire        reset,
   input  wire [1:0]  fator_zoom,   
   input  wire [9:0]  x_destino,    // coordenada destino
   input  wire [9:0]  y_destino,
   output reg  [9:0]  x_fonte,      // coordenada origem
   output reg  [9:0]  y_fonte
);

   always @* begin
      if (reset) begin
         x_fonte = 0;
         y_fonte = 0;
      end else begin
         case (fator_zoom)
            2'b00: begin   // zoom 1x
               x_fonte = x_destino;
               y_fonte = y_destino;
            end
            2'b01: begin   // zoom 2x
               x_fonte = x_destino << 1;
               y_fonte = y_destino << 1;
            end
            2'b10: begin   // zoom 4x
               x_fonte = x_destino << 2;
               y_fonte = y_destino << 2;
            end
            default: begin // fallback (valor inválido, ex: 11)
               x_fonte = x_destino;
               y_fonte = y_destino;
            end
         endcase
      end
   end

endmodule
