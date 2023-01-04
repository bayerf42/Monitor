;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Reset vector, initial SP and PC
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           org         $0
           dc.l        sys_stack
           dc.l        start

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Start of Monitor in ROM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           org         $40100

sys_stack  equ         $20000          ; top of RAM, 1kb
user_stack equ         $1fc00          ; USP 1k below SSP, enough space for system stack

           section     code

code       equ         *               ; start address of code section (instructions in ROM)

           section     const
const      equ         *               ; start address of const section (initialized data in ROM)


           section     code

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Entry table for monitor routines at fixed addresses
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

sys_getchar
           jmp         _get_byte
sys_putchar
           jmp         _send_byte
sys_pstring
           jmp         _pstring
sys_print_led
           jmp         _print_led
sys_disassemble
           jmp         _disassemble
sys_lcd_init
           jmp         _InitLcd
sys_lcd_goto
           jmp         _goto_xy
sys_lcd_puts
           jmp         _Puts
sys_lcd_clear
           jmp         _clr_screen
sys_lcd_defchar
           jmp         _def_char
sys_monitor_loop
           jmp         main_1
sys_monitor_scan
           jmp         _scan


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Main entry to monitor
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

start:
           ;; Init exception vectors 
           move.l      #service_bus_err,$8  ; bus error
           move.l      #service_addr_err,$c ; address error
           move.l      #service_illegal,$10 ; illegal instruction
           move.l      #service_div0,$14    ; division by 0
           move.l      #service_check,$18   ; check out of bounds
           move.l      #service_trapv,$1c   ; trap on overflow
           move.l      #service_priv,$20    ; privilege violation
           move.l      #service_trace,$24   ; trace
           move.l      #service_line_a,$28  ; line A emulation
           move.l      #service_line_f,$2c  ; line F emulation

           ;; Default interrupt vectors
           lea         service_interrupts,a0
           move.l      a0,$3c               ; uninitialized interrupt
           lea         $60.w,a1             ; start with spurious interrupt
           moveq       #7,d0
_next_int
           move.l      a0,(a1)+
           dbf         d0,_next_int

           ;; Default trap vectors
           lea         service_traps,a0
           lea         $80.w,a1             ; start with trap #0
           moveq       #15,d0 
_next_trap
           move.l      a0,(a1)+
           dbf         d0,_next_trap

           ;; overwrite vectors actually used
           move.l      #service_tick,$68    ; level 2 interrupt
           move.l      #service_trap0,$80   ; trap #0 (back to monitor)
           move.l      #service_trap1,$84   ; trap #1 (static breakpoint)
           move.l      #service_trap3,$8c   ; trap #3 (dynamic breakpoint)

           jmp         _main

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Monitor variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

           section     data
           org         $200                 ; user interrupts not used, so place global variables
                                            ; here to make entire RAM above $400 available to user
