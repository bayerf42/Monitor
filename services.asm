;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Time critical and assembly code for the 680008 kit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

            section code

trace_bit   equ     7
system_bit  equ     5


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; service interrupt level 2 for 68008 kit
;;; increment tick every 10ms
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

service_tick
            addq.l  #1,_tick.w
            rte


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Trace handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

service_trace
            move.w  #$2700,sr
            movem.l d0-d7/a0-a6,_user_data.w
            move.w  (a7)+,_user_sr.w
            move.l  (a7)+,a1
            move.l  a7,_user_ssp.w
            move.l  usp,a0
            move.l  a0,_user_usp.w
            move.l  a1,_user_pc.w
            move.l  a1,_display_PC.w
            move.l  a1,_save_PC.w
            move.l  a1,_curr_inst.w

            ; Check for matching breakpoint
            move.w  _num_bp.w,d0
            lea     _break_points.w,a0
            bra.s   .loop
.next       cmpa.l  (a0)+,a1
            beq.s   to_monitor
.loop       dbf     d0,.next

            ; Check if the active SP has reached auto-step level again
            tst.b   _frame_origin.w
            bne.s   .user_mode
            move.l  _user_ssp.w,a0
            bra.s   .cont
.user_mode  move.l  _user_usp.w,a0
.cont       tst.b   _step_mode.w
            bne.s   returning

            cmpa.l  _call_frame.w,a0
            blo     rest_regs          ; auto-step when still in call frame

            ; SP has reached original level -> return to monitor
to_monitor  jsr     _key_address
            jmp     main_1

returning   cmpa.l  _call_frame.w,a0   ; stepping out
            bls     rest_regs
            bra.s   to_monitor


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TRAP #0 handler (return to monitor)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

service_trap0
            move.w  #$2700,sr
            movem.l d0-d7/a0-a6,_user_data.w
            move.w  (a7)+,_user_sr.w
            move.l  (a7)+,a1
service_cont
            move.l  a7,_user_ssp.w
            move.l  usp,a0
            move.l  a0,_user_usp.w
            move.l  a1,_user_pc.w
            move.l  a1,_display_PC.w
            move.l  a1,_save_PC.w
            move.l  a1,_curr_inst.w

            bsr     _disarm_breakpoints
            jsr     _key_address
            jmp     main_1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TRAP #1 handler (static breakpoints)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

service_trap1
            tst.b   _enable_trap1.w
            bne.s   service_trap0
            rte


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; TRAP #3 handler (dynamic breakpoints)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

service_trap3
            move.w  #$2700,sr
            movem.l d0-d7/a0-a6,_user_data.w
            move.w  (a7)+,_user_sr.w
            move.l  (a7)+,a1
            subq.l  #2,a1              ; adjust PC to re-execute broken opcode
            bra.s   service_cont


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Standard exception handlers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

service_bus_err
            move.b  #$2,_exception_nr.w
            bra.s   ext_exception      ; Extended stack frame

service_addr_err
            move.b  #$3,_exception_nr.w
            bra.s   ext_exception      ; Extended stack frame

service_illegal
            move.b  #$4,_exception_nr.w
            bra.s   std_exception

service_div0
            move.b  #$5,_exception_nr.w
            bra.s   std_exception

service_check
            move.b  #$6,_exception_nr.w
            bra.s   std_exception

service_trapv
            move.b  #$7,_exception_nr.w
            bra.s   std_exception

service_priv
            move.b  #$8,_exception_nr.w
            bra.s   std_exception

service_line_a
            move.b  #$a,_exception_nr.w
            bra.s   std_exception

service_line_f
            move.b  #$b,_exception_nr.w
            bra.s   std_exception

service_interrupts
            move.b  #$c,_exception_nr.w
            bra.s   std_exception

service_traps
            move.b  #$d,_exception_nr.w
            bra.s   std_exception

ext_exception
            addq.l  #8,a7              ; adjust for extra stuff on stack
std_exception
            move.w  #$2700,sr
            movem.l d0-d7/a0-a6,_user_data.w
            move.w  (a7)+,_user_sr.w
            move.l  (a7)+,a1
            move.l  a7,_user_ssp.w
            move.l  usp,a0
            move.l  a0,_user_usp.w
            move.l  a1,_user_pc.w
            move.l  a1,_display_PC.w
            move.l  a1,_save_PC.w
            move.l  a1,_curr_inst.w

            bsr     _disarm_breakpoints
            jsr     _print_exception
            jmp     main_1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Temporary trace handler for GO from breakpoint
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

service_step_then_go
            move.w  #$2700,sr
            movem.l d0-d7/a0-a6,_user_data.w
            move.w  (a7)+,_user_sr.w
            move.l  (a7)+,a1
            move.l  a7,_user_ssp.w
            move.l  usp,a0
            move.l  a0,_user_usp.w
            move.l  a1,_user_pc.w
            move.l  a1,_display_PC.w
            move.l  a1,_save_PC.w
            move.l  a1,_curr_inst.w
            move.l  #service_trace,$24   ; restore original vector
            bra.s   _go


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Start execution in stepping mode
;;;
;;; step_cont:   execute unbounded steps
;;; step_over:   execute while SP is lower (over calls)
;;; step_out:    execute until SP is higher (after return)
;;; step_into:   execute exactly one step (into calls)
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_step_into
            clr.l   _call_frame.w             ; never auto-step, make SP check succeed always
            bra.s   step_cont

_step_cont
            move.l  #$fffffffe,_call_frame.w  ; always auto-step, make SP check fail always
            bra.s   step_cont

_step_out
            st      _step_mode.w
            bra.s   step_common

_step_over
            sf      _step_mode.w
            ; Establish stack frame in which auto-stepping is enabled
step_common btst    #system_bit,_user_sr.w
            seq     _frame_origin.w    ; store origin of stack frame
            beq.s   .user_mode
            move.l  _user_ssp.w,_call_frame.w
            bra.s   step_cont
.user_mode  move.l  _user_usp.w,_call_frame.w
step_cont   bset    #trace_bit,_user_sr.w
            bra.s   rest_regs


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GO (continue execution at full speed)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_go
            bsr.s   _arm_breakpoints
            bclr    #trace_bit,_user_sr.w

rest_regs   move.l  _display_PC.w,d0
            btst    #0,d0
            bne.s   odd_pc
            move.l  d0,_user_pc.w
            move.l  _user_usp.w,a0
            move.l  a0,usp
            movem.l _user_data.w,d0-d7/a0-a6
            move.l  _user_ssp.w,a7       ; restore SP, CCR and PC
            move.l  _user_pc.w,-(a7)
            move.w  _user_sr.w,-(a7)
            rte

            ; We arrive here when restoring an odd PC (which should never happen...)
            ; So when the user presses PC to show the guilty instruction and
            ; tries to continue from here, we display message accordingly.

odd_pc      jsr     _print_odd_pc
            jmp     main_1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Execute one instruction in step mode and GO afterwards
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_step_then_go
            move.l  #service_step_then_go,$24 ; temporary vector for trace
            bra.s   step_cont


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Arm/disarm breakpoints
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_arm_breakpoints
            tst.b   _bp_armed.w
            bne.s   .done
            move.w  _num_bp.w,d0
            lea     _break_points.w,a0
            lea     _orig_instr.w,a2
            bra.s   .loop
.next       movea.l (a0)+,a1
            move.w  (a1),(a2)+           ; save original opcode
            move.w  #$4e43,(a1)          ; patch with TRAP #3
.loop       dbf     d0,.next
            st      _bp_armed.w
.done       rts

_disarm_breakpoints
            tst.b   _bp_armed.w
            beq.s   .done
            move.w  _num_bp.w,d0
            lea     _break_points.w,a0
            lea     _orig_instr.w,a2
            bra.s   .loop
.next       movea.l (a0)+,a1
            move.w  (a2)+,(a1)           ; restore original opcode
.loop       dbf     d0,.next
            sf      _bp_armed.w
.done       rts


; call from c program to make mask level to 1

_enable_level2
            move.w  #$2100,sr
            rts
