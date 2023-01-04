*-----------------------------------------------------------
* Title      : test_keys.asm
* Written by : Fred Bayer
* Date       : 2021-05-09
* Description: display key codes
*              Run and press keys. RESET to stop.
*              RESET, IRQ and REP aren't part of the Matrix,
*              they don't display here
*-----------------------------------------------------------

            org     $400
start
            jsr     lcd_clear
again       jsr     monitor_scan       ; when stepping over, note the display
            move.b  d0,d1              ; key code
            asr.b   #4,d0
            lea     txt_code.w,a0      ; point to output buffer
            bsr.s   nibble             ; print upper nibble
            move.b  d1,d0
            bsr.s   nibble             ; print lower nibble
            clr.l   -(sp)
            clr.l   -(sp)
            jsr     lcd_goto           ; goto 0,0 Note: no stack cleanup yet
            pea     message.w
            jsr     lcd_puts
            adda.w  #12,sp             ; remove all params from stack, both lcd_goto and lcd_puts
            trap    #1
            bsr.s   delay              ; rather step over than step into!
            bra.s   again

nibble      andi.b  #$0f,d0            ; extract nibble
            addi.b  #'0',d0
            cmpi.b  #'9',d0            ; test if letter needed
            bls.s   ok
            addq.b  #7,d0              ; adjust for letters
ok          move.b  d0,(a0)+           ; append to buffer
            rts

delay       move.w  #5000,d0
loop        dbf     d0,loop            ; delay loop
            rts

message     dc.b    "Key = "
txt_code    dc.b    "xx",0

            include ../include/monitor4x.inc

            end     start