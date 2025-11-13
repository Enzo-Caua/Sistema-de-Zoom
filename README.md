# Sistema de Redimensionamento de Imagens Embarcado

## Sumário

* [Softwares Utilizados](#softwares-utilizados)
* [Hardwares Utilizados](#hardwares-utilizados)
* [Instalação e Configuração do Ambiente](#instalação-e-configuração-do-ambiente)
* [Especificações do Projeto](#especificações-do-projeto)
* [1. Introdução](#1-introdução)

  * [1.1 Estrutura do Projeto](#11-estrutura-do-projeto)
  * [1.2 Objetivos da Etapa 2](#12-objetivos-da-etapa-2)
  * [1.3 Arquitetura da Solução](#13-arquitetura-da-solução)
* [2. Fundamentação Teórica](#2-fundamentação-teórica)

  * [2.1 Sistemas Embarcados e Co-design Hardware/Software](#21-sistemas-embarcados-e-co-design-hardwaresoftware)
  * [2.2 Arquitetura ARM Cortex-A9 e Programação em Assembly](#22-arquitetura-arm-cortex-a9-e-programação-em-assembly)
  * [2.3 Comunicação HPS-FPGA e Mapeamento de Memória](#23-comunicação-hps-fpga-e-mapeamento-de-memória)
  * [2.4 Processamento Digital de Imagens: Operação de Zoom](#24-processamento-digital-de-imagens-operação-de-zoom)
  * [2.5 Formato BMP e Manipulação de Pixels](#25-formato-bmp-e-manipulação-de-pixels)
* [3. Arquitetura e Implementação](#3-arquitetura-e-implementação)

  * [3.1 Organização da Arquitetura](#31-organização-da-arquitetura)
  * [3.2 Estratégias de Implementação](#32-estratégias-de-implementação)
  * [3.3 Comunicação e Sincronismo HPS-FPGA](#33-comunicação-e-sincronismo-hps-fpga)
  * [3.4 Fluxo de Execução](#34-fluxo-de-execução)
* [4. Testes e Erros](#4-testes-e-erros)

  * [4.1 Metodologia de Testes](#41-metodologia-de-testes)
  * [4.2 Critérios de Validação](#42-critérios-de-validação)
  * [4.3 Resultados Obtidos](#43-resultados-obtidos)
  * [4.4 Problemas Encontrados e Soluções](#44-problemas-encontrados-e-soluções)
  * [4.5 Avaliação Final dos Testes](#45-avaliação-final-dos-testes)
* [5. Resultados e Conclusão](#5-resultados-e-conclusão)

  * [5.1 Resultados Obtidos](#51-resultados-obtidos)
  * [5.2 Análise dos Resultados](#52-análise-dos-resultados)
* [6. Manual do Usuário](#6-manual-do-usuário)

  * [6.1 Preparação do Ambiente](#61-preparação-do-ambiente)
  * [6.2 Execução do Programa](#62-execução-do-programa)
  * [6.3 Restrições e Cuidados](#63-restrições-e-cuidados)
* [7. Observações Finais](#7-observações-finais)
* [Autores](#autores)

---

## Softwares Utilizados

* **Assembler ARM GNU (as)** – utilizado para montagem e vinculação dos módulos Assembly.
* **Linux embarcado da DE1-SoC** – ambiente de execução do sistema.
* **Monitor VGA** conectado à FPGA para exibição dos resultados visuais.

## Hardwares Utilizados

* **Placa DE1-SoC** com FPGA Intel Cyclone V (5CSEMA5F31C6).
* **Processador ARM Cortex-A9 (HPS)** para execução do software de controle.
* **Monitor VGA** para exibição das imagens processadas.

---

## Especificações do Projeto

* **Formato de imagem suportado:** BMP 8 bits (256 tons de cinza).
* **Operações disponíveis:** Zoom In e Zoom Out com diferentes algoritmos de interpolação.
* **Comunicação:** Ponte Lightweight HPS-FPGA (end. base 0xFF200000).
* **Controle:** Via menu textual interativo no terminal Linux.

---

# 1. Introdução

### 1.1 Estrutura do Projeto

O desenvolvimento foi dividido em duas etapas principais:

* **Etapa 1:** Implementação de um coprocessador gráfico em Verilog capaz de realizar operações de zoom em imagens em escala de cinza (8 bits por pixel), controlado por chaves e botões da placa.
* **Etapa 2:** Desenvolvimento de uma API em Assembly ARM que realiza a comunicação entre o processador e o coprocessador da Etapa 1, permitindo controle via software.

### 1.2 Objetivos da Etapa 2

O principal objetivo foi estabelecer uma interface de comunicação entre o ARM e o coprocessador, substituindo o controle físico por um controle programável via software.

Objetivos específicos:

* Desenvolver uma API modular em Assembly;
* Implementar a ISA do coprocessador em software;
* Integrar HPS e FPGA via mapeamento de memória;
* Implementar funções para leitura e transferência de imagens BMP;
* Criar uma interface interativa de controle.

### 1.3 Arquitetura da Solução

O sistema integra o **HPS (ARM Cortex-A9)** e a **FPGA**, conectados pela ponte Lightweight. O ARM gerencia a leitura e o controle do sistema, enquanto a FPGA realiza o processamento da imagem em hardware.

---

# 2. Fundamentação Teórica

## 2.1 Sistemas Embarcados e Co-design Hardware/Software

Sistemas embarcados combinam hardware e software dedicados a uma tarefa específica. Na DE1-SoC, o co-design permite dividir funções: o ARM controla o fluxo e a FPGA executa as operações intensivas de dados.

## 2.2 Arquitetura ARM Cortex-A9 e Programação em Assembly

O ARM Cortex-A9 é um processador de 32 bits (ARMv7-A). A linguagem Assembly foi usada para criar uma API de comunicação direta com o hardware, controlando registradores e endereços físicos.

## 2.3 Comunicação HPS-FPGA e Mapeamento de Memória

A ponte Lightweight (0xFF200000) permite comunicação rápida via mapeamento de memória. O Assembly usa `mmap2` para acessar os PIOs:

* **PIO_PONTE (15 bits)** – Envia dados e comandos;
* **PIO_STATUS (1 bit)** – Indica estado de processamento da FPGA.

## 2.4 Processamento Digital de Imagens: Operação de Zoom

O zoom altera a escala da imagem (amplia ou reduz). O coprocessador realiza o processamento, enquanto o Assembly apenas envia comandos e dados.

## 2.5 Formato BMP e Manipulação de Pixels

O formato BMP (8 bits) foi escolhido por ser simples e não comprimido. Cada pixel (0-255) é transferido diretamente pela ponte HPS-FPGA.

---

# 3. Arquitetura e Implementação

## 3.1 Organização da Arquitetura

* **HPS:** Leitura e validação do BMP, menu interativo, envio de comandos.
* **FPGA:** Execução das operações de zoom diretamente em hardware.

## 3.2 Estratégias de Implementação

O sistema foi dividido em três APIs:

* **Gerenciamento de Imagem (BMP):** leitura e validação do BMP.
* **Interface Hardware (FPGA):** mapeamento e comunicação.
* **Interface do Usuário (UI):** menu e seleção de comandos.

## 3.3 Comunicação e Sincronismo HPS-FPGA

O PIO_PONTE (15 bits) transmite pixels e comandos. A sincronização é feita por detecção de bordas, garantindo a transferência segura de cada pixel.

## 3.4 Fluxo de Execução

1. Validação de argumentos.
2. Inicialização da FPGA.
3. Carregamento do BMP.
4. Transferência para FPGA.
5. Menu interativo.
6. Execução de comandos.
7. Limpeza e saída.

---

# 4. Testes e Erros

## 4.1 Metodologia de Testes

Os testes foram realizados no Linux embarcado da DE1-SoC. Cada módulo foi montado e executado manualmente.

## 4.2 Critérios de Validação

Foram avaliados:

* Comunicação HPS-FPGA;
* Integridade dos dados BMP;
* Funcionamento do zoom;
* Estabilidade e tempo de resposta.

## 4.3 Resultados Obtidos

* Transferência correta de pixels.
* Zoom in/out funcionais e proporcionais.
* Processamento em tempo real.
* Sistema estável e responsivo.

## 4.4 Problemas Encontrados e Soluções

* **Endereços incorretos:** corrigidos no mapeamento da ponte.
* **Falta de sincronização:** resolvida com rotina de polling.
* **Ausência de Makefile:** montagem manual para controle total.

## 4.5 Avaliação Final dos Testes

O sistema apresentou comunicação estável, execução imediata e integração completa entre HPS e FPGA.

---

# 5. Resultados e Conclusão

## 5.1 Resultados Obtidos

A comunicação ARM-FPGA foi bem-sucedida, e a API em Assembly executou corretamente leitura, transferência e controle das operações. Zoom in/out apresentaram resultados visuais coerentes e imediatos.

## 5.2 Análise dos Resultados

O sistema comprovou a eficiência da comunicação direta entre software e hardware, com alta responsividade e controle de baixo nível, validando o co-design hardware/software.

---

# 6. Manual do Usuário

## 6.1 Preparação do Ambiente

1. Copiar os módulos `.s` e as imagens BMP para o HPS.
2. Conectar o monitor VGA.
3. Executar com permissão de superusuário:

   ```bash
   as -o bmp_system.o bmp_system.s
   ld -o bmp_system bmp_system.o
   sudo ./bmp_system imagem.bmp
   ```

## 6.2 Execução do Programa

O menu interativo permite escolher entre diferentes operações de zoom e visualizar os resultados em tempo real no monitor VGA.

## 6.3 Restrições e Cuidados

* Somente imagens BMP de 8 bits.
* Executar com `sudo`.
* Monitor VGA conectado antes da execução.
* Não interromper durante a transferência de pixels.

---

# 7. Observações Finais

O sistema foi validado com estabilidade e desempenho consistentes. Apesar da montagem manual, o fluxo de uso é simples e eficaz, com controle direto e feedback imediato via VGA.

---

# Autores

* **Enzo Cauã da S. Barbosa**
* **Jamile Letícia C. da Silva**
* **Rafael Sampaio Firmo**

Tutoria: **Ângelo Amâncio Duarte**
