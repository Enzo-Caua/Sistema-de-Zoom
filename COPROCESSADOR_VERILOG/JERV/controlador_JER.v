module controlador_JER (
   input  wire clock,          // 50 MHz
   input  wire reset,
   input  wire [14:0] entrada_dados,
   output wire hsync,
   output wire vsync,
   output wire [7:0] red,
   output wire [7:0] green,
   output wire [7:0] blue,
   output wire sync,
   output wire clk,
   output wire blank,
   output wire pronto           // Sinal de status para o HPS
);

   // ========= PARÂMETROS FIXOS =========
   parameter ORIG_WIDTH  = 160;
   parameter ORIG_HEIGHT = 120;
   parameter VGA_WIDTH   = 640;
   parameter VGA_HEIGHT  = 480;
   
   // ========= DECODIFICADOR DE ENTRADA =========
   wire [3:0] entrada_algoritmo;
   wire [1:0] entrada_zoom;
   wire [7:0] pixel_externo;
   wire       controle_ram;
   
   assign entrada_algoritmo = entrada_dados[3:0];
   assign entrada_zoom = entrada_dados[5:4];
   assign controle_ram = entrada_dados[6];
   assign pixel_externo = entrada_dados[14:7];
   
   // ========= Divisor de Frequência =========
   wire clock_25MHz;
   divisor_freq clk_25MHZ (
      .clk_in(clock),
      .reset(reset),
      .clk_out(clock_25MHz)
   );

   // ========= Detecção de Borda para controle_ram =========
   reg controle_ram_prev;
   wire controle_ram_edge;
   
   always @(posedge clock_25MHz) begin
      if (reset)
         controle_ram_prev <= 1'b0;
      else
         controle_ram_prev <= controle_ram;
   end
   
   // Detecta borda de subida (quando assembly ativa o bit)
   assign controle_ram_edge = controle_ram && !controle_ram_prev;

   // ========= Detecção de Mudança de Configuração =========
   reg [5:0] config_anterior;
   wire config_mudou;
   wire [5:0] config_atual = {entrada_algoritmo, entrada_zoom};
   
   assign config_mudou = (config_atual != config_anterior);
   
   always @(posedge clock_25MHz) begin
      if (reset) begin
         config_anterior <= 6'b000000;
      end else if (!controle_ram) begin  // Só atualiza quando não está em modo escrita
         config_anterior <= config_atual;
      end
   end

   // ========= Contador para Escrita Externa =========
   reg [14:0] contador_escrita_ext;
   reg escrita_em_andamento;
   
   always @(posedge clock_25MHz) begin
      if (reset || config_mudou) begin
         contador_escrita_ext <= 15'd0;
         escrita_em_andamento <= 1'b0;
      end else if (controle_ram_edge) begin
         escrita_em_andamento <= 1'b1;
         if (contador_escrita_ext < (ORIG_WIDTH * ORIG_HEIGHT - 1))
            contador_escrita_ext <= contador_escrita_ext + 15'd1;
         else
            contador_escrita_ext <= 15'd0;
      end else if (!controle_ram && escrita_em_andamento) begin
         escrita_em_andamento <= 1'b0;
      end
   end

   // ========= Estados para Média de Blocos =========
   reg [4:0] estado_media;
   reg [15:0] soma_pixels;
   reg [7:0] pixel_ram_in_delayed;
   reg [7:0] pixel_final;
   
   wire usar_media_2x = (entrada_algoritmo == 4'b1000) && (entrada_zoom == 2'b01);
   wire usar_media_4x = (entrada_algoritmo == 4'b1000) && (entrada_zoom == 2'b10);
   wire usar_media_blocos = usar_media_2x || usar_media_4x;

   // ========= Define largura e altura de acordo com chaves =========
   reg [9:0] largura_imagem, altura_imagem;
   wire [9:0] largura_destino, altura_destino;
   
   always @(posedge clock_25MHz) begin
      if (reset) begin
         largura_imagem <= ORIG_WIDTH;
         altura_imagem  <= ORIG_HEIGHT;
      end else if (!controle_ram) begin  // Só atualiza quando não está escrevendo
         case ({entrada_algoritmo, entrada_zoom})
            6'b000101, 6'b001001: begin
               largura_imagem <= ORIG_WIDTH << 1;
               altura_imagem  <= ORIG_HEIGHT << 1;
            end
            6'b010001, 6'b100001: begin
               largura_imagem <= ORIG_WIDTH >> 1;
               altura_imagem  <= ORIG_HEIGHT >> 1;
            end
            6'b000110, 6'b001010: begin
               largura_imagem <= ORIG_WIDTH << 2;
               altura_imagem  <= ORIG_HEIGHT << 2;
            end
            6'b010010, 6'b100010: begin
               largura_imagem <= ORIG_WIDTH >> 2;
               altura_imagem  <= ORIG_HEIGHT >> 2;
            end
            default: begin
               largura_imagem <= ORIG_WIDTH;
               altura_imagem  <= ORIG_HEIGHT;
            end
         endcase
      end
   end
   
   assign largura_destino = (largura_imagem > VGA_WIDTH) ? VGA_WIDTH : largura_imagem;
   assign altura_destino = (altura_imagem > VGA_HEIGHT) ? VGA_HEIGHT : altura_imagem;

   // ========= Contadores para Preenchimento RAM =========
   wire [9:0] cont_x_wire, cont_y_wire;
   wire done_x, done_y;
   wire enable_contador;
   wire pixel_pronto;
   
   assign pixel_pronto = usar_media_blocos ? (estado_media == 5'd0) : 1'b1;
   assign enable_contador = usar_media_blocos ? pixel_pronto : 1'b1;

   contador_largura cont_larg (
      .clock(clock_25MHz),
      .reset(reset),
      .enable(enable_contador && !controle_ram),
      .config_mudou(config_mudou),
      .largura_max(largura_destino),
      .cont_largura(cont_x_wire),
      .done(done_x)
   );

   contador_altura cont_alt (
      .clock(clock_25MHz),
      .reset(reset),
      .enable(done_x && enable_contador && !controle_ram),
      .config_mudou(config_mudou),
      .altura_max(altura_destino),
      .cont_altura(cont_y_wire),
      .done(done_y)
   );

   // ========= Registradores de coordenadas processadas =========
   reg [9:0] x_proc, y_proc;
   always @(posedge clock_25MHz) begin
      if (reset || config_mudou) begin
         x_proc <= 0;
         y_proc <= 0;
      end else if (!controle_ram) begin
         x_proc <= cont_x_wire;
         y_proc <= cont_y_wire;
      end
   end

   // ========= Estado: 0 = Preenchimento RAM, 1 = Exibição VGA =========
   reg modo_vga;
   reg processamento_completo;
   
   always @(posedge clock_25MHz) begin
      if (reset || config_mudou) begin
         modo_vga <= 0;
         processamento_completo <= 0;
      end else if (controle_ram) begin
         // Durante escrita externa, volta ao modo de preenchimento
         modo_vga <= 0;
         processamento_completo <= 0;
      end else if (!processamento_completo && 
                   x_proc == (largura_destino - 1) && 
                   y_proc == (altura_destino - 1)) begin
         modo_vga <= 1;
         processamento_completo <= 1;
      end
   end
   
   // Sinal de status: pronto quando está em modo VGA e processamento completo
   assign pronto = modo_vga && processamento_completo;

   // ========= Seletor de Algoritmo =========
   wire [9:0] x_dest, y_dest;
   wire [9:0] x_fonte0, y_fonte0, x_fonte1, y_fonte1, x_fonte2, y_fonte2, x_fonte3, y_fonte3;
   wire [9:0] x_fonte4, y_fonte4, x_fonte5, y_fonte5, x_fonte6, y_fonte6, x_fonte7, y_fonte7;
   wire [9:0] x_fonte8, y_fonte8, x_fonte9, y_fonte9, x_fonte10, y_fonte10, x_fonte11, y_fonte11;
   wire [9:0] x_fonte12, y_fonte12, x_fonte13, y_fonte13, x_fonte14, y_fonte14, x_fonte15, y_fonte15;
   
   assign x_dest = modo_vga ? x_proc : cont_x_wire;
   assign y_dest = modo_vga ? y_proc : cont_y_wire;

   seletor_algoritmo seletor (
      .reset(reset),
      .entrada_algoritmo(entrada_algoritmo),
      .entrada_zoom(entrada_zoom),
      .x_destino(x_dest),
      .y_destino(y_dest),
      .x_fonte0(x_fonte0), .y_fonte0(y_fonte0),
      .x_fonte1(x_fonte1), .y_fonte1(y_fonte1),
      .x_fonte2(x_fonte2), .y_fonte2(y_fonte2),
      .x_fonte3(x_fonte3), .y_fonte3(y_fonte3),
      .x_fonte4(x_fonte4), .y_fonte4(y_fonte4),
      .x_fonte5(x_fonte5), .y_fonte5(y_fonte5),
      .x_fonte6(x_fonte6), .y_fonte6(y_fonte6),
      .x_fonte7(x_fonte7), .y_fonte7(y_fonte7),
      .x_fonte8(x_fonte8), .y_fonte8(y_fonte8),
      .x_fonte9(x_fonte9), .y_fonte9(y_fonte9),
      .x_fonte10(x_fonte10), .y_fonte10(y_fonte10),
      .x_fonte11(x_fonte11), .y_fonte11(y_fonte11),
      .x_fonte12(x_fonte12), .y_fonte12(y_fonte12),
      .x_fonte13(x_fonte13), .y_fonte13(y_fonte13),
      .x_fonte14(x_fonte14), .y_fonte14(y_fonte14),
      .x_fonte15(x_fonte15), .y_fonte15(y_fonte15)
   );

   // ========= Multiplexador de Coordenadas para ram_in =========
   wire [9:0] x_ram_in_select, y_ram_in_select;
   reg [9:0] x_atual, y_atual;
   
   always @(*) begin
      if (usar_media_4x) begin
         case (estado_media)
            5'd1:  begin x_atual = x_fonte0;  y_atual = y_fonte0;  end
            5'd2:  begin x_atual = x_fonte1;  y_atual = y_fonte1;  end
            5'd3:  begin x_atual = x_fonte2;  y_atual = y_fonte2;  end
            5'd4:  begin x_atual = x_fonte3;  y_atual = y_fonte3;  end
            5'd5:  begin x_atual = x_fonte4;  y_atual = y_fonte4;  end
            5'd6:  begin x_atual = x_fonte5;  y_atual = y_fonte5;  end
            5'd7:  begin x_atual = x_fonte6;  y_atual = y_fonte6;  end
            5'd8:  begin x_atual = x_fonte7;  y_atual = y_fonte7;  end
            5'd9:  begin x_atual = x_fonte8;  y_atual = y_fonte8;  end
            5'd10: begin x_atual = x_fonte9;  y_atual = y_fonte9;  end
            5'd11: begin x_atual = x_fonte10; y_atual = y_fonte10; end
            5'd12: begin x_atual = x_fonte11; y_atual = y_fonte11; end
            5'd13: begin x_atual = x_fonte12; y_atual = y_fonte12; end
            5'd14: begin x_atual = x_fonte13; y_atual = y_fonte13; end
            5'd15: begin x_atual = x_fonte14; y_atual = y_fonte14; end
            5'd16: begin x_atual = x_fonte15; y_atual = y_fonte15; end
            default: begin x_atual = x_fonte0; y_atual = y_fonte0; end
         endcase
      end else if (usar_media_2x) begin
         case (estado_media)
            5'd1: begin x_atual = x_fonte0; y_atual = y_fonte0; end
            5'd2: begin x_atual = x_fonte1; y_atual = y_fonte1; end
            5'd3: begin x_atual = x_fonte4; y_atual = y_fonte4; end
            5'd4: begin x_atual = x_fonte5; y_atual = y_fonte5; end
            default: begin x_atual = x_fonte0; y_atual = y_fonte0; end
         endcase
      end else begin
         x_atual = x_fonte0;
         y_atual = y_fonte0;
      end
   end
   
   assign x_ram_in_select = usar_media_blocos ? x_atual : x_fonte0;
   assign y_ram_in_select = usar_media_blocos ? y_atual : y_fonte0;

   // ========= Validação de Coordenadas =========
   wire [9:0] x_fonte_valido, y_fonte_valido;
   assign x_fonte_valido = (x_ram_in_select < ORIG_WIDTH) ? x_ram_in_select : (ORIG_WIDTH - 1);
   assign y_fonte_valido = (y_ram_in_select < ORIG_HEIGHT) ? y_ram_in_select : (ORIG_HEIGHT - 1);

   // ========= Endereço ram_in =========
   reg [14:0] endereco_ram_in;
   reg wren_ram_in;
   
   always @(posedge clock_25MHz) begin
      if (reset) begin
         endereco_ram_in <= 0;
         wren_ram_in <= 0;
      end else if (controle_ram_edge) begin
         // Escrita externa: usa contador sequencial
         endereco_ram_in <= contador_escrita_ext;
         wren_ram_in <= 1;
      end else if (controle_ram) begin
         // Mantém write enable durante o pulso
         wren_ram_in <= 0;  // Write é registrado na borda
      end else begin
         // Leitura normal: usa coordenadas calculadas
         endereco_ram_in <= y_fonte_valido * ORIG_WIDTH + x_fonte_valido;
         wren_ram_in <= 0;
      end
   end

   wire [7:0] pixel_ram_in;
   ram_in ram_in_inst (
      .clock(clock_25MHz),
      .address(endereco_ram_in),
      .data(pixel_externo),
      .wren(wren_ram_in),
      .q(pixel_ram_in)
   );

   // ========= Máquina de Estados para Média de Blocos =========
   always @(posedge clock_25MHz) begin
      if (reset || config_mudou) begin
         estado_media <= 5'd0;
         soma_pixels <= 16'd0;
      end else if (!modo_vga && usar_media_blocos && !controle_ram) begin
         if (usar_media_4x) begin
            case (estado_media)
               5'd0: begin
                  if ((y_proc < altura_destino) && (x_proc < largura_destino)) begin
                     estado_media <= 5'd1;
                     soma_pixels <= 16'd0;
                  end
               end
               5'd1: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd2;
               end
               5'd2: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd3;
               end
               5'd3: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd4;
               end
               5'd4: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd5;
               end
               5'd5: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd6;
               end
               5'd6: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd7;
               end
               5'd7: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd8;
               end
               5'd8: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd9;
               end
               5'd9: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd10;
               end
               5'd10: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd11;
               end
               5'd11: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd12;
               end
               5'd12: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd13;
               end
               5'd13: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd14;
               end
               5'd14: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd15;
               end
               5'd15: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd16;
               end
               5'd16: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd0;
               end
               default: estado_media <= 5'd0;
            endcase
         end else if (usar_media_2x) begin
            case (estado_media)
               5'd0: begin
                  if ((y_proc < altura_destino) && (x_proc < largura_destino)) begin
                     estado_media <= 5'd1;
                     soma_pixels <= 16'd0;
                  end
               end
               5'd1: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd2;
               end
               5'd2: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd3;
               end
               5'd3: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd4;
               end
               5'd4: begin
                  soma_pixels <= soma_pixels + {8'b00000000, pixel_ram_in_delayed};
                  estado_media <= 5'd0;
               end
               default: estado_media <= 5'd0;
            endcase
         end
      end else if (!usar_media_blocos) begin
         estado_media <= 5'd0;
         soma_pixels <= 16'd0;
      end
   end

   // ========= Pipeline para ram_in e Cálculo de Média =========
   wire [7:0] pixel_media_calculado;
   wire [15:0] soma_com_arredondamento;
   
   assign soma_com_arredondamento = usar_media_4x ? (soma_pixels + 16'd8) : (soma_pixels + 16'd2);
   assign pixel_media_calculado = usar_media_4x ? soma_com_arredondamento[15:4] : soma_com_arredondamento[9:2];
   
   always @(posedge clock_25MHz) begin
      if (reset) begin
         pixel_ram_in_delayed <= 0;
         pixel_final <= 0;
      end else begin
         pixel_ram_in_delayed <= pixel_ram_in;
         
         if (usar_media_4x && estado_media == 5'd16) begin
            pixel_final <= pixel_media_calculado;
         end else if (usar_media_2x && estado_media == 5'd4) begin
            pixel_final <= pixel_media_calculado;
         end else if (!usar_media_blocos) begin
            pixel_final <= pixel_ram_in_delayed;
         end
      end
   end

   // ========= RAM com Pipeline =========
   reg [18:0] endereco_RAM_wr;
   reg [7:0] pixel_RAM_wr;
   reg wren;
   wire [7:0] pixel_RAM_rd;
   reg [18:0] endereco_RAM_rd;

   ram1p RAM_inst (
      .address(wren ? endereco_RAM_wr : endereco_RAM_rd),
      .clock(clock_25MHz),
      .data(pixel_RAM_wr),
      .wren(wren),
      .q(pixel_RAM_rd)
   );

   // ========= Escrita na RAM =========
   always @(posedge clock_25MHz) begin
      if (reset || config_mudou) begin
         endereco_RAM_wr <= 0;
         pixel_RAM_wr    <= 0;
         wren            <= 0;
      end else if (!modo_vga && !controle_ram) begin
         if ((y_proc < altura_destino) && (x_proc < largura_destino)) begin
            if (usar_media_4x) begin
               if (estado_media == 5'd16) begin
                  pixel_RAM_wr    <= pixel_final;
                  endereco_RAM_wr <= y_proc * largura_destino + x_proc;
                  wren            <= 1;
               end else begin
                  wren <= 0;
               end
            end else if (usar_media_2x) begin
               if (estado_media == 5'd4) begin
                  pixel_RAM_wr    <= pixel_final;
                  endereco_RAM_wr <= y_proc * largura_destino + x_proc;
                  wren            <= 1;
               end else begin
                  wren <= 0;
               end
            end else begin
               pixel_RAM_wr    <= pixel_final;
               endereco_RAM_wr <= y_proc * largura_destino + x_proc;
               wren            <= 1;
            end
         end else begin
            wren <= 0;
         end
      end else begin
         wren <= 0;
      end
   end

   // ========= Leitura RAM → VGA =========
   reg [9:0] vga_x, vga_y;
   wire [9:0] prox_x, prox_y;
   reg [7:0] pixel_vga;
   reg [7:0] pixel_vga_delayed;

   always @(posedge clock_25MHz) begin
      if (reset) begin
         pixel_vga_delayed <= 0;
      end else begin
         pixel_vga_delayed <= pixel_RAM_rd;
      end
   end

   always @(posedge clock_25MHz) begin
      if (reset || config_mudou) begin
         vga_x <= 0;
         vga_y <= 0;
         endereco_RAM_rd <= 0;
         pixel_vga <= 0;
      end else if (modo_vga) begin
         vga_x <= prox_x;
         vga_y <= prox_y;

         if ((prox_x < largura_destino) && (prox_y < altura_destino)) begin
            endereco_RAM_rd <= prox_y * largura_destino + prox_x;
            pixel_vga <= pixel_vga_delayed;
         end else begin
            endereco_RAM_rd <= 0;
            pixel_vga <= 8'b00000000;
         end
      end else begin
         vga_x <= 0;
         vga_y <= 0;
         endereco_RAM_rd <= 0;
         pixel_vga <= 0;
      end
   end

   // ========= Driver VGA =========
   vga_driver ctrl_VGA (
      .clock(clock_25MHz),
      .reset(reset),
      .color_in(pixel_vga),
      .next_x(prox_x),
      .next_y(prox_y),
      .hsync(hsync),
      .vsync(vsync),
      .red(red),
      .green(green),
      .blue(blue),
      .sync(sync),
      .clk(clk),
      .blank(blank)
   );

endmodule