#ifndef __inc_monitor4x_h
#define __inc_monitor4x_h

/*****************************************************************************
* Some type abbreviations
*****************************************************************************/
typedef unsigned char  uchar;
typedef unsigned short ushort;
typedef unsigned int   uint;
typedef unsigned long  ulong;

/*****************************************************************************
* Stubs to call monitor routines from C
*****************************************************************************/
extern void print_led(int offset, const char* text);
extern void disassemble(ushort** addr, char* dest);
extern void lcd_init(void);
extern void lcd_goto(int x, int y);
extern const char* lcd_puts(const char* text);
extern void lcd_clear(void);
extern void lcd_defchar(char udc, const char* bits);
extern void monitor_loop(void);
extern char monitor_scan(void);

/*****************************************************************************
*  68008 kit I/O locations
*****************************************************************************/
#define gpio1 ((char *) 0xF0000)   // 8-bit debugging LED
#define port0 ((char *) 0x80000)   // key input
#define port1 ((char *) 0x80002)   // digit driver
#define port2 ((char *) 0xA0000)   // segment driver

#define LCD_command_write ((char *) 0x60000)
#define LCD_data_write    ((char *) 0x60001)
#define LCD_command_read  ((char *) 0x60002)
#define LCD_data_read     ((char *) 0x60003)

/*****************************************************************************
* Useful monitor variables
*****************************************************************************/
#define tick_100hz    ((ulong *)  0x00268) // tick counter
#define disasm_lines  ((ushort *) 0x0026c) // number of lines to disassemble
#define hexdump_lines ((ushort *) 0x0026e) // number of lines of hexdump
#define disasm_on_lcd ((char *)   0x00270) // 0 to suppress displaying current instruction on LCD
#define enable_trap1  ((char *)   0x00272) // 0 to skip over TRAP 1, 1 to break at TRAP 1
#define delay_b1      ((uint *)   0x0027c) // delay1 for UART, 2400: 0x1a, 4800: 0x0a, 9600: 0x02
#define delay_b2      ((uint *)   0x00280) // delay2 for UART, 2400: 0x2b, 4800: 0x15, 9600: 0x06
#define user_data(n)  ((ulong *)  (0x002a6+4*(n))) // 8 elements, data registers D0-D7
#define user_addr(n)  ((ulong *)  (0x002c6+4*(n))) // 7 elements, address registers A0-A6
#define user_usp      ((ulong *)  0x002e2) // user stack pointer USP
#define user_ssp      ((ulong *)  0x002e6) // system stack pointer SSP
#define user_sr       ((ushort *) 0x002ea) // status register SR
#define user_pc       ((ulong *)  0x002ec) // program counter PC
#define show_sr       ((char *)   0x002fa) // status register display: 0 classic, 1 numeric, 2 symbolic
#define lcd_width     ((uchar *)  0x00300) // width of LCD, typically 8, 16, 20
#define lcd_lines     ((uchar *)  0x00302) // height of LCD, typically 1, 2, 4
#define lcd_present   ((char *)   0x00304) // 0 if LCD is missing, 1 if present
#define shift_size    ((ushort *) 0x00306) // size of block to be shifted on INS and DEL, usually 512

#endif
