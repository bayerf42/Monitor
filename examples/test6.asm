*-----------------------------------------------------------
* Title      : test6.asm
* Written by : Fred Bayer
* Date       : 2021-04-16
* Description: learn monitor, single step thru it and play around
*-----------------------------------------------------------

            include ../include/monitor4x.inc

            org     user_data
            dc.l    $d0d0d0d0        * This way we can initialize registers
            dc.l    $d1d1d1d1
            dc.l    $d2d2d2d2

            org     user_addr+3*4
            dc.l    $a3a3a3a3

            org     $400
start
            andi    #$dfff,sr        * Switch to user mode
            move.l  #$12345678,d0
            add.l   #$76543210,d0
            muls    #77,d0
            trap    #1
            move.l  d0,-(sp)         * step over from here goes upto label `here`
            move.w  (sp)+,d1
            move.w  (sp)+,d2
here        bsr.s   foo
            roxr.l  #3,d0
            trap    #0
            bra     start            * Restart will throw privilege violation

foo         addq.l  #5,d0
            rts

            end     start