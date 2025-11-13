# Sistema de Redimensionamento de Imagens Embarcado

## Sumário

* [Softwares Utilizados](#softwares-utilizados)
* [Hardwares Utilizados](#hardwares-utilizados)
* [Instalação e Configuração do Ambiente](#instalação-e-configuração-do-ambiente)
* [Especificações do Projeto](#especificações-do-projeto)

* [1. Introdução](#1-introdução)
  * [1.1 Requisitos](#11-requisitos)
  * [1.2 Etapas de Desenvolvimento](#12-etapas-de-desenvolvimento)

* [2. Fundamentação Teórica](#2-fundamentação-teórica)
  * [2.1 Arquitetura ARM Cortex-A9 e Assembly LegV7](#21-arquitetura-arm-cortex-a9-e-assembly-legv7)
  * [2.2 Comunicação HPS–FPGA (Ponte Lightweight) e Mapeamento de Memória](#22-comunicacao-hps–fpga-ponte-lightweight-e-mapeamento-de-memoria)
  * [2.3 Formato de Imagem BMP](#23-formato-de-imagem-bmp)
  
* [3. Arquitetura e Implementação](#3-arquitetura-e-implementação)
  * [3.1 Organização da Arquitetura](#31-organização-da-arquitetura)
  * [3.2 Estratégias de Implementação](#32-estratégias-de-implementação)
  * [3.3 Comunicação e Sincronismo HPS-FPGA](#33-comunicação-e-sincronismo-hps-fpga)
  * [3.4 Fluxo de Execução](#34-fluxo-de-execução)

* [4. Testes e Erros](#4-testes-e-erros)
  * [4.1 Teste da Ponte HPS–FPGA com LEDs](#41-teste-da-ponte-hps–fpga-com-leds)
  * [4.2 Teste das Instruções de Zoom com Arquivo .mif](#42-teste-das-instruções-de-zoom-com-arquivo-mif)
  * [4.3 Teste de Leitura e Escrita do Arquivo BMP](#43-teste-de-leitura-e-escrita-do-arquivo-bmp)
  * [4.4 Conclusões dos Testes](#44-conclusões-dos-testes)


* [5. Resultados e Conclusão](#5-resultados-e-conclusão)
  * [5.1 Resultados Obtidos](#51-resultados-obtidos)
  * [5.2 Análise de Desempenho](#52-análise-de-desempenho)
  * [5.3 Conclusão Geral](#53-conclusão-geral)
* [Autores](#autores)

---

## Softwares Utilizados

* **Assembler ARM GNU** – utilizado para montagem e vinculação dos módulos Assembly.
* **Linux embarcado da DE1-SoC** – ambiente de execução do sistema.
* **Quartus Prime Lite 23.1** – utilizado para **síntese**, compilação e programação da FPGA.

## Hardwares Utilizados
- **Kit de Desenvolvimento DE1-SoC** com FPGA Intel Cyclone V (5CSEMA5F31C6) e Processador ARM Cortex-A9 (HPS).  
- **Monitor VGA** com resolução nativa de 640x480 @ 60 Hz.  
- **Computador host** para compilação, programação da FPGA via USB-Blaster II e acesso remoto da DE1-SoC.  
---

## Especificações do Projeto

* **Formato de imagem suportado:** BITMAP 8 bits (256 tons de cinza).
* **Operações disponíveis:** Zoom In e Zoom Out com diferentes algoritmos de interpolação.
* **Comunicação:** Ponte Lightweight HPS-FPGA.
* **Controle:** Via menu textual interativo no terminal Linux.

---

## Instalação e Configuração do Ambiente
1. **Instalar o Quartus Prime Lite 23.1** no computador host.  
2. **Criar um novo projeto no Quartus** selecionando o dispositivo *Cyclone V 5CSEMA5F31C6* (DE1-SoC).  
3. **Adicionar os arquivos Verilog** correspondentes aos módulos do sistema (zoom in, zoom out, controlador, driver VGA, etc.).  
4. **Compilar o projeto** no Quartus e verificar a **ausência** de erros.  
5. **Gerar o arquivo de cabeçalho do sistema**, executando o comando abaixo no diretório do projeto do Quartus:  
*sopc-create-header-files "./soc_system.sopcinfo" --single hps_0.h --module hps_0*
6. **Programar a FPGA** via USB-Blaster II selecionando o arquivo .sof gerado.
7. **Conectar a saída VGA** da placa ao monitor para visualizar os resultados em tempo real.
8. **Conectar-se à DE1-SoC** via SSH a partir do computador host: 
*ssh user@<endereço_ip_da_placa>*
9. **Transferir os arquivos** Assembly, arquivo de cabeçalho do HPS gerado e a imagem BMP para a DE1-SoC utilizando o comando scp:
*scp bmp_JER.s hps_0.h imagem.bmp user@<endereço_ip_da_placa>:/home/user/*
10. **Compilar os arquivos** Assembly diretamente na DE1-SoC:
*as -o bmp_JER.o bmp_JER.s*
*ld -o bmp_JER bmp_JER.o*
11. **Executar o programa** com privilégios de superusuário:
*sudo ./bmp_JER imagem.bmp*

---

# 1. Introdução
O projeto propõe o desenvolvimento de um sistema para redimensionamento de imagens em tempo real. A tarefa envolve ampliar ou reduzir imagens em escala de cinza, mantendo a **eficiência** e a qualidade dentro das limitações do hardware.

## 1.1 Requisitos
- O código da API deve ser escrito em linguagem Assembly;
- O sistema só poderá utilizar os componentes disponíveis na placa;
- Deverão ser implementados na API os comandos da ISA do coprocessador. As instruções devem utilizar as operações que foram anteriormente implementadas via chaves e botões na placa;
- As imagens são representadas em escala de cinza e cada elemento da imagem (pixel) deverá ser representado por um número inteiro de 8 bits.
- A imagem deve ser lida a partir de um arquivo e transferida para o coprocessador;
- O coprocessador deve ser compatível com o processador ARM (Hard Processor System - HPS) para viabilizar o desenvolvimento da solução.

## 1.2 Etapas de Desenvolvimento

O desenvolvimento foi dividido em duas etapas principais:

* **Etapa 1:** Implementação de um coprocessador gráfico em Verilog capaz de realizar operações de zoom em imagens em escala de cinza (8 bits por pixel), controlado por chaves e botões da placa. Disponivel em: [Repositorio da Fase 1](https://github.com/Enzo-Caua/Coprocessador-Grafico).
* **Etapa 2:** Desenvolvimento de uma API em Assembly ARM que realiza a comunicação entre o processador e o coprocessador da Etapa 1, permitindo controle via software.

---

## 2. Fundamentação Teórica

### 2.1 Arquitetura ARM Cortex-A9 e Assembly LegV7

O **ARM Cortex-A9** é um processador baseado na arquitetura **ARMv7-A**, amplamente utilizado em sistemas embarcados de alto desempenho, como o **Hard Processor System (HPS)** presente na placa **DE1-SoC**. Trata-se de uma CPU **RISC (Reduced Instruction Set Computer)**, projetada para oferecer alta eficiência energética e execução rápida de instruções simples.

O processador é **pipelineado**, permitindo que múltiplas instruções sejam processadas simultaneamente em diferentes estágios (busca, decodificação, execução, memória e escrita). Essa característica aumenta o desempenho sem elevar significativamente o consumo de energia.

A arquitetura ARMv7-A utiliza um **conjunto de instruções de 32 bits**, conhecidas como **ARM Assembly (LegV7)**. Essa linguagem fornece controle direto sobre os registradores e sobre o acesso a endereços físicos, o que é essencial para aplicações embarcadas que necessitam de comunicação direta com o hardware.

Alguns exemplos de instruções comumente utilizadas são:
- `MOV`, `ADD`, `SUB` — operações aritméticas e de movimentação de dados;
- `LDR`, `STR` — leitura e escrita em endereços de memória;
- `CMP`, `B`, `BEQ`, `BNE` — comparações e desvios condicionais;
- `SVC #0` — chamada de sistema para executar funções do kernel Linux (como `open`, `read`, `write`, `mmap2` e `close`).

O uso de Assembly no contexto do HPS proporciona **controle preciso sobre os recursos do processador**, facilitando a manipulação direta de registradores e periféricos mapeados em memória. Isso é fundamental para o desenvolvimento de sistemas híbridos, nos quais o processador ARM coordena a execução do hardware programável na FPGA.

---

### 2.2 Comunicação HPS–FPGA (Ponte Lightweight) e Mapeamento de Memória

A comunicação entre o **processador ARM (HPS)** e a **FPGA** ocorre por meio das **pontes HPS-to-FPGA**, que interligam os dois domínios de hardware dentro do SoC.  
Dentre essas, destaca-se a **Lightweight HPS-FPGA Bridge**, utilizada neste projeto por apresentar **baixa latência** e ser ideal para operações de controle e troca de dados simples entre o processador e os periféricos da FPGA.

Essa ponte é mapeada no espaço de endereçamento físico do HPS a partir do endereço base `0xFF200000`. A partir desse ponto, todos os componentes PIO (Parallel Input/Output) conectados à FPGA podem ser acessados como endereços de memória comuns pelo software.

O acesso aos registradores da FPGA é feito via **mapeamento de memória** utilizando a chamada de sistema `mmap2`. Esse recurso permite associar endereços físicos do barramento da FPGA a ponteiros virtuais no espaço de memória do processo em execução no Linux. Assim, é possível escrever e ler dados diretamente nos periféricos da FPGA, sem a necessidade de drivers intermediários.

Esse modelo de comunicação síncrona possibilita a implementação de um **protocolo simples e determinístico**, no qual o HPS envia comandos, aguarda o processamento e recebe o status da FPGA antes de prosseguir.  
A combinação de **Assembly ARM** com **mapeamento direto via ponte Lightweight** garante **tempo de resposta reduzido** e **total controle sobre a sincronização**, fatores essenciais em sistemas embarcados de tempo real.

---

### 2.3 Formato de Imagem BMP

O formato **BMP (Bitmap Image File)** contém informações completas sobre a imagem e seus pixels, organizadas em três seções principais:

1. **File Header (14 bytes):**  
   Contém a assinatura `"BM"`, o tamanho total do arquivo e o deslocamento até o início dos dados de imagem.

2. **Info Header (40 bytes – DIB Header):**  
   Define as propriedades da imagem, incluindo largura, altura, número de planos, profundidade de cor (neste caso, 8 bits) e o método de compressão (normalmente 0 para imagens não comprimidas).

3. **Pixel Data:**  
   Armazena os valores de cor de cada pixel. Em imagens de 8 bits em escala de cinza, cada pixel é representado por um único byte variando de `0` (preto) a `255` (branco).  
   Importante observar que, por padrão, o formato BMP armazena as linhas da imagem **de baixo para cima**, exigindo inversão vertical durante o carregamento ou envio para a FPGA.

No sistema desenvolvido, o HPS lê o arquivo BMP diretamente do sistema de arquivos Linux, valida seus cabeçalhos e carrega os pixels em um buffer de memória.  
Esses dados são então transferidos para a FPGA via ponte Lightweight, onde são processados pelos módulos de hardware responsáveis pelas operações de **Zoom In** e **Zoom Out**.

Essa abordagem permite manipular imagens de forma direta e eficiente, sem compressão e sem a necessidade de decodificação complexa, tornando o BMP ideal para aplicações embarcadas com recursos limitados.

---

# 3. Arquitetura e Implementação

### 3.1 Organização da Arquitetura

A arquitetura do sistema foi projetada para integrar o **processador ARM (HPS)** e o **coprocessador gráfico em FPGA**, de modo que o processamento e o controle ocorram de forma cooperativa.  
O **HPS** atua como a unidade de controle, responsável por interpretar os comandos do usuário, carregar a imagem BMP e enviar instruções de operação à FPGA por meio da **ponte Lightweight**.  
Por sua vez, a **FPGA** realiza o processamento em nível de hardware — executando as operações de zoom, replicação e redução de forma paralela e em tempo real.

A comunicação entre o HPS e a FPGA é feita através de um **registrador PIO de 15 bits**, chamado `PIO_PONTE`, mapeado no espaço de endereçamento físico do HPS.  
Cada palavra de 15 bits enviada por esse registrador representa uma instrução ou um dado, dependendo do modo de operação.  
A definição dos bits é mostrada na tabela a seguir:

| Bits        | Função                                           | Descrição |
|--------------|--------------------------------------------------|------------|
| **[14:7]**   | Dados de pixel (8 bits)                         | Utilizados para escrita dos valores de intensidade (0–255) durante o carregamento da imagem. |
| **[6]**      | Controle de escrita na RAM (`controle_ram`)      | Habilita a escrita de pixels na memória de vídeo da FPGA. |
| **[5:4]**    | Fator de zoom (`zoom`)                           | Define o fator de ampliação ou redução aplicado (2x ou 4x). |
| **[3:0]**    | Algoritmo / Comando (`algoritmo`)                | Seleciona a operação ou o método de interpolação a ser executado. |

Cada combinação específica desses bits define uma **instrução de controle** a ser executada pela FPGA.  
Essas instruções são enviadas em formato binário a partir do HPS, que utiliza o Assembly ARM para escrever diretamente no registrador `PIO_PONTE`.  
A tabela abaixo mostra as instruções implementadas e suas representações binárias de 15 bits:

| Operação | Código Binário (15 bits) | Descrição |
|-----------|--------------------------|------------|
| **Exibe imagem original** | `000000000000000` | Exibe a imagem base armazenada na memória da FPGA. |
| **Escreve na RAM** | `000000001000000` | Ativa o modo de escrita, permitindo a transferência sequencial dos pixels BMP para a memória da FPGA. |
| **Zoom IN NNI 2x** | `000000000010001` | Executa o algoritmo *Nearest Neighbor Interpolation* com fator de ampliação 2x. |
| **Zoom IN NNI 4x** | `000000000100001` | Executa *Nearest Neighbor Interpolation* com fator de ampliação 4x. |
| **Zoom IN Replicação 2x** | `000000000010010` | Realiza ampliação 2x utilizando replicação de pixels. |
| **Zoom IN Replicação 4x** | `000000000100010` | Realiza ampliação 4x utilizando replicação de pixels. |
| **Zoom OUT NNI 2x** | `000000000010100` | Reduz a imagem com decimação (NNI) em fator 2x. |
| **Zoom OUT NNI 4x** | `000000000100100` | Reduz a imagem com decimação (NNI) em fator 4x. |
| **Zoom OUT Média 2x** | `000000000011000` | Reduz a imagem calculando a média de blocos 2x2. |
| **Zoom OUT Média 4x** | `000000000101000` | Reduz a imagem calculando a média de blocos 4x4. |

Durante o funcionamento, o HPS envia o código binário da operação desejada ao registrador `PIO_PONTE`.  
A FPGA decodifica o comando, ajusta os sinais internos de controle (`zoom`, `algoritmo`, `controle_ram`, etc.) e executa a operação correspondente.  
Essa estrutura permite que o mesmo barramento de 15 bits seja utilizado tanto para o **envio de dados de pixel** quanto para o **envio de comandos de operação**, reduzindo a complexidade da interface.

O resultado é uma arquitetura de comunicação **simples, eficiente e síncrona**, na qual o HPS controla o fluxo de processamento e a FPGA executa as operações gráficas em **tempo real**, atualizando a saída VGA de forma imediata.

## 3.2 Estratégias de Implementação

O sistema estabelece comunicação direta entre o **HPS** e a **FPGA** via o **barramento lightweight HPS-to-FPGA**.  
A implementação adota uma **arquitetura modular**, com separação clara das responsabilidades:

- **BMP API** → Responsável por leitura, validação e extração das informações de imagens BMP (8-bit grayscale).  
- **FPGA API** → Implementa o mapeamento de memória e o envio de dados e comandos para o coprocessador gráfico.  
- **UI API** → Gerencia o menu de operações e a interação com o usuário via terminal.  
- **Utilitários** → Conjunto de funções auxiliares para impressão, conversão numérica e temporização (delays).  

Essa estrutura modular favorece **reuso, clareza e manutenção**, permitindo a substituição ou expansão de partes do código sem impacto global. Além disso, o sistema inclui tratamento de erros robusto, garantindo encerramento seguro em falhas de leitura, validação ou mapeamento de memória.

---

## 3.3 Comunicação e Sincronismo HPS–FPGA

A interação entre o processador ARM e a FPGA ocorre por **endereços mapeados em memória** através do `/dev/mem`, utilizando o syscall `mmap2`.  
Dois registradores principais controlam a comunicação:

- **PIO_PONTE_OFFSET (0x00000000)** → envio de dados e comandos para o coprocessador.  
- **PIO_STATUS_OFFSET (0x00000010)** → leitura do estado e sinalização de prontidão.

Durante a transferência de pixels, o sistema insere **delays controlados (~500 ciclos ARM)** para garantir a detecção correta de bordas pela FPGA. Essa técnica compensa a diferença de frequência entre o ARM (~50 MHz) e a lógica da FPGA (~25 MHz), mantendo **sincronismo e integridade dos dados**.

---

## 3.4 Fluxo de Execução

O programa segue um fluxo linear e bem definido:

1. **Inicialização e validação de parâmetros**  
   - Verifica se o nome do arquivo BMP foi informado e exibe o banner do sistema.  

2. **Configuração da interface FPGA**  
   - Abre o dispositivo `/dev/mem` e realiza o mapeamento via `mmap2`.  
   - Calcula e armazena os ponteiros base dos registradores de controle e status.  

3. **Leitura e validação da imagem BMP**  
   - Confirma assinatura “BM” e formato de 8 bits/pixel.  
   - Extrai metadados: largura, altura, offset e total de pixels.  

4. **Transferência de pixels para a FPGA**  
   - Cada pixel é enviado sequencialmente, respeitando o tempo de borda de controle.  
   - Mensagens de status informam o progresso e sucesso da transferência.  

5. **Execução de comandos gráficos**  
   - O usuário escolhe entre exibir a imagem original ou aplicar operações de zoom (NNI, replicação, média).  
   - O comando correspondente é mapeado na tabela `cmd_table` e enviado à FPGA.  

6. **Finalização e limpeza**  
   - Fecha descritores de arquivo e libera a memória mapeada.  
   - Exibe a mensagem de encerramento e retorna ao shell do Linux.

---

# 4. Testes e Erros

A etapa de testes teve como objetivo verificar a **correta comunicação entre o HPS e a FPGA**, além de garantir o funcionamento das operações de leitura, escrita e processamento das imagens BMP.  
Os testes foram realizados em três níveis: comunicação via ponte Lightweight, verificação das instruções de zoom em hardware e validação do fluxo completo no terminal do HPS.

---

## 4.1 Teste da Ponte HPS–FPGA com LEDs

O primeiro teste foi destinado à **validação da comunicação entre o HPS e a FPGA** por meio da **ponte Lightweight**. Para isso, as instruções enviadas pelo processador foram redirecionadas temporariamente para os **LEDs da placa DE1-SoC**, permitindo observar visualmente se os comandos estavam sendo recebidos corretamente pelo hardware.
Cada instrução binária (de 15 bits) era enviada a partir do HPS e, ao ser decodificada na FPGA, ativava um padrão específico de LEDs.  
Esse teste confirmou que:

- Os 15 bits do registrador `PIO_PONTE` estavam sendo mapeados corretamente;  
- As instruções enviadas em Assembly correspondiam exatamente aos valores esperados;  
- O sistema respondia de forma síncrona, sem atraso perceptível entre o envio e a atualização dos LEDs.

Esse método simples de verificação visual foi essencial para validar a camada de comunicação antes da integração completa com os módulos de processamento de imagem.

---

## 4.2 Teste das Instruções de Zoom com Arquivo `.mif`

Após validar a comunicação, foi necessário assegurar que as **instruções de zoom** estivessem sendo interpretadas corretamente pela FPGA.  
Para isso, foram utilizados **arquivos `.mif` (Memory Initialization File)**, que representam imagens de teste em formato binário diretamente carregadas na memória da FPGA.
Esses arquivos permitiram simular diferentes entradas sem depender da leitura do arquivo BMP.  
Durante os testes, o comportamento dos módulos de **Zoom In** e **Zoom Out** foi monitorado no monitor VGA e também via análise da RAM interna.  

Os resultados confirmaram que:

- As instruções enviadas (`Zoom In NNI`, `Replicação`, `Zoom Out NNI` e `Média`) estavam sendo decodificadas corretamente;  
- As transformações aplicadas à imagem correspondiam ao algoritmo selecionado;  
- O fator de zoom (2x ou 4x) era ajustado corretamente conforme os bits `[5:4]` do registrador.

Esse teste garantiu o correto funcionamento dos módulos de interpolação e redução, validando a lógica interna da FPGA.

---

## 4.3 Teste de Leitura e Escrita do Arquivo BMP

O último estágio de testes concentrou-se na **validação do lado de software (HPS)**, responsável por ler o arquivo `.bmp`, interpretar seu cabeçalho e transferir os pixels para a FPGA.  
Esses testes foram realizados diretamente no **terminal do Linux embarcado** da placa DE1-SoC.

Durante a execução, o terminal exibiu mensagens de depuração indicando:

- Abertura bem-sucedida do arquivo BMP;  
- Validação correta da assinatura `"BM"` e da profundidade de cor (8 bits);  
- Escrita sequencial dos pixels na RAM da FPGA;  
- Recebimento das respostas da FPGA após cada operação.

Esses resultados confirmaram que a **API em Assembly ARM** estava realizando corretamente as operações de leitura de arquivo, validação de cabeçalho e transferência de dados.  
Com isso, foi possível observar no monitor VGA as imagens processadas em tempo real, comprovando o funcionamento completo do sistema.

---

## 4.4 Conclusões dos Testes

Os testes realizados em todos os níveis — comunicação, hardware e software — demonstraram a **estabilidade e confiabilidade** da integração HPS-FPGA.  
A ponte Lightweight operou corretamente em todas as instruções, o mapeamento de memória foi validado com sucesso e o fluxo de leitura e escrita do BMP apresentou comportamento consistente.  
Assim, o sistema comprovou a capacidade de realizar **processamento de imagem embarcado em tempo real**, com **controle total via software** e execução eficiente em hardware.

---

# 5. Resultados e Conclusão

## 5.1 Resultados Obtidos

Após a execução dos testes de hardware e software, foi possível validar o funcionamento completo do sistema de **Redimensionamento de Imagens Embarcado**.  
Os resultados observados tanto na saída VGA quanto nos registros de execução do HPS confirmaram o comportamento esperado em todas as etapas.
Durante a operação, as imagens foram corretamente carregadas na **memória da FPGA**, processadas conforme o **algoritmo e fator de zoom** selecionados, e exibidas em **tempo real** no monitor conectado à placa DE1-SoC.  
O tempo de resposta entre o envio da instrução pelo HPS e a atualização da imagem na tela foi praticamente instantâneo, evidenciando a **baixa latência da ponte Lightweight** e a **eficiência da execução em hardware dedicado**.

Entre os principais resultados observados, destacam-se:

- **Comunicação estável e confiável** entre HPS e FPGA por meio da ponte Lightweight;  
- **Execução correta de todos os algoritmos** de ampliação e redução (NNI, Replicação e Média);  
- **Validação precisa dos fatores de zoom (2x e 4x)**, com preservação da integridade da imagem;  
- **Interpretação e escrita adequadas do arquivo BMP**, com leitura fiel do cabeçalho e dos dados de pixel;  
- **Exibição visual coerente** com as transformações aplicadas, sem artefatos ou distorções perceptíveis.

A utilização dos **LEDs** e dos **arquivos `.mif`** foi essencial para o processo de depuração, permitindo identificar rapidamente falhas de comunicação e confirmar o comportamento correto dos módulos de hardware antes da integração final.

---

## 5.2 Análise de Desempenho

O desempenho do sistema mostrou-se consistente com os objetivos do projeto.  
Por se tratar de um **sistema embarcado híbrido**, a divisão de tarefas entre o **HPS (controle e leitura)** e a **FPGA (processamento paralelo)** proporcionou um ganho significativo em relação a implementações puramente em software.
A execução dos algoritmos de zoom diretamente em hardware reduziu a carga de processamento do HPS e permitiu **taxas de atualização em tempo real**, mesmo para imagens completas de 160x120 pixels.  
Além disso, a estrutura modular dos blocos Verilog facilita futuras expansões, como a adição de novos algoritmos ou filtros.
O uso da **ponte Lightweight** demonstrou-se ideal para aplicações que exigem **comandos rápidos e comunicação de baixa largura de banda**, como o controle de periféricos e a sincronização entre processador e coprocessador.

---

## 5.3 Conclusão Geral

O projeto de **Sistema de Redimensionamento de Imagens Embarcado** atingiu com sucesso todos os objetivos propostos, demonstrando a integração eficiente entre o processador ARM e a FPGA presentes na DE1-SoC.  

O sistema foi capaz de:
- Ler e interpretar corretamente imagens no formato BMP;  
- Transferir os pixels para a memória de vídeo da FPGA;  
- Executar diferentes algoritmos de ampliação e redução de imagem em tempo real;  
- Exibir os resultados diretamente na saída VGA, com controle total via software.  

Durante o desenvolvimento, os testes de comunicação, validação de hardware e depuração do código Assembly foram fundamentais para o sucesso da implementação.  
O projeto evidencia a **potência da arquitetura híbrida HPS–FPGA**, combinando a flexibilidade do software com o alto desempenho do hardware reconfigurável.
Em síntese, o sistema desenvolvido demonstra um **exemplo funcional de processamento de imagem embarcado**, capaz de realizar operações complexas de redimensionamento de forma **rápida, confiável e reconfigurável**, sendo uma base sólida para aplicações futuras envolvendo visão computacional e processamento gráfico em tempo real.

---

# Autores

* **Enzo Cauã da S. Barbosa**
* **Jamile Letícia C. da Silva**
* **Rafael Sampaio Firmo**

Tutoria: **Prof. Dr. Ângelo Amâncio Duarte**
