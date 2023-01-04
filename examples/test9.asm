*-----------------------------------------------------------
* Title      : test9.asm
* Written by : Fred Bayer
* Date       : 2021-05-05
* Description: Stepping and traps
*-----------------------------------------------------------

            org     $400
            andi    #$dfff,sr    ; switch to user mode, can be left out
            move.w  d0,d0        ; just a marker to see where you are
            nop
again       move.w  d1,d1        ; dito
            bsr.s   delay        ; try step into and step out
            move.w  d2,d2        ; marker again
            trap    #0           ; try step over / step into + go
            move.w  d3,d3
            pea     1234.w       ; try step over from here
            clr.l   -(sp)
            bsr.s   delay        ; and from here
            move.w  d4,d4
            adda.w  #8,sp
            move.w  d5,d5
            trap    #1           ; try stepping through disabled trap
            move.w  d6,d6
            bra.s   again

delay       moveq   #4,d7
loop        trap    #1           ; enable/disable and see how the stepper reacts
            dbf     d7,loop
            rts