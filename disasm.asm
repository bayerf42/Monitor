*-----------------------------------------------------------
* Title      : disasm.asm
* Written by : Fred Bayer
* Date       : 2020-12-12
* Description: 68000 Disassembler
*-----------------------------------------------------------

            xdef    _disassemble
_disassemble:   * Entry to disassembler using C calling convention
                * void disassemble(ushort** addr, char* dest);
            link    a6,#0
            movem.l d2-d6/a2-a4,-(a7)
            move.l  8(a6),a2
            move.l  (a2),a2
            move.l  12(a6),a4
            bsr.s   disassemble_inst
            move.l  8(a6),a0
            move.l  a2,(a0)
            movem.l (a7)+,d2-d6/a2-a4
            unlk    a6
            rts

*=============================================================================
*
* Main entry to disassembler
*   Register usage:
*
*   D0: scratch
*   D1: scratch
*   D2: state/nibble aux.
*   D3: register list
*   D4: opcode
*   D5: opsize
*   D6: backup_ea
*   D7: -
*
*   A0: scratch
*   A1: scratch/input to strapp
*   A2: instruction pointer
*   A3: internal for decoder table
*   A4: output buffer
*   A5: -
*   A6: -
*
*   A2 must point to the instruction being disassembled and is
*   advanced to next instruction on return.
*   A4 must point to an output buffer where the disassembly string
*   will be written. It is 0-terminated and opcode, operand and comment
*   are separated by TAB characters. The buffer should be at least 50 bytes.
*
*   Standard Motorola syntax is used and a ? and ^ character precede wrong
*   operands:
*   .? indicates an invalid size field
*   ^ indicates invalid size (=byte) for an address register
*   ? before an operand indicates illegal addressing mode for this instruction
*   ?ea indicates a reserved effective address bit pattern
*   ?op in the comment indicates illegal opcode
*   line A and line F opcodes are marked in the comment field
*
*   PC-relative addresses are displayed using the actual operand address
*=============================================================================

disassemble_full                       * Disassemble with address and opcode
            move.l  a2,d0
            bsr     print_addr24       * print memory address of instruction
            move.b  #':',(a4)+
            move.w  (a2),d0
            bsr     print_word         * print instruction hexadecimal
            move.b  #' ',(a4)+

disassemble_inst                       * Disassemble instruction only
            move.w  (a2)+,d4           * store opcode for later
            lea     instructions(pc),a3

.next       move.w  d4,d0
            and.w   (a3),d0            * test opcode bit pattern
            cmp.w   2(a3),d0
            beq.s   .found
            adda.w  #10,a3
            bra.s   .next

.found      lea     str_base(pc),a1    * opcode found, now dispatch to printer fct
            adda.w  8(a3),a1           * offset in string table
            cmpi.b  #';',(a1)          * opcode is a comment, don't print yet
            beq.s   .dont_print
            bsr     strapp
.dont_print lea     op_base(pc),a0
            adda.w  6(a3),a0           * offset in fct table
            jsr     (a0)               * call special printer function
            clr.b   (a4)               * terminate output string
            rts

*============================================================
* Inline coded formatting strings for opcode patterns
*============================================================

op_simple                              * <op>
            move.b  #9,(a4)+           * always have a TAB
            rts

op_simple_ea1                          * <op>   <ea> {operand size=1}
            moveq   #1,d5
            bra.s   op_ea_cont

op_simple_ea2                          * <op>   <ea> {operand size=2}
            moveq   #2,d5
            bra.s   op_ea_cont

op_simple_ea4                          * <op>   <ea> {operand size=4}
            moveq   #4,d5
op_ea_cont  move.b  #9,(a4)+
            bra     print_ea

op_simple_size_ea                      * <op>.<sz>   <ea>
            bsr     print_size
            bra     print_ea

op_imm2                                * <op>   #<data> {operand size=2}
            move.b  #9,(a4)+
            moveq   #2,d5
            bra     print_immediate

op_imm_size_ea                         * <op>I.<sz>   #<data>,<ea>
            move.b  #'I',(a4)+
            bsr     print_size
            bsr     print_immediate
            move.b  #',',(a4)+
            bra     print_ea

op_size_dn_ea                          * <op>.<sz>   Dn,<ea>
            bsr     print_size
            bsr     print_hi_dreg
            move.b  #',',(a4)+
            bra     print_ea

op_size_ea_dn                          * <op>.<sz>   <ea>,Dn
            bsr     print_size
            bsr     print_ea
            move.b  #',',(a4)+
            bra     print_hi_dreg

op_size_ea_an                          * <op>A.<sz>   <ea>,An
            move.b  #'A',(a4)+
            move.b  #'.',(a4)+
            btst    #8,d4              * size flag in opcode (W/L)
            bsr     print_worl
            move.b  #9,(a4)+
            bsr     print_ea
            move.b  #',',(a4)+
            bra     print_hi_areg

op_size_tiny_ea                        * <op>Q.<sz>   #<data>,<ea>
            move.b  #'Q',(a4)+
            bsr     print_size
            bsr     print_tiny
            move.b  #',',(a4)+
            bra     print_ea

op_movep_dx_ay                         * <op>P.<sz>   Dx,(d,Ay)
            bsr.s   movep_comm
            bsr     print_hi_dreg
            move.b  #',',(a4)+
pr_dsp_ay   move.b  #'(',(a4)+         * entry for (d,Ay)
            bsr     print_displacement
            move.b  #',',(a4)+
            bsr     print_lo_areg
            move.b  #')',(a4)+
            rts

op_movep_ay_dx                         * <op>P.<sz>   (d,Ay),Dx
            bsr.s   movep_comm
            bsr.s   pr_dsp_ay
            move.b  #',',(a4)+
            bra     print_hi_dreg

movep_comm  move.b  #'P',(a4)+
            bsr     print_bit6_size
            move    #2,d5
            rts

op_ea2_dn                              * <op>   <ea>,Dn {operand size=2}
            moveq   #2,d5
            move.b  #9,(a4)+
            bsr     print_ea
            move.b  #',',(a4)+
            bra     print_hi_dreg

op_ea4_an                              * <op>   <ea>,An {operand size=4}
            moveq   #4,d5
            move.b  #9,(a4)+
            bsr     print_ea
            move.b  #',',(a4)+
            bra     print_hi_areg

op_an_size                             * <op>   An,#size
            move.b  #9,(a4)+
            bsr     print_lo_areg
            move.b  #',',(a4)+
            moveq   #2,d5
            bra     print_immediate

op_an                                  * <op>   An
            move.b  #9,(a4)+
            bra     print_lo_areg

op_an_usp                              * <op>   An,USP
            move.b  #9,(a4)+
            bsr     print_lo_areg
            move.b  #',',(a4)+
            lea     str_usp(pc),a1
            bra     strapp

op_usp_an                              * <op>   USP,An
            move.b  #9,(a4)+
            lea     str_usp(pc),a1
            bsr     strapp
            move.b  #',',(a4)+
            bra     print_lo_areg

op_ext_dn                              * <op>   Dy,Dx
            move.b  #9,(a4)+
            bra.s   ext_dn_cont

op_ext_an                              * <op>   -(Ay),-(Ax)
            move.b  #9,(a4)+
            bra.s   ext_an_cont

op_size_ext_dn                         * <op>X.<sz>   Dy,Dx
            move.b  #'X',(a4)+
            bsr     print_size
ext_dn_cont bsr     print_lo_dreg
            move.b  #',',(a4)+
            bra     print_hi_dreg

op_size_ext_an                         * <op>X.<sz>   -(Ay),-(Ax)
            move.b  #'X',(a4)+
            bsr     print_size
ext_an_cont move.b  #'-',(a4)+
            bsr     print_lo_areg_ind
            move.b  #',',(a4)+
            move.b  #'-',(a4)+
            bra     print_hi_areg_ind

op_size_cmpm                           * <op>.<sz>   (Ay)+,(Ax)+
            bsr     print_size
            bsr     print_lo_areg_ind
            move.b  #'+',(a4)+
            move.b  #',',(a4)+
            bsr     print_hi_areg_ind
            move.b  #'+',(a4)+
            rts

op_dx_dy                               * <op>    Dx,Dy
            move.b  #9,(a4)+
            bsr     print_hi_dreg
            move.b  #',',(a4)+
            bra     print_lo_dreg

op_ax_ay                               * <op>    Ax,Ay
            move.b  #9,(a4)+
            bsr     print_hi_areg
            move.b  #',',(a4)+
            bra     print_lo_areg

op_dx_ay                               * <op>    Dx,Ay
            move.b  #9,(a4)+
            bsr     print_hi_dreg
            move.b  #',',(a4)+
            bra     print_lo_areg

op_log_to_sr                           * <op>I   #<data>,SR
            move.b  #'I',(a4)+
            move.b  #9,(a4)+
            moveq   #2,d5
            bsr     print_immediate
            move.b  #',',(a4)+
            lea     str_sr(pc),a1
            bra     strapp

op_log_to_ccr                          * <op>I   #<data>,CCR
            move.b  #'I',(a4)+
            move.b  #9,(a4)+
            moveq   #1,d5
            bsr     print_immediate
            move.b  #',',(a4)+
            lea     str_ccr(pc),a1
            bra     strapp

op_from_sr                             * <op>    SR,<ea>
            move.b  #9,(a4)+
            lea     str_sr(pc),a1
            bsr     strapp
            move.b  #',',(a4)+
            moveq   #2,d5
            bra     print_ea

op_to_sr                               * <op>   <ea>,SR
            move.b  #9,(a4)+
            moveq   #2,d5
            bsr     print_ea
            move.b  #',',(a4)+
            lea     str_sr(pc),a1
            bra     strapp

op_to_ccr                              * <op>   <ea>,CCR
            move.b  #9,(a4)+
            moveq   #1,d5
            bsr     print_ea
            move.b  #',',(a4)+
            lea     str_ccr(pc),a1
            bra     strapp

op_bit_dn_ea                           * <op>   Dn,<ea>
            move.b  #9,(a4)+
            moveq   #1,d5              * for memory, don't care for Dn with size 4
            bsr     print_hi_dreg
            move.b  #',',(a4)+
            bra     print_ea

op_bit_imm_ea                          * <op>   #<data>,<ea>
            move.b  #9,(a4)+
            moveq   #1,d5              * like above
            bsr     print_immediate
            move.b  #',',(a4)+
            bra     print_ea

op_unknown                             * DC.W   <opcode>   * <comment>
            lea     str_dcw(pc),a1
            bsr     strapp
            move.b  #9,(a4)+
            move.b  #'$',(a4)+
            move.w  d4,d0              * opcode
            bsr     print_word
            move.b  #9,(a4)+
            lea     str_base(pc),a1
            adda.w  8(a3),a1           * opcode string as comment
            bra     strapp

op_shift                               * shift or rotate, register mode
            bsr     print_size
            btst    #5,d4              * Dn/imm code
            beq.s   .immediate
            bsr     print_hi_dreg      * shift count in data reg.
            bra.s   .cont
.immediate  bsr     print_tiny
.cont       move.b  #',',(a4)+
            bra     print_lo_dreg

op_move                                * <op>.<sz>   <ea>,<ea>
            bsr     print_move_size
            subq.w  #1,a3              * so that valid_ea in msb is used
            bsr     print_ea           * source ea
            addq.w  #1,a3              * restore a3
            move.b  #',',(a4)+
            move.w  d4,d1
            andi.w  #$0fc0,d1          * extract 6 bit dest. ea
            move.w  d1,d0
            rol.w   #7,d0              * lsr #9 -> rol #7
            lsr.w   #3,d1              * reg >> 3 bits
            andi.w  #$38,d1
            or.w    d1,d0
            bra     print_ea_d0

op_sz_dn                               * <op>.<sz>  Dn
            bsr     print_bit6_size
            bra     print_lo_dreg

op_dn                                  * <op>   Dn
            move.b  #9,(a4)+
            bra     print_lo_dreg

op_trap                                * TRAP   #<data>
            move.b  #9,-1(a4)          * overwrite 'V' of TRAPV
            move.b  #'#',(a4)+
            move.b  d4,d0
            bra     print_nibble       

op_cbranch                             * <op><cc>.<sz>   <target>
            bsr.s   print_cc           * fall-thru!

op_branch                              * <op>.<sz>   <target>
            move.b  #'.',(a4)+
            move.w  d4,d0
            tst.b   d0
            beq.s   .longbranch
            move.b  #'S',(a4)+
            move.b  #9,(a4)+
            ext.w   d0
            ext.l   d0
            add.l   a2,d0
            bra.s   br_cont1
.longbranch move.b  #'W',(a4)+
            move.b  #9,(a4)+
branch_tgt  move.w  (a2),d0
            ext.l   d0
            add.l   a2,d0
            lea     2(a2),a2
br_cont1    move.b  #'$',(a4)+
            bra     print_addr24

op_scc_ea                              * <op><cc>   <ea>
            bsr.s   print_cc
            move.b  #9,(a4)+
            moveq   #1,d5
            bra.s   print_ea

op_dbcc_dn                             * <op><cc>   Dn,<target>
            bsr.s   print_cc
            move.b  #9,(a4)+
            bsr     print_lo_dreg
            move.b  #',',(a4)+
            bra.s   branch_tgt

print_cc                               * Print condition codes
            move.w  d4,d0
            andi.w  #$0f00,d0
            lsr.w   #7,d0
            move.b  (cc_names,pc,d0.w),(a4)+
            move.b  (cc_names+1,pc,d0.w),(a4)+
            rts

cc_names    dc.b    'T F HILSCCCSNEEQVCVSPLMIGELTGTLE'

op_moveq                               * <op>   #<data>,Dn
            move.b  #9,(a4)+
            subq.w  #2,a2              * point back to opcode for byte immediate data
            moveq   #1,d5
            bsr     print_immediate
            move.b  #',',(a4)+
            bra     print_hi_dreg

op_mvm_list_ea                         * <op>M.<sz>   <list>,<ea>
            bsr.s   op_mvm_comm
            bsr     print_list
            move.b  #',',(a4)+
            bra.s   print_ea

op_mvm_ea_list                         * <op>M.<sz>   <ea>,<list>
            bsr.s   op_mvm_comm
            bsr.s   print_ea
            move.b  #',',(a4)+
            bra     print_list

op_mvm_comm move.b  #'M',(a4)+
            bsr     print_bit6_size
            move.w  (a2)+,d3
            rts

op_base     equ     op_simple          * Start of disasm fct table


*======================================================================
* Effective address output formatting
*======================================================================

print_ea                               * interprete effective address M and R
            move.w  d4,d0
print_ea_d0                            * entry for ea of general move
            andi.w  #$3f,d0
            move.w  d0,d6              * backup ea
            move.w  d0,d1
            andi.b  #7,d0              * d0 is register
            lsr.b   #3,d1              * d1 is mode

            dbra    d1,.next1
            btst    #0,5(a3)           * data register direct, check if allowed
            bne.s   .ok_dn
            move.b  #'?',(a4)+
.ok_dn      move.b  #'D',(a4)+
            bra     print_nibble

.next1      dbra    d1,.next2
            btst    #1,5(a3)           * address register direct, check if allowed
            bne.s   .ok_an
            move.b  #'?',(a4)+
.ok_an      btst    #0,d5              * check for odd opsize
            beq.s   .ok_sz
            move.b  #'^',(a4)+         * indicate invalid size
.ok_sz      bra     print_ea_an

.next2      dbra    d1,.next3
            btst    #4,5(a3)           * address register indirect, check if allowed
            bne.s   .print_ari
            move.b  #'?',(a4)+
.print_ari  move.b  #'(',(a4)+         * address register indirect
            bsr     print_ea_an
            move.b  #')',(a4)+
            rts

.next3      dbra    d1,.next4
            btst    #2,5(a3)           * ARI with post-decrement, check if allowed
            bne.s   .ok_anp
            move.b  #'?',(a4)+
.ok_anp     bsr.s   .print_ari
            move.b  #'+',(a4)+
            rts

.next4      dbra    d1,.next5
            btst    #3,5(a3)           * ARI with pre-decrement, check if allowed
            bne.s   .ok_anm
            move.b  #'?',(a4)+
.ok_anm     move.b  #'-',(a4)+
            bra.s   .print_ari

.next5      dbra    d1,.next6
            btst    #4,5(a3)           * ARI with 16 bit offset, check if allowed
            bne.s   .ok_ano
            move.b  #'?',(a4)+
.ok_ano     move.b  #'(',(a4)+
            move.w  (a2)+,d0           * offset
            move.b  #'$',(a4)+
            bsr     print_word         * print 16 bit offset
            move.b  #',',(a4)+
            move.w  d6,d0              * reload register number
            andi.b  #7,d0
            bsr     print_ea_an
            move.b  #')',(a4)+
            rts

.next6      dbra    d1,mode7
            btst    #4,5(a3)           * ARI with index and 8 bit offset, check if allowed
            bne.s   .ok_anx
            move.b  #'?',(a4)+
.ok_anx     move.b  #'(',(a4)+
            move.w  (a2)+,d0           * extension word (not checked, since 68000 doesn't neither)
            tst.b   d0                 * don't print zero offset
            beq.s   .skip_zero
            move.b  #'$',(a4)+
            bsr     print_byte         * print 8 bit offset
            move.b  #',',(a4)+
.skip_zero  move.w  d6,d0              * reload register number
            andi.b  #7,d0
            bsr     print_ea_an
            move.b  #',',(a4)+
            move.w  -2(a2),d1          * reload extension word
print_index rol.w   #4,d1              * entry for PC-relative
            bsr     print_reg          * index register
            move.b  #'.',(a4)+
            btst    #15,d1             * size flag of extension word
            beq.s   .word
            move.b  #'L',(a4)+
            bra.s   .cont
.word       move.b  #'W',(a4)+
.cont       move.b  #')',(a4)+
            rts

mode7       dbra    d0,.next71
            btst    #5,5(a3)           * absolute short, check if allowed
            bne.s   .ok_abs
            move.b  #'?',(a4)+
.ok_abs     move.b  #'$',(a4)+
            move.w  (a2)+,d0
            bsr     print_word
            move.b  #'.',(a4)+
            move.b  #'W',(a4)+
            rts

.next71     dbra    d0,.next72
            btst    #5,5(a3)           * absolute long, check if allowed
            bne.s   .ok_abl
            move.b  #'?',(a4)+
.ok_abl     move.b  #'$',(a4)+
            move.l  (a2)+,d0
            bsr     print_addr24
            move.b  #'.',(a4)+
            move.b  #'L',(a4)+
            rts

.next72     dbra    d0,.next73
            btst    #6,5(a3)           * PCR with 16 bit offset, check if allowed
            bne.s   .ok_pco
            move.b  #'?',(a4)+
.ok_pco     move.b  #'(',(a4)+
            move.w  (a2),d0
            ext.l   d0
            add.l   a2,d0
            lea     2(a2),a2
            move.b  #'$',(a4)+
            bsr     print_addr24       * print result address (PC+offset)
            lea     str_pc(pc),a1
            bsr     strapp
            move.b  #')',(a4)+
            rts

.next73     dbra    d0,.next74
            btst    #6,5(a3)           * PCR with index and 8 bit offset, check if allowed
            bne.s   .ok_pcx
            move.b  #'?',(a4)+
.ok_pcx     move.b  #'(',(a4)+
            move.b  1(a2),d0           * 8 bit offset
            ext.w   d0
            ext.l   d0
            add.l   a2,d0
            move.b  #'$',(a4)+
            bsr.s   print_addr24       * print result address (PC+offset)
            lea     str_pc(pc),a1
            bsr.s   strapp
            move.b  #',',(a4)+
            move.w  (a2)+,d1           * reload extension word
            bra     print_index

.next74     dbra    d0,.invalid_ea
            btst    #7,5(a3)           * immediate data, check if allowed
            bne.s   print_immediate
            move.b  #'?',(a4)+
            bra.s   print_immediate

.invalid_ea lea     str_inv_ea(pc),a1  * invalid adressing mode
            bra.s   strapp

print_immediate
            move.b  #'#',(a4)+         * immediate data, size in d5 must be set
print_displacement
            move.b  #'$',(a4)+
            cmpi.b  #4,d5
            beq.s   .long_imm
            cmpi.b  #2,d5
            beq.s   .word_imm
            move.w  (a2)+,d0           * byte immediate, ignoring high byte of data
            bra.s   print_byte
.word_imm   move.w  (a2)+,d0
            bra.s   print_word
.long_imm   move.l  (a2)+,d0           * fall thru!

*======================================================================
* Basic hex and string output routines
*======================================================================

print_long                             * Append hex long in d0 to buffer a4
            swap    d0
            bsr.s   print_word
            swap    d0
print_word                             * Append hex word in d0 to buffer a4
            rol.w   #8,d0
            bsr.s   print_byte
            ror.w   #8,d0
print_byte                             * Append hex byte in d0 to buffer a4
            move.b  d0,d2
            lsr.b   #4,d0
            bsr.s   print_nibble
            move.b  d2,d0
print_nibble                           * Append hex nibble in d0 to buffer a4
            andi.b  #$0f,d0
            cmpi.b  #10,d0
            blo.s   .digit
            addq.b  #7,d0
.digit      addi.b  #'0',d0
            move.b  d0,(a4)+
            rts

print_addr24                           * Print long in d0 as 24 bit address to buffer a4
            swap    d0
            bsr.s   print_byte
            swap    d0
            bra.s   print_word

strapp                                 * String append from a1 to a4
            move.b  (a1)+,(a4)+
            bne.s   strapp
            subq.l  #1,a4              * Ready to overwrite 0 terminator
            rts

*======================================================================
* More common parts output formatting routines
*======================================================================

print_size                             * Print size suffix in bits 7..6 of opcode
            move.b  #'.',(a4)+
            move.w  d4,d0
            andi.w  #$c0,d0
            lsr.w   #6,d0
            move.b  (size_names,pc,d0.w),(a4)+
            move.b  (sizes,pc,d0.w),d5
            move.b  #9,(a4)+           * TAB to operand section
            rts

size_names  dc.b    'BWL?'
sizes       dc.b    1,2,4,$ff

print_move_size                        * Print 'move' size suffix in bits 13..12 of opcode
            move.b  #'.',(a4)+
            move.w  d4,d0
            andi.w  #$3000,d0
            rol.w   #4,d0
            move.b  (msize_names,pc,d0.w),(a4)+
            move.b  (msizes,pc,d0.w),d5
            move.b  #9,(a4)+           * TAB to operand section
            rts

msize_names dc.b    '?BLW'
msizes      dc.b    $ff,1,4,2

print_bit6_size                        * Print .W/.L depending on size bit 6 of opcode
            move.b  #'.',(a4)+
            btst    #6,d4              * size flag in opcode (W/L)
            bsr.s   print_worl
            move.b  #9,(a4)+           * TAB to operand section
            rts

print_ea_an                            * Print address register with number in D0
            move.b  #'A',(a4)+
            bra     print_nibble

print_lo_areg_ind                      * Print address register in low opcode bits in parentheses
            move.b  #'(',(a4)+
            bsr.s   print_lo_areg
            move.b  #')',(a4)+
            rts

print_hi_areg_ind                      * Print address register in high opcode bits in parentheses
            move.b  #'(',(a4)+
            bsr.s   print_hi_areg
            move.b  #')',(a4)+
            rts

print_lo_dreg                          * Print data register in low opcode bits
            move.b  #'D',(a4)+
            bra.s   print_lo_reg

print_lo_areg                          * Print address register in low opcode bits
            move.b  #'A',(a4)+
            bra.s   print_lo_reg

print_hi_dreg                          * Print data register in high opcode bits
            move.b  #'D',(a4)+
            bra.s   print_hi_reg

print_hi_areg                          * Print address register in high opcode bits
            move.b  #'A',(a4)+
            bra.s   print_hi_reg

print_lo_reg                           * Print register number in 2..0 bits of opcode
            move.w  d4,d0
            andi.w  #$0007,d0
            bra     print_nibble

print_hi_reg                           * Print register number in 11..9 bits of opcode
            move.w  d4,d0
            andi.w  #$0e00,d0
            bra.s   print_mids

print_tiny                             * Print tiny constant in 11..9 bits of opcode, 0 becomes 8
            move.b  #'#',(a4)+
            move.w  d4,d0
            andi.w  #$0e00,d0
            bne.s   print_mids
            bset    #12,d0             * Make 0 an 8
print_mids  rol.w   #7,d0              * lsr.w #9 --> rol.w #7
            bra     print_nibble

print_worl                             * print 'W' if Z=1, 'L' if Z=0, set opsize accordingly
            beq.s   .word
            moveq   #4,d5
            move.b  #'L',(a4)+
            rts
.word       moveq   #2,d5
            move.b  #'W',(a4)+
            rts

print_reg                              * Print register name in D1, 0-7 is D0-D7, 8-15 is A0-A7
            move.b  d1,d0
            btst    #3,d0
            bne.s   .addr_reg
            move.b  #'D',(a4)+
            bra.s   .cont
.addr_reg   move.b  #'A',(a4)+
.cont       andi.b  #$07,d0
            bra     print_nibble


print_list                             * Print register list for MOVEM
           * register list expected in D3
           *
           * Use state machine to compress contiguous register ranges:
           * Start state is 0, 17 mask bits are checked, last is always 0.
           *
           * State  0 = R not in list  1 = R in list
           * ======================================
           * 0      0                  1; print R
           * 1      2                  3; print -
           * 2      2                  1; print / R
           * 3      2; print R-1       3
           *
           *
            clr.b   d1                 * register nr
            moveq   #0,d2              * state
testbit     move.b  d4,d0
            andi.b  #$38,d0            * Check for pre-dec addr mode
            cmpi.b  #$20,d0
            beq.s   .reverse
            lsr.w   #1,d3
            bra.s   .cont
.reverse    lsl.w   #1,d3
.cont       bcs.s   got_1
got_0
            tst.b   d2                 * State 0, bit 0
            beq.s   next_bit

            cmpi.b  #1,d2              * State 1, bit 0 => State=2
            bne.s   .s02
            moveq   #2,d2
            bra.s   next_bit

.s02        cmpi.b  #2,d2              * State 2, bit 0
            beq.s   next_bit

            subq.b  #1,d1              * State 3, bit 0 => Print reg-1, State=2
            bsr.s   print_reg
            addq.b  #1,d1
            moveq   #2,d2
            bra.s   next_bit
got_1
            tst.b   d2                 * State 0, bit 1 => Print reg, State=1
            bne.s   .s11
            bsr.s   print_reg
            moveq   #1,d2
            bra.s   next_bit

.s11        cmpi.b  #1,d2              * State 1, bit 1 => Print "-", State=3
            bne.s   .s12
            move.b  #'-',(a4)+
            moveq   #3,d2
            bra.s   next_bit

.s12        cmpi.b  #2,d2              * State 2, bit 1 => Print "/", Print reg, State=1
            bne.s   next_bit           * State 3, bit 1 => nop
            move.b  #'/',(a4)+
            bsr.s   print_reg
            moveq   #1,d2

next_bit    addq.b  #1,d1
            cmpi.b  #17,d1             * one additional 0 to close open register ranges
            blo.s   testbit
            rts


*======================================================================
* Instruction decoding table: mask, match, allowed-ea, format-fct, opcode-str
* Allowed-ea byte bit mask, for move MSB src ea, LSB dst ea
*   0: Dn
*   1: An
*   2: (An)+
*   3: -(An)
*   4: (An),(d16,An),(d8,An,Xn)
*   5: xxx.W,xxx.L
*   6: (d16,PC),(d8,PC,Xn)
*   7: #data
*======================================================================
instructions

*----------------------------------------------------------------------
* $0... : immediates, bit operations, MOVEP
*----------------------------------------------------------------------
            dc.w    $ffff,$003c,$00,op_log_to_ccr-op_base,str_or-str_base
            dc.w    $ffff,$007c,$00,op_log_to_sr-op_base,str_or-str_base
            dc.w    $ff00,$0000,$3d,op_imm_size_ea-op_base,str_or-str_base
            dc.w    $ffff,$023c,$00,op_log_to_ccr-op_base,str_and-str_base
            dc.w    $ffff,$027c,$00,op_log_to_sr-op_base,str_and-str_base
            dc.w    $ff00,$0200,$3d,op_imm_size_ea-op_base,str_and-str_base
            dc.w    $ff00,$0400,$3d,op_imm_size_ea-op_base,str_sub-str_base
            dc.w    $ff00,$0600,$3d,op_imm_size_ea-op_base,str_add-str_base
            dc.w    $ffff,$0a3c,$00,op_log_to_ccr-op_base,str_eor-str_base
            dc.w    $ffff,$0a7c,$00,op_log_to_sr-op_base,str_eor-str_base
            dc.w    $ff00,$0a00,$3d,op_imm_size_ea-op_base,str_eor-str_base
            dc.w    $ff00,$0c00,$3d,op_imm_size_ea-op_base,str_cmp-str_base
            dc.w    $f1b8,$0108,$00,op_movep_ay_dx-op_base,str_move-str_base
            dc.w    $f1b8,$0188,$00,op_movep_dx_ay-op_base,str_move-str_base
            dc.w    $ffc0,$0800,$7d,op_bit_imm_ea-op_base,str_btst-str_base * sic, #imm illegal
            dc.w    $ffc0,$0840,$3d,op_bit_imm_ea-op_base,str_bchg-str_base
            dc.w    $ffc0,$0880,$3d,op_bit_imm_ea-op_base,str_bclr-str_base
            dc.w    $ffc0,$08c0,$3d,op_bit_imm_ea-op_base,str_bset-str_base
            dc.w    $f1c0,$0100,$fd,op_bit_dn_ea-op_base,str_btst-str_base * sic, #imm allowed
            dc.w    $f1c0,$0140,$3d,op_bit_dn_ea-op_base,str_bchg-str_base
            dc.w    $f1c0,$0180,$3d,op_bit_dn_ea-op_base,str_bclr-str_base
            dc.w    $f1c0,$01c0,$3d,op_bit_dn_ea-op_base,str_bset-str_base
*----------------------------------------------------------------------
* $1... : MOVE.B
* $2... : MOVE.L
* $3... : MOVE.W
*----------------------------------------------------------------------
            dc.w    $c1c0,$0040,$ff02,op_move-op_base,str_movea-str_base
            dc.w    $c000,$0000,$ff3d,op_move-op_base,str_move-str_base
*----------------------------------------------------------------------
* $4... : a grabbag
*----------------------------------------------------------------------
            dc.w    $ffc0,$40c0,$3d,op_from_sr-op_base,str_move-str_base
            dc.w    $ffc0,$44c0,$fd,op_to_ccr-op_base,str_move-str_base
            dc.w    $ffc0,$46c0,$fd,op_to_sr-op_base,str_move-str_base
            dc.w    $ff00,$4000,$3d,op_simple_size_ea-op_base,str_negx-str_base
            dc.w    $ff00,$4200,$3d,op_simple_size_ea-op_base,str_clr-str_base
            dc.w    $ff00,$4400,$3d,op_simple_size_ea-op_base,str_neg-str_base
            dc.w    $ff00,$4600,$3d,op_simple_size_ea-op_base,str_not-str_base
            dc.w    $ffb8,$4880,$00,op_sz_dn-op_base,str_ext-str_base
            dc.w    $fff8,$4840,$00,op_dn-op_base,str_swap-str_base
            dc.w    $ffc0,$4800,$3d,op_simple_ea1-op_base,str_nbcd-str_base
            dc.w    $ffc0,$4840,$70,op_simple_ea4-op_base,str_pea-str_base
            dc.w    $ffff,$4afc,$00,op_simple-op_base,str_illegal-str_base
            dc.w    $ffc0,$4ac0,$3d,op_simple_ea1-op_base,str_tas-str_base
            dc.w    $ff00,$4a00,$3d,op_simple_size_ea-op_base,str_tst-str_base * sic, no An,(d,PC),#imm EA
            dc.w    $fff0,$4e40,$00,op_trap-op_base,str_trapv-str_base
            dc.w    $fff8,$4e50,$00,op_an_size-op_base,str_link-str_base
            dc.w    $fff8,$4e58,$00,op_an-op_base,str_unlk-str_base
            dc.w    $fff8,$4e60,$00,op_an_usp-op_base,str_move-str_base
            dc.w    $fff8,$4e68,$00,op_usp_an-op_base,str_move-str_base
            dc.w    $ffff,$4e70,$00,op_simple-op_base,str_reset-str_base
            dc.w    $ffff,$4e71,$00,op_simple-op_base,str_nop-str_base
            dc.w    $ffff,$4e72,$00,op_imm2-op_base,str_stop-str_base
            dc.w    $ffff,$4e73,$00,op_simple-op_base,str_rte-str_base
            dc.w    $ffff,$4e75,$00,op_simple-op_base,str_rts-str_base
            dc.w    $ffff,$4e76,$00,op_simple-op_base,str_trapv-str_base
            dc.w    $ffff,$4e77,$00,op_simple-op_base,str_rtr-str_base
            dc.w    $ffc0,$4e80,$70,op_simple_ea4-op_base,str_jsr-str_base
            dc.w    $ffc0,$4ec0,$70,op_simple_ea4-op_base,str_jmp-str_base
            dc.w    $ff80,$4880,$38,op_mvm_list_ea-op_base,str_move-str_base
            dc.w    $ff80,$4c80,$74,op_mvm_ea_list-op_base,str_move-str_base
            dc.w    $f1c0,$41c0,$70,op_ea4_an-op_base,str_lea-str_base
            dc.w    $f1c0,$4180,$fd,op_ea2_dn-op_base,str_chk-str_base
*----------------------------------------------------------------------
* $5... : ADDQ, SUBQ, Scc, DBcc
*----------------------------------------------------------------------
            dc.w    $f0f8,$50c8,$00,op_dbcc_dn-op_base,str_db-str_base
            dc.w    $f0c0,$50c0,$3d,op_scc_ea-op_base,str_s-str_base
            dc.w    $f100,$5000,$3f,op_size_tiny_ea-op_base,str_add-str_base
            dc.w    $f100,$5100,$3f,op_size_tiny_ea-op_base,str_sub-str_base
*----------------------------------------------------------------------
* $6... : BRA, BSR, Bcc
*----------------------------------------------------------------------
            dc.w    $ff00,$6000,$00,op_branch-op_base,str_bra-str_base
            dc.w    $ff00,$6100,$00,op_branch-op_base,str_bsr-str_base
            dc.w    $f000,$6000,$00,op_cbranch-op_base,str_b-str_base
*----------------------------------------------------------------------
* $7... : MOVEQ
*----------------------------------------------------------------------
            dc.w    $f100,$7000,$00,op_moveq-op_base,str_moveq-str_base
*----------------------------------------------------------------------
* $8... : OR, DIV, SBCD
*----------------------------------------------------------------------
            dc.w    $f1f8,$8100,$00,op_ext_dn-op_base,str_sbcd-str_base
            dc.w    $f1f8,$8108,$00,op_ext_an-op_base,str_sbcd-str_base
            dc.w    $f1c0,$80c0,$fd,op_ea2_dn-op_base,str_divu-str_base
            dc.w    $f1c0,$81c0,$fd,op_ea2_dn-op_base,str_divs-str_base
            dc.w    $f100,$8000,$fd,op_size_ea_dn-op_base,str_or-str_base
            dc.w    $f100,$8100,$3c,op_size_dn_ea-op_base,str_or-str_base
*----------------------------------------------------------------------
* $9... : SUB, SUBX, SUBA
*----------------------------------------------------------------------
            dc.w    $f0c0,$90c0,$ff,op_size_ea_an-op_base,str_sub-str_base
            dc.w    $f138,$9100,$00,op_size_ext_dn-op_base,str_sub-str_base
            dc.w    $f138,$9108,$00,op_size_ext_an-op_base,str_sub-str_base
            dc.w    $f100,$9000,$ff,op_size_ea_dn-op_base,str_sub-str_base
            dc.w    $f100,$9100,$3c,op_size_dn_ea-op_base,str_sub-str_base
*----------------------------------------------------------------------
* $A... : Reserved, line A emulation
*----------------------------------------------------------------------
            dc.w    $f000,$a000,$00,op_unknown-op_base,str_line_a-str_base
*----------------------------------------------------------------------
* $B... : EOR, CMP, CMPA, CMPM
*----------------------------------------------------------------------
            dc.w    $f0c0,$b0c0,$ff,op_size_ea_an-op_base,str_cmp-str_base
            dc.w    $f138,$b108,$00,op_size_cmpm-op_base,str_cmpm-str_base
            dc.w    $f100,$b000,$ff,op_size_ea_dn-op_base,str_cmp-str_base
            dc.w    $f100,$b100,$3d,op_size_dn_ea-op_base,str_eor-str_base * sic!
*----------------------------------------------------------------------
* $C... : AND, MUL, ABCD, EXG
*----------------------------------------------------------------------
            dc.w    $f1f8,$c140,$00,op_dx_dy-op_base,str_exg-str_base
            dc.w    $f1f8,$c148,$00,op_ax_ay-op_base,str_exg-str_base
            dc.w    $f1f8,$c188,$00,op_dx_ay-op_base,str_exg-str_base
            dc.w    $f1f8,$c100,$00,op_ext_dn-op_base,str_abcd-str_base
            dc.w    $f1f8,$c108,$00,op_ext_an-op_base,str_abcd-str_base
            dc.w    $f1c0,$c0c0,$fd,op_ea2_dn-op_base,str_mulu-str_base
            dc.w    $f1c0,$c1c0,$fd,op_ea2_dn-op_base,str_muls-str_base
            dc.w    $f100,$c000,$fd,op_size_ea_dn-op_base,str_and-str_base
            dc.w    $f100,$c100,$3c,op_size_dn_ea-op_base,str_and-str_base
*----------------------------------------------------------------------
* $D... : ADD, ADDX, ADDA
*----------------------------------------------------------------------
            dc.w    $f0c0,$d0c0,$ff,op_size_ea_an-op_base,str_add-str_base
            dc.w    $f138,$d100,$00,op_size_ext_dn-op_base,str_add-str_base
            dc.w    $f138,$d108,$00,op_size_ext_an-op_base,str_add-str_base
            dc.w    $f100,$d000,$ff,op_size_ea_dn-op_base,str_add-str_base
            dc.w    $f100,$d100,$3c,op_size_dn_ea-op_base,str_add-str_base
*----------------------------------------------------------------------
* $E... : shifts and rotates
*----------------------------------------------------------------------
            dc.w    $ffc0,$e0c0,$3c,op_simple_ea2-op_base,str_asr-str_base
            dc.w    $ffc0,$e1c0,$3c,op_simple_ea2-op_base,str_asl-str_base
            dc.w    $ffc0,$e2c0,$3c,op_simple_ea2-op_base,str_lsr-str_base
            dc.w    $ffc0,$e3c0,$3c,op_simple_ea2-op_base,str_lsl-str_base
            dc.w    $ffc0,$e4c0,$3c,op_simple_ea2-op_base,str_roxr-str_base
            dc.w    $ffc0,$e5c0,$3c,op_simple_ea2-op_base,str_roxl-str_base
            dc.w    $ffc0,$e6c0,$3c,op_simple_ea2-op_base,str_ror-str_base
            dc.w    $ffc0,$e7c0,$3c,op_simple_ea2-op_base,str_rol-str_base
            dc.w    $f118,$e000,$00,op_shift-op_base,str_asr-str_base
            dc.w    $f118,$e100,$00,op_shift-op_base,str_asl-str_base
            dc.w    $f118,$e008,$00,op_shift-op_base,str_lsr-str_base
            dc.w    $f118,$e108,$00,op_shift-op_base,str_lsl-str_base
            dc.w    $f118,$e010,$00,op_shift-op_base,str_roxr-str_base
            dc.w    $f118,$e110,$00,op_shift-op_base,str_roxl-str_base
            dc.w    $f118,$e018,$00,op_shift-op_base,str_ror-str_base
            dc.w    $f118,$e118,$00,op_shift-op_base,str_rol-str_base
*----------------------------------------------------------------------
* $F... : Reserved, line F co-processor emulation
*----------------------------------------------------------------------
            dc.w    $f000,$f000,$00,op_unknown-op_base,str_line_f-str_base
*----------------------------------------------------------------------
* $.... : undefined opcode
*----------------------------------------------------------------------
            dc.w    $0000,$0000,$00,op_unknown-op_base,str_unknown-str_base

*======================================================================
* Opcode and other strings
*======================================================================
str_abcd         dc.b    "ABCD",0
str_add          dc.b    "ADD",0
str_and          dc.b    "AND",0
str_asl          dc.b    "ASL",0
str_asr          dc.b    "ASR",0
str_bchg         dc.b    "BCHG",0
str_bclr         dc.b    "BCLR",0
str_bra          dc.b    "BRA",0
str_bset         dc.b    "BSET",0
str_bsr          dc.b    "BSR",0
str_btst         dc.b    "BTST",0
str_chk          dc.b    "CHK",0
str_clr          dc.b    "CLR",0
str_cmp          dc.b    "CMP",0
str_cmpm         dc.b    "CMPM",0
str_db           dc.b    "DB",0
str_divs         dc.b    "DIVS",0
str_divu         dc.b    "DIVU",0
str_eor          dc.b    "EOR",0
str_exg          dc.b    "EXG",0
str_ext          dc.b    "EXT",0
str_illegal      dc.b    "ILLEGAL",0
str_jmp          dc.b    "JMP",0
str_jsr          dc.b    "JSR",0
str_lea          dc.b    "LEA",0
str_link         dc.b    "LINK",0
str_lsl          dc.b    "LSL",0
str_lsr          dc.b    "LSR",0
str_move         dc.b    "MOVE",0
str_movea        dc.b    "MOVEA",0
str_moveq        dc.b    "MOVEQ",0
str_muls         dc.b    "MULS",0
str_mulu         dc.b    "MULU",0
str_nbcd         dc.b    "NBCD",0
str_neg          dc.b    "NEG",0
str_negx         dc.b    "NEGX",0
str_nop          dc.b    "NOP",0
str_not          dc.b    "NOT",0
str_pea          dc.b    "PEA",0
str_reset        dc.b    "RESET",0
str_rol          dc.b    "ROL",0
str_ror          dc.b    "ROR",0
str_roxl         dc.b    "ROXL",0
str_roxr         dc.b    "ROXR",0
str_rte          dc.b    "RTE",0
str_rtr          dc.b    "RTR",0
str_rts          dc.b    "RTS",0
str_sbcd         dc.b    "SBCD",0
str_stop         dc.b    "STOP",0
str_sub          dc.b    "SUB",0
str_swap         dc.b    "SWAP",0
str_tas          dc.b    "TAS",0
str_tst          dc.b    "TST",0
str_trapv        dc.b    "TRAPV",0
str_unlk         dc.b    "UNLK",0

str_dcw          dc.b    "DC.W",0
str_line_a       dc.b    "; line A",0
str_line_f       dc.b    "; line F",0
str_unknown      dc.b    "; ?op",0
str_ccr          dc.b    "CCR",0
str_usp          dc.b    "USP",0
str_inv_ea       dc.b    "?ea",0
str_pc           dc.b    ",PC",0
                                       * Some common suffix optimizations
str_or           equ     str_eor+1
str_s            equ     str_rts+2
str_b            equ     str_sub+2
str_sr           equ     str_bsr+1

str_base         equ     str_abcd      * Start of string table

*======================================================================
* End of Disassembler
*======================================================================