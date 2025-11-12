@ ============================================================================
@ API MODULAR PARA SISTEMA BMP + COPROCESSADOR GRÁFICO
@ Plataforma: DE1-SoC (Cyclone V SoC - ARM Cortex-A9)
@ VERSÃO CORRIGIDA - Bugs de mmap2 e transferência resolvidos
@ ============================================================================

@ ===========================
@ CONFIGURAÇÕES E CONSTANTES
@ ===========================

@ Endereços base do hardware (lightweight HPS-to-FPGA bridge)
.equ HPS_LW_BASE,       0xFF200000
.equ PIO_PONTE_OFFSET,  0x00000000
.equ PIO_STATUS_OFFSET, 0x00000010

@ Comandos do coprocessador (15 bits)
.equ CMD_ORIGINAL,          0x0000
.equ CMD_WRITE_RAM,         0x0040
.equ CMD_ZOOM_IN_NNI_2X,    0x0011
.equ CMD_ZOOM_IN_NNI_4X,    0x0021
.equ CMD_ZOOM_IN_REP_2X,    0x0012
.equ CMD_ZOOM_IN_REP_4X,    0x0022
.equ CMD_ZOOM_OUT_NNI_2X,   0x0014
.equ CMD_ZOOM_OUT_NNI_4X,   0x0024
.equ CMD_ZOOM_OUT_AVG_2X,   0x0018
.equ CMD_ZOOM_OUT_AVG_4X,   0x0028

@ Syscalls Linux ARM
.equ SYS_EXIT,      1
.equ SYS_READ,      3
.equ SYS_WRITE,     4
.equ SYS_OPEN,      5
.equ SYS_CLOSE,     6
.equ SYS_LSEEK,     19
.equ SYS_MMAP2,     192

@ Flags para open
.equ O_RDONLY,      0x0000
.equ O_RDWR,        0x0002
.equ O_SYNC,        0x101000

@ Flags para mmap2
.equ PROT_READ,     0x1
.equ PROT_WRITE,    0x2
.equ MAP_SHARED,    0x1
.equ MAP_FAILED,    0xFFFFFFFF

@ Estrutura image_info (offsets)
.equ INFO_WIDTH,        0
.equ INFO_HEIGHT,       4
.equ INFO_BPP,          8
.equ INFO_DATA_OFFSET,  12
.equ INFO_TOTAL_PIXELS, 16

@ Constantes BMP
.equ BMP_SIGNATURE,     0x4D42
.equ BMP_HEADER_SIZE,   54
.equ BMP_PALETTE_SIZE,  1024

@ ===========================
@ SEÇÃO DE DADOS
@ ===========================

.data
    .align 4
    
    @ Main
    banner:         .asciz "\n========================================\n"
    banner2:        .asciz "  Sistema de Processamento de Imagem  \n"
    banner3:        .asciz "  DE1-SoC + Coprocessador Grafico     \n"
    banner4:        .asciz "========================================\n\n"
    usage_msg:      .asciz "Uso: ./bmp_system <arquivo.bmp>\n"
    exit_msg:       .asciz "\nEncerrando sistema. Ate logo!\n"
    
    @ BMP API
    bmp_err_open:       .asciz "Erro: Nao foi possivel abrir arquivo BMP\n"
    bmp_err_read:       .asciz "Erro: Falha ao ler arquivo BMP\n"
    bmp_err_invalid:    .asciz "Erro: Arquivo BMP invalido (deve ser 8-bit grayscale)\n"
    bmp_info_fmt:       .asciz "Imagem: "
    bmp_info_x:         .asciz "x"
    bmp_info_px:        .asciz " pixels, "
    bmp_info_bpp:       .asciz " bits/pixel\n"
    bmp_loading:        .asciz "Carregando imagem BMP...\n"
    bmp_success:        .asciz "Imagem carregada com sucesso!\n"
    
    @ FPGA API
    fpga_init_msg:      .asciz "Inicializando interface FPGA...\n"
    fpga_init_ok:       .asciz "Interface FPGA inicializada.\n"
    fpga_init_err:      .asciz "Erro: Falha ao mapear memoria FPGA\n"
    fpga_err_devmem:    .asciz "Erro: Nao foi possivel abrir /dev/mem (execute como root)\n"
    fpga_transfer_msg:  .asciz "Transferindo imagem para FPGA...\n"
    fpga_transfer_ok:   .asciz "Transferencia concluida!\n"
    fpga_cmd_msg:       .asciz "Enviando comando para FPGA...\n"
    fpga_cmd_ok:        .asciz "Comando executado.\n"
    fpga_debug_pixels:  .asciz "Pixels transferidos: \n"
    
    @ UI API
    menu_header:    .asciz "\n======= MENU DE OPERACOES =======\n"
    menu_opt0:      .asciz "0 - Exibir imagem original\n"
    menu_opt1:      .asciz "1 - Zoom IN NNI 2x\n"
    menu_opt2:      .asciz "2 - Zoom IN NNI 4x\n"
    menu_opt3:      .asciz "3 - Zoom IN Replicacao 2x\n"
    menu_opt4:      .asciz "4 - Zoom IN Replicacao 4x\n"
    menu_opt5:      .asciz "5 - Zoom OUT NNI 2x\n"
    menu_opt6:      .asciz "6 - Zoom OUT NNI 4x\n"
    menu_opt7:      .asciz "7 - Zoom OUT Media 2x\n"
    menu_opt8:      .asciz "8 - Zoom OUT Media 4x\n"
    menu_opt9:      .asciz "9 - Sair\n"
    menu_prompt:    .asciz "\nEscolha: "
    menu_invalid:   .asciz "Opcao invalida!\n"
    
    devmem_path:    .asciz "/dev/mem"
    newline:        .asciz "\n"
    
    .align 4
    o_rdwr_sync_val: .word 0x00101002
    bmp_full_hdr:    .word 1078
    
    .align 4
    cmd_table:
        .word CMD_ORIGINAL
        .word CMD_ZOOM_IN_NNI_2X
        .word CMD_ZOOM_IN_NNI_4X
        .word CMD_ZOOM_IN_REP_2X
        .word CMD_ZOOM_IN_REP_4X
        .word CMD_ZOOM_OUT_NNI_2X
        .word CMD_ZOOM_OUT_NNI_4X
        .word CMD_ZOOM_OUT_AVG_2X
        .word CMD_ZOOM_OUT_AVG_4X

@ ===========================
@ SEÇÃO BSS
@ ===========================

.bss
    .align 4
    image_buffer:       .skip 1048576
    image_info:         .skip 32
    bmp_header:         .skip 1078
    bmp_fd:             .skip 4
    fpga_ponte_ptr:     .skip 4
    fpga_status_ptr:    .skip 4
    fpga_mem_fd:        .skip 4
    fpga_base_addr:     .skip 4
    input_buf:          .skip 4
    num_buffer:         .skip 12

@ ===========================
@ PROGRAMA PRINCIPAL
@ ===========================

.text
.global _start
.syntax unified

_start:
    @ Verifica argumentos (argc >= 2)
    ldr r0, [sp]
    cmp r0, #2
    blt show_usage
    
    @ Obtém nome do arquivo (argv[1])
    ldr r10, [sp, #8]
    
    @ Exibe banner
    bl print_banner
    
    @ Inicializa API FPGA
    bl fpga_init
    cmp r0, #0
    blt error_exit
    
    @ Carrega imagem BMP
    mov r0, r10
    ldr r1, =image_buffer
    ldr r2, =image_info
    bl bmp_load
    cmp r0, #0
    blt error_exit
    
    @ Exibe informações da imagem
    ldr r0, =image_info
    bl bmp_print_info
    
    @ Transfere para FPGA
    ldr r0, =image_buffer
    ldr r1, =image_info
    bl fpga_transfer_image
    cmp r0, #0
    blt error_exit
    
    @ Comando inicial: exibir original
    mov r0, #CMD_ORIGINAL
    bl fpga_send_command
    
    @ Loop do menu
    bl ui_menu_loop
    
    @ Finalização limpa
    bl fpga_cleanup
    
    ldr r0, =exit_msg
    bl print_string
    
    mov r7, #SYS_EXIT
    mov r0, #0
    svc #0

show_usage:
    ldr r0, =usage_msg
    bl print_string
    b error_exit

print_banner:
    push {lr}
    ldr r0, =banner
    bl print_string
    ldr r0, =banner2
    bl print_string
    ldr r0, =banner3
    bl print_string
    ldr r0, =banner4
    bl print_string
    pop {pc}

error_exit:
    bl fpga_cleanup
    mov r7, #SYS_EXIT
    mov r0, #1
    svc #0

@ ===========================
@ BMP API
@ ===========================

bmp_load:
    push {r4-r8, lr}
    mov r4, r0
    mov r5, r1
    mov r6, r2
    
    ldr r0, =bmp_loading
    bl print_string
    
    @ Abre arquivo
    mov r7, #SYS_OPEN
    mov r0, r4
    mov r1, #O_RDONLY
    mov r2, #0
    svc #0
    
    cmp r0, #0
    blt .bmp_load_error_open
    
    mov r8, r0
    ldr r1, =bmp_fd
    str r0, [r1]
    
    @ Lê cabeçalho
    mov r7, #SYS_READ
    mov r0, r8
    ldr r1, =bmp_header
    ldr r2, =bmp_full_hdr
    ldr r2, [r2]
    svc #0
    
    cmp r0, #BMP_HEADER_SIZE
    blt .bmp_load_error_read
    
    @ Valida BMP
    bl bmp_validate_header
    cmp r0, #0
    blt .bmp_load_error_invalid
    
    @ Extrai informações
    mov r0, r6
    bl bmp_extract_info
    
    @ Lê dados de pixel
    mov r0, r5
    mov r1, r6
    bl bmp_read_pixels
    cmp r0, #0
    blt .bmp_load_error_read
    
    @ Fecha arquivo
    bl bmp_close
    
    ldr r0, =bmp_success
    bl print_string
    
    mov r0, #0
    pop {r4-r8, pc}

.bmp_load_error_open:
    ldr r0, =bmp_err_open
    bl print_string
    mov r0, #-1
    pop {r4-r8, pc}

.bmp_load_error_read:
    ldr r0, =bmp_err_read
    bl print_string
    bl bmp_close
    mov r0, #-1
    pop {r4-r8, pc}

.bmp_load_error_invalid:
    ldr r0, =bmp_err_invalid
    bl print_string
    bl bmp_close
    mov r0, #-1
    pop {r4-r8, pc}

bmp_validate_header:
    push {r4-r5, lr}
    
    ldr r4, =bmp_header
    
    @ Verifica assinatura "BM"
    ldrh r5, [r4]
    ldr r1, =BMP_SIGNATURE
    cmp r5, r1
    bne .bmp_invalid
    
    @ Verifica bits por pixel
    ldrh r5, [r4, #28]
    cmp r5, #8
    bne .bmp_invalid
    
    @ Verifica tamanho do header DIB
    ldr r5, [r4, #14]
    cmp r5, #40
    bne .bmp_invalid
    
    mov r0, #0
    pop {r4-r5, pc}

.bmp_invalid:
    mov r0, #-1
    pop {r4-r5, pc}

bmp_extract_info:
    push {r4-r6, lr}
    mov r4, r0
    ldr r5, =bmp_header
    
    @ Largura
    ldr r0, [r5, #18]
    str r0, [r4, #INFO_WIDTH]
    
    @ Altura
    ldr r1, [r5, #22]
    str r1, [r4, #INFO_HEIGHT]
    
    @ Bits por pixel
    ldrh r2, [r5, #28]
    str r2, [r4, #INFO_BPP]
    
    @ Offset dos dados
    ldr r3, [r5, #10]
    str r3, [r4, #INFO_DATA_OFFSET]
    
    @ Total de pixels
    mul r6, r0, r1
    str r6, [r4, #INFO_TOTAL_PIXELS]
    
    pop {r4-r6, pc}

bmp_read_pixels:
    push {r4-r8, lr}
    mov r4, r0
    mov r5, r1
    
    @ Posiciona no início dos dados
    mov r7, #SYS_LSEEK
    ldr r0, =bmp_fd
    ldr r0, [r0]
    ldr r1, [r5, #INFO_DATA_OFFSET]
    mov r2, #0
    svc #0
    
    cmp r0, #0
    blt .bmp_read_error
    
    @ Calcula padding
    ldr r6, [r5, #INFO_WIDTH]
    ldr r7, [r5, #INFO_HEIGHT]
    
    add r8, r6, #3
    bic r8, r8, #3
    
    @ Se não há padding, lê tudo
    cmp r8, r6
    bne .bmp_read_rows
    cmp r7, #0
    blt .bmp_read_rows
    
    @ Leitura simples
    mov r7, #SYS_READ
    ldr r0, =bmp_fd
    ldr r0, [r0]
    mov r1, r4
    ldr r2, [r5, #INFO_TOTAL_PIXELS]
    svc #0
    
    cmp r0, #0
    blt .bmp_read_error
    b .bmp_read_success

.bmp_read_rows:
    mov r7, #SYS_READ
    ldr r0, =bmp_fd
    ldr r0, [r0]
    mov r1, r4
    ldr r2, [r5, #INFO_TOTAL_PIXELS]
    svc #0
    
    cmp r0, #0
    blt .bmp_read_error

.bmp_read_success:
    mov r0, #0
    pop {r4-r8, pc}

.bmp_read_error:
    mov r0, #-1
    pop {r4-r8, pc}

bmp_close:
    push {r7, lr}
    ldr r1, =bmp_fd
    ldr r0, [r1]
    cmp r0, #0
    ble .bmp_close_done
    
    mov r7, #SYS_CLOSE
    svc #0
    
    ldr r1, =bmp_fd
    mov r0, #0
    str r0, [r1]
    
.bmp_close_done:
    pop {r7, pc}

bmp_print_info:
    push {r4-r6, lr}
    mov r4, r0
    
    ldr r0, =bmp_info_fmt
    bl print_string
    
    ldr r0, [r4, #INFO_WIDTH]
    bl print_number
    
    ldr r0, =bmp_info_x
    bl print_string
    
    ldr r0, [r4, #INFO_HEIGHT]
    bl print_number
    
    ldr r0, =bmp_info_px
    bl print_string
    
    ldr r0, [r4, #INFO_BPP]
    bl print_number
    
    ldr r0, =bmp_info_bpp
    bl print_string
    
    pop {r4-r6, pc}

@ ===========================
@ FPGA API - CORRIGIDA
@ ===========================

fpga_init:
    push {r4-r8, lr}

    ldr r0, =fpga_init_msg
    bl print_string

    mov r7, #SYS_OPEN
    ldr r0, =devmem_path
    mov r1, #O_RDWR
    mov r2, #0
    svc #0
    cmp r0, #0
    blt .fpga_init_error_devmem

    mov r4, r0                  @ fd = /dev/mem
    ldr r1, =fpga_mem_fd
    str r4, [r1]

    @ offset = 0xFF200000 / 4096 = 0xFF200
    ldr r5, =0xFF200

    mov r7, #SYS_MMAP2
    mov r0, #0                  @ addr = NULL
    mov r1, #4096               @ length = 4KB
    mov r2, #(PROT_READ | PROT_WRITE)
    mov r3, #MAP_SHARED
    @ r4 = fd
    @ r5 = offset
    svc #0                      @ não precisa empilhar
    
    @ Verifica erro no mmap2
    cmn r0, #1
    beq .fpga_init_error_mmap
    ldr r1, =MAP_FAILED
    cmp r0, r1
    beq .fpga_init_error_mmap
    
    @ Sucesso - salva endereço base
    mov r6, r0
    ldr r1, =fpga_base_addr
    str r6, [r1]
    
    @ Calcula ponteiro para PIO_PONTE
    ldr r7, =PIO_PONTE_OFFSET
    add r1, r6, r7
    ldr r2, =fpga_ponte_ptr
    str r1, [r2]
    
    @ Calcula ponteiro para PIO_STATUS
    ldr r7, =PIO_STATUS_OFFSET
    add r1, r6, r7
    ldr r2, =fpga_status_ptr
    str r1, [r2]
    
    ldr r0, =fpga_init_ok
    bl print_string
    
    mov r0, #0
    pop {r4-r8, pc}

.fpga_init_error_devmem:
    ldr r0, =fpga_err_devmem
    bl print_string
    mov r0, #-1
    pop {r4-r8, pc}

.fpga_init_error_mmap:
    ldr r0, =fpga_init_err
    bl print_string
    
    @ Fecha /dev/mem
    ldr r1, =fpga_mem_fd
    ldr r0, [r1]
    mov r7, #SYS_CLOSE
    svc #0
    
    mov r0, #-1
    pop {r4-r8, pc}

fpga_cleanup:
    push {r4-r5, r7, lr}
    
    ldr r4, =fpga_mem_fd
    ldr r0, [r4]
    cmp r0, #0
    ble .fpga_cleanup_done
    
    mov r7, #SYS_CLOSE
    svc #0
    
    ldr r4, =fpga_mem_fd
    mov r0, #0
    str r0, [r4]
    
.fpga_cleanup_done:
    pop {r4-r5, r7, pc}

fpga_transfer_image:
    push {r4-r10, lr}
    mov r4, r0
    mov r5, r1
    
    ldr r0, =fpga_transfer_msg
    bl print_string
    
    @ Verifica se ponteiro FPGA é válido
    ldr r8, =fpga_ponte_ptr
    ldr r8, [r8]
    
    @ Carrega total de pixels
    ldr r6, [r5, #INFO_TOTAL_PIXELS]
    mov r7, #0                  @ contador
    
fpga_transfer_loop:
    cmp r7, r6
    bge .fpga_transfer_done
    
    @ Lê pixel do buffer
    ldrb r9, [r4, r7]
    
    @ Monta comando: APENAS (pixel << 7) | 0x40
    @ Garante que bits 5-0 = 0x40 (algoritmo=0, zoom=0, controle=1)
    lsl r10, r9, #7
    orr r10, r10, #0x0040     @ Bits: [14:7]=pixel, [6]=1, [5:0]=0
    
    @ Escreve no FPGA
    str r10, [r8]
    
    @ DELAY AUMENTADO - crítico para captura de borda
    @ 25MHz = 40ns/ciclo, precisa de ~5 ciclos = 200ns
    @ 50MHz do ARM = 20ns/ciclo, precisa de ~500 ciclos
    mov r0, #500
    bl delay_cycles
    
    @ Limpa o bit de controle (borda descendente)
    lsl r10, r9, #7
    str r10, [r8]              @ controle_ram = 0
    
    mov r0, #500
    bl delay_cycles
    
    add r7, r7, #1
    b fpga_transfer_loop

.fpga_transfer_done:
    ldr r0, =fpga_transfer_ok
    bl print_string
    mov r0, #0
    pop {r4-r10, pc}

.fpga_transfer_error:
    ldr r0, =fpga_init_err
    bl print_string
    mov r0, #-1
    pop {r4-r10, pc}

fpga_send_command:
    push {r4-r6, lr}
    mov r4, r0
    
    ldr r0, =fpga_cmd_msg
    bl print_string
    
    ldr r5, =fpga_ponte_ptr
    ldr r5, [r5]
    cmp r5, #0
    beq .fpga_cmd_error
    
    str r4, [r5]
    
    mov r0, #100
    bl delay_cycles
    
    ldr r0, =fpga_cmd_ok
    bl print_string
    
    mov r0, #0
    pop {r4-r6, pc}

.fpga_cmd_error:
    mov r0, #-1
    pop {r4-r6, pc}

fpga_wait_ready:
    push {r4-r5, lr}
    
    ldr r4, =fpga_status_ptr
    ldr r4, [r4]
    cmp r4, #0
    beq .fpga_wait_error
    
.fpga_wait_loop:
    ldr r5, [r4]
    tst r5, #1
    bne .fpga_wait_loop
    
    mov r0, #0
    pop {r4-r5, pc}

.fpga_wait_error:
    mov r0, #-1
    pop {r4-r5, pc}

delay_cycles:
    push {r4}
    mov r4, r0
.delay_loop:
    subs r4, r4, #1
    bne .delay_loop
    pop {r4}
    bx lr

@ ===========================
@ UI API
@ ===========================

ui_menu_loop:
    push {r4-r6, lr}
    
.ui_menu_start:
    bl ui_print_menu
    
    bl ui_read_choice
    mov r4, r0
    
    cmp r4, #9
    beq .ui_menu_exit
    
    cmp r4, #0
    blt .ui_menu_invalid
    cmp r4, #8
    bgt .ui_menu_invalid
    
    mov r0, r4
    bl ui_map_command
    bl fpga_send_command
    
    b .ui_menu_start

.ui_menu_invalid:
    ldr r0, =menu_invalid
    bl print_string
    b .ui_menu_start

.ui_menu_exit:
    pop {r4-r6, pc}

ui_print_menu:
    push {lr}
    ldr r0, =menu_header
    bl print_string
    ldr r0, =menu_opt0
    bl print_string
    ldr r0, =menu_opt1
    bl print_string
    ldr r0, =menu_opt2
    bl print_string
    ldr r0, =menu_opt3
    bl print_string
    ldr r0, =menu_opt4
    bl print_string
    ldr r0, =menu_opt5
    bl print_string
    ldr r0, =menu_opt6
    bl print_string
    ldr r0, =menu_opt7
    bl print_string
    ldr r0, =menu_opt8
    bl print_string
    ldr r0, =menu_opt9
    bl print_string
    ldr r0, =menu_prompt
    bl print_string
    pop {pc}

ui_read_choice:
    push {r4, r7, lr}
    
    mov r7, #SYS_READ
    mov r0, #0
    ldr r1, =input_buf
    mov r2, #4
    svc #0
    
    ldr r1, =input_buf
    ldrb r0, [r1]
    
    cmp r0, #'0'
    blt .ui_read_invalid
    cmp r0, #'9'
    bgt .ui_read_invalid
    
    sub r0, r0, #'0'
    pop {r4, r7, pc}

.ui_read_invalid:
    mov r0, #-1
    pop {r4, r7, pc}

ui_map_command:
    push {r4, lr}
    mov r4, r0
    
    cmp r4, #0
    blt .ui_map_invalid
    cmp r4, #8
    bgt .ui_map_invalid
    
    ldr r1, =cmd_table
    lsl r4, r4, #2
    ldr r0, [r1, r4]
    
    pop {r4, pc}

.ui_map_invalid:
    mov r0, #CMD_ORIGINAL
    pop {r4, pc}

@ ===========================
@ FUNÇÕES UTILITÁRIAS
@ ===========================

print_string:
    push {r0-r5, r7, lr}
    mov r4, r0
    
    mov r1, r0
    mov r5, #0
.strlen_loop:
    ldrb r2, [r1], #1
    cmp r2, #0
    addne r5, r5, #1
    bne .strlen_loop
    
    mov r7, #SYS_WRITE
    mov r0, #1
    mov r1, r4
    mov r2, r5
    svc #0
    
    pop {r0-r5, r7, pc}

print_number:
    push {r4-r8, lr}
    mov r4, r0
    
    ldr r5, =num_buffer
    add r5, r5, #11
    mov r6, #0
    
    cmp r4, #0
    bne .convert_loop
    mov r7, #'0'
    sub r5, r5, #1
    strb r7, [r5]
    mov r6, #1
    b .print_num
    
.convert_loop:
    cmp r4, #0
    beq .print_num
    
    mov r0, r4
    bl divide_by_10
    
    add r1, r1, #'0'
    sub r5, r5, #1
    strb r1, [r5]
    add r6, r6, #1
    
    mov r4, r0
    b .convert_loop
    
.print_num:
    mov r7, #SYS_WRITE
    mov r0, #1
    mov r1, r5
    mov r2, r6
    svc #0
    
    pop {r4-r8, pc}

divide_by_10:
    push {r4-r5}
    
    cmp r0, #100
    blt .div10_simple
    
    ldr r4, =0xCCCCCCCD
    umull r1, r2, r0, r4
    lsr r2, r2, #3
    
    mov r4, #10
    mul r5, r2, r4
    sub r1, r0, r5
    
    mov r0, r2
    pop {r4-r5}
    bx lr

.div10_simple:
    mov r1, #0
    mov r4, r0
    
.div10_loop:
    cmp r4, #10
    blt .div10_done
    sub r4, r4, #10
    add r1, r1, #1
    b .div10_loop
    
.div10_done:
    mov r0, r1
    mov r1, r4
    pop {r4-r5}
    bx lr

@ Função auxiliar: calcula r0 % r1
modulo:
    push {r4-r5, lr}
    mov r4, r0
    mov r5, r1
    
.mod_loop:
    cmp r4, r5
    blt .mod_done
    sub r4, r4, r5
    b .mod_loop
    
.mod_done:
    mov r0, r4
    pop {r4-r5, pc}

@ ===========================
@ FIM DO ARQUIVO
@ ===========================
