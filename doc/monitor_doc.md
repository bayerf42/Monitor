Monitor program for the Sirichote 68008 Kit
===========================================
This document describes the major modifications and additions to the monitor program made by me.
The new monitor V4.8 is based on V3, which includes the faster 9600 Baud software UART.
All existing features are still available, most new ones use the **REG** key as a prefix, which
is displayed as `SHIFT` on the LEDs.
Though the new features take advantage of the LCD and a terminal connection, they also work
with the bare board.

Summary of enhancements
-----------------------
1. Register editing
2. Disassembling opcode on LCD
3. Dumping info to the terminal
4. Interfacing to user programs
5. Error handling
6. Stepping and breakpoints


Register editing
================
All data and address registers can be modified, too.
To do this press the **DATA** button when displaying a register.
The display now shows dots and the new value can be entered with the hex keys.

To exit register input, press any other key, or **REG** to display/edit another register.


Data registers
--------------
Press **DATA** once to input a new _long_ value, press **DATA** twice to input a _word_ value
(leaving the upper bits intact) or press **DATA** thrice to input a _byte_ value (dito).

The dots indicate which part of the data register will be changed. 


Address registers
-----------------
Address register now also display all 32 bits like data registers, but only the entire value can
be input.

**A7** is the user stack pointer when in user mode or the system stack pointer
when in system mode.

When displaying or editing an address register you can go to the memory byte pointed to
by pressing the **ADDR** key. Now its contents becomes the current address and you can modify
it or start program execution etc.

For example, if you want to dump the stack to the terminal, press **REG**, **A7**, **ADDR**, and
**DUMP**.


Status register
---------------
The status register cannot be modified. If you really want to do so, you can edit monitor variable
at `002ea` where the status register is stored.

The format of status register display can be selected with the monitor variable `show_sr` at
`002fa`. Possible formats:

|Value | Name     | Part      | Format                                   |
|------|----------|-----------|------------------------------------------|
|0     | classic  | CCR only  | using 0/1 for XNZVC                      |
|1     | numeric  | entire SR | 16 bit hexadecimal                       |  
|2     | symbolic | entire SR | formatted as in terminal dump, see below |


Disassembling opcode on LCD
===========================
The instruction at the current address is displayed as disassembly on the LCD automatically. The
details of the disassembly format are described at the end of this document.

When advancing through the memory forward (via the **+** key), the start of the instruction in
memory can be determined correctly, so even for multiword instructions you can navigate through
each byte of the instruction with the **+** and **-** keys and even modify the operands and
instantly see the effect in the disassembly.

However, when you go beyond a multiword instruction with **+** and immediately back with **-**,
the beginning of the instruction is lost and you see the operand interpreted as an instruction.
In this case, you have to go back far enough with the **-** key to synchronize again.

If you want to control the LCD yourself and avoid that the monitor overwrites the LCD
with the disassembly, you can switch monitor output off by writing 0 into monitor variable
`disasm_on_lcd` at address `00270`.

The monitor currently assumes a 16x2 LCD, but other sizes can be used, too, and you have to set the
size in `lcd_width` at `00300` and `lcd_lines` at `00302` once after power-up. 


Dumping info to the terminal
============================
Registers
---------
By pressing the keys **REG** and **DUMP** you can dump the registers to the terminal. Typical
output looks like
```
D0: 00000001 00000001 00000000 F79FA9DE FFF77FF9 FD652CBE C7F8DF59 9FF6FF7E
A0: 00001A5E 00001A70 9EFF9B7B FF8FEFFB 7FFEEFF6 FCBE3AFE 0001FFAC 00020000
SR: A704     TS7--Z--     USP: 0001FC00     SSP: 00020000
0000045C: 670A                       BEQ.S      $000468
```
The first line shows the data registers D0-D7, the second line the address registers A0-A6 and
the currently active stack pointer, the third line the status register numerically and in
symbolic form (in the example: trace and system mode, interrupt level 7, zero flag) and both
stack pointers. The fourth line shows the PC and the current instruction as machine code and
disassembly.


Disassembler listing
--------------------
By pressing the keys **REG** and **REL** you can list machine code starting at the current PC
as disassembly to the terminal. This will advance the current (displayed) address accordingly,
so pressing those keys again will list the following instructions, but the saved PC is not modified,
so you can return to it with the **PC** key.

The number of instructions listed can be set with the monitor variable `disasm_lines`
at address `0026c` (see `monitor4x.inc`)

Similarily, the number of lines output by the standard **DUMP** command can be set with the
monitor variable `hexdump_lines` at address `0026e`.

If a breakpoint is set at the instruction disassembled, an asterisk is printed after the
address.


Breakpoint listing
------------------
By pressing the keys **REG** and **LOAD** you can list all dynamic breakpoints (see below)
as disassembly (one line per breakpoint) to the terminal.


Line feed
---------
By pressing the keys **REG** and **+** you can send a line feed to the terminal.
 

Interfacing to user programs
============================
Jumptable to useful monitor routines
------------------------------------
There are several useful routines in ROM, which should be available to the user. However, when
recompiling the monitor, their entry addresses change and user programs using them would have to be
modified accordingly. So I put a jump table at the very beginning of the monitor code which
delegates to the actual ROM routines. The position of the jump table itself will stay fixed in
future versions of the monitor, so user programs don't have to be adapted.


C and Assembler include files for monitor routines and variables
----------------------------------------------------------------
In the directory `include` are files for C `monitor4x.h` and assembler `monitor4x.inc`
defining symbolic names for the monitor routines and for useful system variables.
Look in the `examples` directory how those routines can be called from your program.

The functions defined here use the jump table mentioned above, so your programs using them will
still work without re-compilation with future versions of the monitor.


Monitor configuration variables
-------------------------------
There are some monitor variables (also defined in the include files mentioned above)
which allow configuration of monitor behavior. These include LCD size, SR display mode,
number of output lines for dumping, and UART speed. 

These variables are defaulted at power-up and you can modify them simply with the memory editor,
or by a user program. Their contents survive **RESET**.

In C, these variables are pointers, so they must be accessed with the `*` operator.  

Be careful not to modify other RAM locations in the range `00200` to `003ff`!


New `cstart_sbc.asm`
--------------------
The original CSTART library `C:/Ide68k/Lib/cstart.asm` defines basic OS functions like
`__getch` and `__putch` to be used by the simulator. I extended it to call the terminal
functions for sending and receiving single characters when running on the 68008 Kit.
The new CSTART library is now at `Lib/cstart_sbc.asm` which you should use in your
C project files instead of the original.

This new CSTART determines if it's running on the Ide68k simulator or on the actual 68008 Kit and
calls the proper I/O routines accordingly. When you use it in your C `.prj` file instead of
the old CSTART library, the compiled HEX file will run on the Ide68k simulator as well as
on the actual 68008 Kit.

The new CSTART also contains C entries to monitor routines via the jump table mentioned above.
These entries could have been put into their own library, but have been included here for
simplicity. Of course these routines won't work in the Ide68k simulator.


Patched `std68k.lib`
--------------------
The original library `std68k.lib` uses `TRAP #0` to implement `setjmp/longjmp`.
This conflicts with 68008 Kit use of `TRAP #0` to return to the monitor.
So the library has been patched to use `TRAP #2` instead and is now at `Lib/std68k_patched.lib`. 

You need this patch only if
1. you use `setjmp/longjmp` at all in your C code
2. you want to single step through `setjmp/longjmp`

Have a look at the sample project `examples/test_setjmp.prj`.


Error handling
==============
Handlers for all standard exceptions have been added to avoid crashes.
They simply display the exception type encountered. You can press the **PC** key to see
the instruction (or the next depending on exception type) which caused the exception.
Handled are:

| Exception           | Number | LED display | Actually used for    |
| ------------------- | ------:| ----------- | -------------------- |
| Bus error           |      2 | `Err bUS`   |                      |
| Address error       |      3 | `Err Addr`  |                      |
| Illegal instruction |      4 | `Err ILLE`  |                      |
| Division by zero    |      5 | `Err div0`  |                      |
| CHK out of bounds   |      6 | `Err CHk`   |                      |
| TRAPV overflow      |      7 | `Err trPv`  |                      |
| Privilege violation |      8 | `Err Priv`  |                      |
| Trace               |      9 |             | Stepping             |
| Line A emulation    |     10 | `Err LinA`  |                      |
| Line F emulation    |     11 | `Err LinF`  |                      |
| Interrupt level 2   |     26 |             | **IRQ**, 100 Hz tick |
| other interrupts    |  24-31 | `Err Intr`  |                      | 
| TRAP #0             |     32 |             | Return to monitor    |
| TRAP #1             |     33 |             | Static breakpoint    |
| TRAP #3             |     35 |             | Dynamic breakpoint   |
| other traps         |  32-47 | `Err trAP`  |                      | 

Since those exception vectors are in RAM you can still redefine them for your needs. 

Even with those handlers your program can still crash, especially when it's running in
system mode and the stack pointer is moved beyond RAM.


Stepping and breakpoints
========================
Please note, that all stepping functions and breakpoints work transparently in both system
and user mode, using the correct stack pointer.

Stepping over subroutine calls and traps
----------------------------------------
The **STEP** key lets you execute one single instruction at a time. When you step a `JSR` or
`BSR` instruction, it goes into the subroutine and lets you execute every single instruction.
(We call this _stepping into_)

Since V4.5 you can also step with the **USER** key, but this _steps over_ subroutine calls
and stops at the instruction thereafter.

In fact, stepping stops when the stack pointer has reached the level (or higher) it had before
pressing **USER**. So when an instruction doesn't modify the stack pointer, _stepping over_ stops
immediately. However, when the instruction pushes something onto the stack, stepping continues
until the data is popped off the stack, regardless if it was a return address or
something completely different.

For example, in this code fragment (taken from `examples/test9.asm`)
```
00000410: 3603                       MOVE.W     D3,D3
00000412: 4878 04D2                  PEA        $04D2.W
00000416: 42A7                       CLR.L      -(A7)
00000418: 610E                       BSR.S      $000428
0000041A: 3804                       MOVE.W     D4,D4
0000041C: DEFC 0008                  ADDA.W     #$0008,A7
00000420: 3A05                       MOVE.W     D5,D5
```
_stepping over_ at `00418` will step through the subroutine call and stop at `0041A`. However,
_stepping over_ at `00412` will step through the parameter pushes, the call, and the parameter
cleanup in `0041C` and stop at `00420`, thus covering the entire call sequence.

If during _stepping over_ a subroutine a trap is encountered, your program will stop there as usual.

Note that _stepping over_ is much slower than normal execution, since a trace exception is
handled after each processor instruction.

For your convenience, you can also skip over `TRAP #0` or `TRAP #1` (see below) instructions
with the **USER** key. Pressing **STEP** here would enter the trap handler, which is probably
not what you want to do.


Stepping out of subroutine call
-------------------------------
The new _step out_ command (since V4.6) is invoked by pressing **REG** **USER** and steps until
a subroutine returns and stops after the original call. (Or more generally, stops, when the
stack pointer increases)

So in the example above, when you _stepped into_ the subroutine at `00418` by pressing **STEP**,
before V4.6 you would have to step through the entire subroutine in single steps, but now you can
press **REG** **USER** to do this automatically and the monitor will stop at `0041A`, after
the call.

When you are in the main program (so the stack is empty) _step out_ displays an error message
`toP SP`.


Stepping indefinitely
---------------------
The new _step continue_ command (since V4.7) is invoked by pressing **REG** **STEP**
and starts program execution at the current address like **GO** but in trace mode,
so it is much slower. This command has been added for completeness and may occasionally
be useful since it stops at dynamic breakpoints (see below) in ROM, in contrast to **GO**.


Static breakpoints
------------------
You can use `TRAP #1` instructions (or in C the `_trap(1)` pseudo-function) to include breakpoints
in your code. On default, these breakpoints are disabled and your program skips over them. But
by the key combination **REG** **COPY** you can enable/disable them (displaying `trP1 On` or
`trP1 OFF`) and the monitor is invoked when your program encounters an active breakpoint,
just like `TRAP #0`.

When you step through your program, and you see that the next instruction is a `TRAP`,
you should step over it with the **USER** key, the **STEP** key would enter the trap handler.
If you accidently do so, you still can recover by
1. pressing **GO** in a `TRAP #0` or enabled `TRAP #1`, which actually executes the trap, so it
   stops afterwards
2. manually stepping through a disabled `TRAP #1` with **STEP** (just 3 instructions until
   after `RTE`), don't use **GO** here, it would start program execution and thus miss
   the instruction after the `TRAP #1` 


Dynamic breakpoints
-------------------
Since V4.7 you can use dynamic breakpoints, too. These breakpoints can be set ad hoc at arbitrary
memory addresses and program execution stops when a dynamic breakpoint is encountered.

You can set a breakpoint by pressing **REG** **INS** in the memory editor. A small square
appears between address and data on the LED to indicate a breakpoint. Note that breakpoints
can only be set at _even_ addresses. You should also make sure that you set a
breakpoint at the first byte of an actual instruction and not at an operand, otherwise strange
effects may result when the monitor patches the code.

Press **REG** **INS** again to remove the breakpoint at the current address. Or press
**REG** **DEL** to remove _all_ dynamic breakpoints at once.

A maximum of 8 breakpoints can be set, they survive **RESET** and downloading programs. Breakpoints
are _not_ copied or moved when you use the commands **COPY**, **INS** or **DEL**.

When you try to set a breakpoint and the small square doesn't appear, either all 8 breakpoints
have already been set or you are at an odd address.

Press **REG** **LOAD** to list all breakpoints to the terminal. Breakpoints are marked with an
asterisk after the address in disassembler listings.

The monitor handles dynamic breakpoints in 2 different ways:

### Full-speed execution
When you press **GO**, the breakpoint locations are patched with `TRAP #3` instructions and
execution starts at full speed until encountering the trap, which restores the original
instructions.


### Stepped execution
When you _step over_, _step out_ or _step continue_, the program is executed in trace mode
and breakpoints are checked by the monitor after each step.
Since no code patching is needed here, breakpoints even work in ROM code.


Command       | Key(s)           | Executes        | Speed     | Breakpoint impl. | Stop at BP in ROM
---           | ---              | ---             | ---       | ---              | ---
Go            | **GO**           | indefinitely    | fast      | `TRAP #3`        | no
Step into     | **STEP**         | one instruction | -         | -                | -
Step over     | **USER**         | while SP<orig.  | slow      | monitor check    | yes
Step out      | **REG** **USER** | until SP>orig.  | slow      | monitor check    | yes
Step continue | **REG** **STEP** | indefinitely    | slow      | monitor check    | yes



Minor changes
=============

Computing relative addresses
----------------------------
The monitor now is able to compute both 8 bit and 16 bit relative addresses. The principle is
when you are editing an _odd_ address, **REL** computes and writes an 8 bit offset
and when you are editing an _even_ address, **REL** computes a 16 bit offset, which is
written to the current and the following byte.

This works for all 68000 instructions which use relative addressing, including `Bcc` (both
8 and 16 bit), `DBcc`, and the addressing modes _PC-relative with offset_ `(d16,PC)` and
_PC-relative with index and offset_ `(d8,PC,Xn)`.

For example, you are at address `006AC` and want to input a branch `BGE` to address `00A80`.
You type **ADDR**, **6**, **A**, **C**, **DATA**, **6**, **C**, which inserts the upper byte
of the opcode for`BGE`. The LCD shows `BGE.S` and a random address. Now go to the next address
with **+** (an _odd_ address) and press **REL**. Enter the destination address `00A80` and
press **GO**. The LED now shows the 8 bit offset `D2` at address `006AD`, but the LCD shows
`BGE.S $000680`, which is clearly wrong. The reason is that the distance to the target is too
big to fit into 8 bits, so you have to use a 16 bit branch.

So (still at the same address `006AD`) enter `00` (which marks a long branch in 68000
machine code) and press **+** to go to the next address `006AE` (an _even_ address).
Now press **REL** and enter the destination again. The LCD now shows the correct instruction
`BGE.W $000A80` (note the `.W` here) and the LED shows `03` at `006AE` and `D2` at `006AF`
which is the correct 16 bit offset.


Chasing pointers in memory
--------------------------
When you are in the memory editor and the (even) address displayed contains a (32 bit) pointer,
you can set the current address to the pointer by pressing **REG** **ADDR**.


New memory layout
-----------------
The old monitor had system variables at `01f000` and the system stack at `010000`, in the middle
of the RAM address range. To have the maximum amount of RAM available for user programs, I changed
the memory layout as follows:

* All global variables have been moved to memory below `000400` (the starting address for user code).
  This memory region is normally used for user interrupt vectors, which the 68008 Kit doesn't
  use. Since the monitor variable area starts at `000200`, the first 64 user interrupt vectors from
  `000100` to `0001ff` could still be used by additional hardware without interference.
* The initial system stack pointer has been moved to `020000`, the top of RAM. So if your program
  runs in system mode, the SSP can grow from there and use the entire available RAM.
* The initial user stack pointer has been moved to `01fc00`, 1 kByte below the SSP. The monitor
  routines just need about 1/2 kByte of stack space, so the system stack will not run into the
  user stack range below. So if you decide to run your code in user mode, you'll have plenty
  of stack space below the system stack space.

This gives you a contiguous block of 126 kByte RAM in user mode or 127 kByte RAM in system mode.


Code clean-up and bug fixes
---------------------------
A lot of former global variables have been made local, the automaton states have been given
symbolic names and code duplications (register display) have been removed.

The duplicate user registers have been removed and the correct stack pointer (user or system)
is displayed now depending on machine mode.

Key code mapping now via table.

Many comments added.


Extended LED font
-----------------
A crude 7 segment font for the full alphabet has been created and text strings can now be
displayed on the LED. See `test_led.asm` how to use it. Most characters work fairly well, but
a few like K,M,W,X are really ugly, but at least guessable...


The disassembler
================
The disassembler uses standard Motorola syntax and supports only 68000/68008 instructions, no
later 68k instruction sets or addressing modes are supported. Illegal instructions or
adressing modes are marked with a question mark `?` or a caret `^` to indicate which part of
the instruction is illegal.

* `.?` indicates an invalid size field: `E9E2 ASL.? D4,D2`
* `^` indicates an invalid size for an address register: `D008 ADD.B ^A0,D0`
* `?ea` indicates a reserved effective address bit pattern: `D0BE ADD.L ?ea,D0`
* `?` before an operand indicates an illegal addressing mode for this instruction: `41C0 LEA ?D0,A0`
* `?op` indicates an undefined opcode: `4100 DC.W $4100 ; ?op`

Undefined opcodes or line A and line F instructions are written as `DC.W` pseudo-instructions.

PC-relative addresses and branch targets show the resulting absolute address.

All addresses which are actually output to the address bus are displayed with 24 bit/6 hex digits.
These are branch targets, PC-relative addresses and long absolute addresses.

The disassembler has been tested with all 2<sup>16</sup> possible opcodes and verified against
the actual behavior of the 68008 chip to each possible opcode and works correctly.  


Changes from V4.4 to V4.5
=========================
* Fix: Display correct disassembly after **LOAD** and **COPY**
* New: Monitor variable `show_sr` at `002fa` to switch SR and CCR display
* New: Key **REG** **COPY** to toggle `TRAP #1` breakpoints
* New: `monitor_scan` function to read keyboard
* New: Compute 8 and 16 bit offsets for all branches and PC-relative addressing modes via **REL** 
* Fix: Error handler on odd PC
* New: Display memory pointed to by address register
* New: Step over subroutines and traps with **USER** key
* New: Enter partial data into data register


Changes from V4.5 to V4.6
=========================
* New: display format for SR; 0, 1, or 2 in `002fa` 
* New: variable LCD size in `lcd_width` at `00300` and `lcd_lines` at `00302`
* New: flag `lcd_present` at `00304`
* New: variable shift size for **INS** and **DEL** block move at `00306`
* New: Step out of subroutine call
* Fix: Compatibility patch for `setjmp/logjmp` in `std68k.lib`
* Fix: avoid duplicates when including `monitor4x.h` twice
* Fix: use macros instead of consts for monitor variables in C
* Enh: more documentation, also as PDF


Changes from V4.6 to V4.7
=========================
* New: dynamic breakpoints
* Fix: disassembler TRAP syntax
* New: print newline to terminal
* New: Step continue
* Fix: handlers for unused traps and interrupts

Changes from V4.7 to V4.8
=========================
* Fix: clean up project structure and prepare for GIT
* New: go to pointer address displayed
* Enh: documentation


Summary of new key commands (original key labels)
=================================================
* Dumping to terminal
  * **DUMP** dump memory to terminal (*as before*)
  * **REG** **REL** list disassembly to terminal
  * **REG** **DUMP** dump registers to terminal
  * **REG** **LOAD** list dynamic breakpoints to terminal
  * **REG** **+** print a newline to terminal
* Register editing
  * **REG** **_Xn_** **DATA** input new (long) value for register _Xn_
  * **REG** **_Dn_** **DATA** **DATA** input new word value for data register _Dn_
  * **REG** **_Dn_** **DATA** **DATA** **DATA** input new byte value for data register _Dn_
  * **REG** **_An_** **ADDR** set current memory address from address register _An_
  * **REG** **ADDR** set current memory address from pointer in memory
* Stepping
  * **STEP** step into subroutines and traps  (*as before*)
  * **USER** step over subroutines and traps
  * **REG** **STEP** step continue
  * **REG** **USER** step out of a subroutine
* Breakpoints
  * **REG** **COPY** toggle all `TRAP #1` static breakpoints
  * **REG** **INS** toggle dynamic breakpoint at current address
  * **REG** **DEL** delete all dynamic breakpoints
  * **REG** **LOAD** list dynamic breakpoints to terminal

Summary of new key commands (new key labels)
========================================================
* Dumping to terminal
  * **⎙HEX** dump memory to terminal
  * **SHIFT** **⎙ASM** list disassembly to terminal
  * **SHIFT** **⎙REG** dump registers to terminal
  * **SHIFT** **⎙BRK** list dynamic breakpoints to terminal
  * **SHIFT** **⎙LF** print a newline to terminal
* Register editing
  * **SHIFT** **_Xn_** **EDIT** input new (long) value for register _Xn_
  * **SHIFT** **_Dn_** **EDIT** **EDIT** input new word value for data register _Dn_
  * **SHIFT** **_Dn_** **EDIT** **EDIT** **EDIT** input new byte value for data register _Dn_
  * **SHIFT** **_An_** **USE_A** set current memory address from address register _An_
  * **SHIFT** **USE_A** set current memory address from pointer in memory
* Stepping
  * **INTO** step into subroutines and traps
  * **OVER** step over subroutines and traps
  * **SHIFT** **CONT** step continue
  * **SHIFT** **OUT** step out of a subroutine
* Breakpoints
  * **SHIFT** **±TRP1** toggle all `TRAP #1` static breakpoints
  * **SHIFT** **±BRK** toggle dynamic breakpoint at current address
  * **SHIFT** **⨯BRK** delete all dynamic breakpoints
  * **SHIFT** **⎙BRK** list dynamic breakpoints to terminal
