*-----------------------------------------------------------
* Title      : monitor4x.inc
* Written by : Fred Bayer
* Date       : 2021-04-03
* Description: Official entrypoints into monitor ROM V4.x
*-----------------------------------------------------------


****************************************************************************************************
* Service entrypoints (C-calling convention)
****************************************************************************************************
getchar            equ  $40100     * void            -> int32 
putchar            equ  $40106     * int8            -> void
pstring            equ  $4010C     * int8*           -> void

print_led          equ  $40112     * int32,char*     -> void
disassemble        equ  $40118     * int16**,char*   -> void

lcd_init           equ  $4011e     * void            -> void
lcd_goto           equ  $40124     * int32,int32     -> void
lcd_puts           equ  $4012A     * char*           -> char*
lcd_clear          equ  $40130     * void            -> void
lcd_defchar        equ  $40136     * char,char*      -> void

monitor_loop       equ  $4013C     * void            -> [no return]
monitor_scan       equ  $40142     * void            -> char


****************************************************************************************************
* 68008 kit I/O locations
****************************************************************************************************
gpio1              equ  $F0000     * 8-bit debugging LED
port0              equ  $80000     * key input
port1              equ  $80002     * digit driver
port2              equ  $A0000     * segment driver

LCD_command_write  equ  $60000
LCD_data_write     equ  $60001
LCD_command_read   equ  $60002
LCD_data_read      equ  $60003


****************************************************************************************************
* Useful monitor variables
****************************************************************************************************
led_buffer         equ  $00202     * byte*8, LED segment buffer, right to left!
tick_100hz         equ  $00268     * long, tick counter
disasm_lines       equ  $0026c     * word, number of lines to disassemble
hexdump_lines      equ  $0026e     * word, number of lines of hexdump
disasm_on_lcd      equ  $00270     * byte, 0 to suppress displaying current instruction on LCD
enable_trap1       equ  $00272     * byte, 0 to skip over TRAP 1, 1 to break at TRAP 1
delay_b1           equ  $0027c     * long, delay1 for UART, 2400: 0x1a, 4800: 0x0a, 9600: 0x02
delay_b2           equ  $00280     * long, delay2 for UART, 2400: 0x2b, 4800: 0x15, 9600: 0x06
user_data          equ  $002a6     * long*8, data registers D0-D7
user_addr          equ  $002c6     * long*7, address registers A0-A6
user_usp           equ  $002e2     * long, user stack pointer USP
user_ssp           equ  $002e6     * long, system stack pointer SSP
user_sr            equ  $002ea     * word, status register SR
user_pc            equ  $002ec     * long, program counter PC
show_sr            equ  $002fa     * byte, status register display: 0 classic, 1 numeric, 2 symbolic
lcd_width          equ  $00300     * byte, width of LCD, typically 8, 16, 20
lcd_lines          equ  $00302     * byte, height of LCD, typically 1, 2, 4
lcd_present        equ  $00304     * byte, 0 when LCD is missing, 1 when present
shift_size         equ  $00306     * word, size of block to be shifted on INS and DEL, usually 512