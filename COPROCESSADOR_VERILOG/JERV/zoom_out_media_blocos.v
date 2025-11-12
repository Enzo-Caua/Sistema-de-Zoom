module zoom_out_media_blocos (
   input  wire [9:0] x_out,      // coordenada X na imagem reduzida
   input  wire [9:0] y_out,      // coordenada Y na imagem reduzida
   input  wire [1:0] fator_zoom, // 01=2x, 10=4x
   
   // Coordenadas dos pixels do bloco (até 16 para 4x4)
   output wire [9:0] x0,  y0,  // linha 0
   output wire [9:0] x1,  y1,
   output wire [9:0] x2,  y2,
   output wire [9:0] x3,  y3,
   output wire [9:0] x4,  y4,  // linha 1
   output wire [9:0] x5,  y5,
   output wire [9:0] x6,  y6,
   output wire [9:0] x7,  y7,
   output wire [9:0] x8,  y8,  // linha 2
   output wire [9:0] x9,  y9,
   output wire [9:0] x10, y10,
   output wire [9:0] x11, y11,
   output wire [9:0] x12, y12, // linha 3
   output wire [9:0] x13, y13,
   output wire [9:0] x14, y14,
   output wire [9:0] x15, y15
);

   // Calcula o canto superior esquerdo do bloco
   wire [9:0] x_base, y_base;
    
   // Para 2x: bloco 2x2, para 4x: bloco 4x4
   assign x_base = (fator_zoom == 2'b01) ? (x_out << 1) : (x_out << 2);
   assign y_base = (fator_zoom == 2'b01) ? (y_out << 1) : (y_out << 2);

   // Gera todas as 16 coordenadas (para 2x2 usa apenas as primeiras 4)
   // Linha 0
   assign x0 = x_base;     assign y0 = y_base;
   assign x1 = x_base + 1; assign y1 = y_base;
   assign x2 = x_base + 2; assign y2 = y_base;
   assign x3 = x_base + 3; assign y3 = y_base;
   
   // Linha 1
   assign x4 = x_base;     assign y4 = y_base + 1;
   assign x5 = x_base + 1; assign y5 = y_base + 1;
   assign x6 = x_base + 2; assign y6 = y_base + 1;
   assign x7 = x_base + 3; assign y7 = y_base + 1;
   
   // Linha 2
   assign x8  = x_base;     assign y8  = y_base + 2;
   assign x9  = x_base + 1; assign y9  = y_base + 2;
   assign x10 = x_base + 2; assign y10 = y_base + 2;
   assign x11 = x_base + 3; assign y11 = y_base + 2;
   
   // Linha 3
   assign x12 = x_base;     assign y12 = y_base + 3;
   assign x13 = x_base + 1; assign y13 = y_base + 3;
   assign x14 = x_base + 2; assign y14 = y_base + 3;
   assign x15 = x_base + 3; assign y15 = y_base + 3;

endmodule