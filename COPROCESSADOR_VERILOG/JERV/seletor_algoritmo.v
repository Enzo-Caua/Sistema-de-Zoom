module seletor_algoritmo (
   input  wire        reset,
   input  wire [3:0]  entrada_algoritmo,   // seletor de algoritmo
   input  wire [1:0]  entrada_zoom,  // 00=1x, 01=2x, 10=4x
   input  wire [9:0]  x_destino,   // coordenada X destino
   input  wire [9:0]  y_destino,   // coordenada Y destino

   output reg  [9:0]  x_fonte0, y_fonte0,   // p0
   output reg  [9:0]  x_fonte1, y_fonte1,   // p1
   output reg  [9:0]  x_fonte2, y_fonte2,   // p2
   output reg  [9:0]  x_fonte3, y_fonte3,   // p3
   output reg  [9:0]  x_fonte4, y_fonte4,   // p4
   output reg  [9:0]  x_fonte5, y_fonte5,   // p5
   output reg  [9:0]  x_fonte6, y_fonte6,   // p6
   output reg  [9:0]  x_fonte7, y_fonte7,   // p7
   output reg  [9:0]  x_fonte8, y_fonte8,   // p8
   output reg  [9:0]  x_fonte9, y_fonte9,   // p9
   output reg  [9:0]  x_fonte10, y_fonte10, // p10
   output reg  [9:0]  x_fonte11, y_fonte11, // p11
   output reg  [9:0]  x_fonte12, y_fonte12, // p12
   output reg  [9:0]  x_fonte13, y_fonte13, // p13
   output reg  [9:0]  x_fonte14, y_fonte14, // p14
   output reg  [9:0]  x_fonte15, y_fonte15  // p15
);

   // Fios internos para cada algoritmo
   wire [9:0] x_nni_zin,  y_nni_zin;
   wire [9:0] x_nni_zout, y_nni_zout;
   wire [9:0] x_rep,      y_rep;

   // Coordenadas da média de blocos (16 pixels)
   wire [9:0] x0_med, y0_med, x1_med, y1_med, x2_med, y2_med, x3_med, y3_med;
   wire [9:0] x4_med, y4_med, x5_med, y5_med, x6_med, y6_med, x7_med, y7_med;
   wire [9:0] x8_med, y8_med, x9_med, y9_med, x10_med, y10_med, x11_med, y11_med;
   wire [9:0] x12_med, y12_med, x13_med, y13_med, x14_med, y14_med, x15_med, y15_med;

   // ++++++++++++++++ //
   //      ZOOM IN     //
   // ++++++++++++++++ //

   // Nearest Neighbor Zoom In
   zoom_in_nni nni_zin (
      .reset(reset),
		.x_destino(x_destino),
      .y_destino(y_destino),
      .x_fonte(x_nni_zin),
      .y_fonte(y_nni_zin),
      .fator_zoom(entrada_zoom)
   );

   // Pixel Replication
   zoom_in_pixel_rep pixel_rep_zin (
      .reset(reset),
      .x_destino(x_destino),
      .y_destino(y_destino),
      .x_fonte(x_rep),
      .y_fonte(y_rep),
      .fator_zoom(entrada_zoom)
   );

   // ++++++++++++++++ //
   //      ZOOM OUT    //
   // ++++++++++++++++ //

   // Nearest Neighbor Zoom Out
   zoom_out_nni nni_zout (
      .reset(reset),
      .x_destino(x_destino),
      .y_destino(y_destino),
      .x_fonte(x_nni_zout),
      .y_fonte(y_nni_zout),
      .fator_zoom(entrada_zoom)
   );

   // Média de Blocos (2x2 e 4x4)
   zoom_out_media_blocos media_zout (
      .x_out(x_destino),
      .y_out(y_destino),
      .fator_zoom(entrada_zoom),
      .x0(x0_med), .y0(y0_med), .x1(x1_med), .y1(y1_med),
      .x2(x2_med), .y2(y2_med), .x3(x3_med), .y3(y3_med),
      .x4(x4_med), .y4(y4_med), .x5(x5_med), .y5(y5_med),
      .x6(x6_med), .y6(y6_med), .x7(x7_med), .y7(y7_med),
      .x8(x8_med), .y8(y8_med), .x9(x9_med), .y9(y9_med),
      .x10(x10_med), .y10(y10_med), .x11(x11_med), .y11(y11_med),
      .x12(x12_med), .y12(y12_med), .x13(x13_med), .y13(y13_med),
      .x14(x14_med), .y14(y14_med), .x15(x15_med), .y15(y15_med)
   );

   // ++++++++++++++++ //
   //   SELETOR FINAL  //
   // ++++++++++++++++ //

   always @* begin
      if (reset) begin
         x_fonte0 = 0; y_fonte0 = 0;   x_fonte1 = 0; y_fonte1 = 0;
         x_fonte2 = 0; y_fonte2 = 0;   x_fonte3 = 0; y_fonte3 = 0;
         x_fonte4 = 0; y_fonte4 = 0;   x_fonte5 = 0; y_fonte5 = 0;
         x_fonte6 = 0; y_fonte6 = 0;   x_fonte7 = 0; y_fonte7 = 0;
         x_fonte8 = 0; y_fonte8 = 0;   x_fonte9 = 0; y_fonte9 = 0;
         x_fonte10 = 0; y_fonte10 = 0; x_fonte11 = 0; y_fonte11 = 0;
         x_fonte12 = 0; y_fonte12 = 0; x_fonte13 = 0; y_fonte13 = 0;
         x_fonte14 = 0; y_fonte14 = 0; x_fonte15 = 0; y_fonte15 = 0;
      end else begin
         case (entrada_algoritmo)
            4'b0001: begin // Zoom In - Nearest Neighbor
               x_fonte0 = x_nni_zin;  y_fonte0 = y_nni_zin;
               // Zera as demais coordenadas
               x_fonte1 = 0; y_fonte1 = 0; x_fonte2 = 0; y_fonte2 = 0; x_fonte3 = 0; y_fonte3 = 0;
               x_fonte4 = 0; y_fonte4 = 0; x_fonte5 = 0; y_fonte5 = 0; x_fonte6 = 0; y_fonte6 = 0; x_fonte7 = 0; y_fonte7 = 0;
               x_fonte8 = 0; y_fonte8 = 0; x_fonte9 = 0; y_fonte9 = 0; x_fonte10 = 0; y_fonte10 = 0; x_fonte11 = 0; y_fonte11 = 0;
               x_fonte12 = 0; y_fonte12 = 0; x_fonte13 = 0; y_fonte13 = 0; x_fonte14 = 0; y_fonte14 = 0; x_fonte15 = 0; y_fonte15 = 0;
            end

            4'b0010: begin // Zoom In - Pixel Replication
               x_fonte0 = x_rep;  y_fonte0 = y_rep;
               // Zera as demais
               x_fonte1 = 0; y_fonte1 = 0; x_fonte2 = 0; y_fonte2 = 0; x_fonte3 = 0; y_fonte3 = 0;
               x_fonte4 = 0; y_fonte4 = 0; x_fonte5 = 0; y_fonte5 = 0; x_fonte6 = 0; y_fonte6 = 0; x_fonte7 = 0; y_fonte7 = 0;
               x_fonte8 = 0; y_fonte8 = 0; x_fonte9 = 0; y_fonte9 = 0; x_fonte10 = 0; y_fonte10 = 0; x_fonte11 = 0; y_fonte11 = 0;
               x_fonte12 = 0; y_fonte12 = 0; x_fonte13 = 0; y_fonte13 = 0; x_fonte14 = 0; y_fonte14 = 0; x_fonte15 = 0; y_fonte15 = 0;
            end

            4'b0100: begin // Zoom Out - Nearest Neighbor
               x_fonte0 = x_nni_zout;  y_fonte0 = y_nni_zout;
               // Zera as demais
               x_fonte1 = 0; y_fonte1 = 0; x_fonte2 = 0; y_fonte2 = 0; x_fonte3 = 0; y_fonte3 = 0;
               x_fonte4 = 0; y_fonte4 = 0; x_fonte5 = 0; y_fonte5 = 0; x_fonte6 = 0; y_fonte6 = 0; x_fonte7 = 0; y_fonte7 = 0;
               x_fonte8 = 0; y_fonte8 = 0; x_fonte9 = 0; y_fonte9 = 0; x_fonte10 = 0; y_fonte10 = 0; x_fonte11 = 0; y_fonte11 = 0;
               x_fonte12 = 0; y_fonte12 = 0; x_fonte13 = 0; y_fonte13 = 0; x_fonte14 = 0; y_fonte14 = 0; x_fonte15 = 0; y_fonte15 = 0;
            end

            4'b1000: begin // Zoom Out - Média de Blocos
               // Conecta todas as 16 coordenadas
               x_fonte0 = x0_med;   y_fonte0 = y0_med;
               x_fonte1 = x1_med;   y_fonte1 = y1_med;
               x_fonte2 = x2_med;   y_fonte2 = y2_med;
               x_fonte3 = x3_med;   y_fonte3 = y3_med;
               x_fonte4 = x4_med;   y_fonte4 = y4_med;
               x_fonte5 = x5_med;   y_fonte5 = y5_med;
               x_fonte6 = x6_med;   y_fonte6 = y6_med;
               x_fonte7 = x7_med;   y_fonte7 = y7_med;
               x_fonte8 = x8_med;   y_fonte8 = y8_med;
               x_fonte9 = x9_med;   y_fonte9 = y9_med;
               x_fonte10 = x10_med; y_fonte10 = y10_med;
               x_fonte11 = x11_med; y_fonte11 = y11_med;
               x_fonte12 = x12_med; y_fonte12 = y12_med;
               x_fonte13 = x13_med; y_fonte13 = y13_med;
               x_fonte14 = x14_med; y_fonte14 = y14_med;
               x_fonte15 = x15_med; y_fonte15 = y15_med;
            end

            default: begin // fallback
               x_fonte0 = x_destino;  y_fonte0 = y_destino;
               x_fonte1 = 0; y_fonte1 = 0; x_fonte2 = 0; y_fonte2 = 0; x_fonte3 = 0; y_fonte3 = 0;
               x_fonte4 = 0; y_fonte4 = 0; x_fonte5 = 0; y_fonte5 = 0; x_fonte6 = 0; y_fonte6 = 0; x_fonte7 = 0; y_fonte7 = 0;
               x_fonte8 = 0; y_fonte8 = 0; x_fonte9 = 0; y_fonte9 = 0; x_fonte10 = 0; y_fonte10 = 0; x_fonte11 = 0; y_fonte11 = 0;
               x_fonte12 = 0; y_fonte12 = 0; x_fonte13 = 0; y_fonte13 = 0; x_fonte14 = 0; y_fonte14 = 0; x_fonte15 = 0; y_fonte15 = 0;
            end
         endcase
      end
   end

endmodule