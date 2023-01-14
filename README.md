# Extending the monitor program for the Sirichote 68008 kit

## What is the Sirichote 68008 Kit?

It is an educational single-board computer using the ancient Motorola 68008 CPU,
designed by Wichit Sirichote, [described here](https://kswichit.net/68008/68008.htm).
It is mainly intended to learn programming the 68k in machine language. It has no operating
system, just a little monitor program and communicates with a terminal (emulator) via RS232.
If you want to buy/build one, contact Wichit via his web site.

## New features

The original monitor program is missing several useful features which I added in this repo. 

1. Register editing
2. Disassembler
3. Dumping info to the terminal
4. Interfacing to user programs
5. Error handling
6. Single stepping and breakpoints

This monitor is also required for my other 68008 Kit projects,
[Motorola FFP library](https://github.com/bayerf42/MotoFFP) and
[Lox68k](https://github.com/bayerf42/Lox68k)

## Prerequisites

* To build the monitor program, you need the
  *IDE68K suite* from https://kswichit.net/68008/ide68k30.zip and a Windows computer to run it.
  Install it to `C:\Ide68k` to avoid changing paths later. 
* For building the ROM image, you need Python 3, available at https://www.python.org/
* To burn the actual EPROM or Flash chip, you need a [programming device](https://www.google.com/search?q=tl866ii+plus)
* Usable chips are
  * [128k×8 EPROM](https://www.microchip.com/en-us/product/AT27C010) (original chip used in Kit)
  * [128k×8 Flash](https://www.microchip.com/en-us/product/SST39SF010A) (easier handling, no UV needed to erase)
  * probably many other 128k×8 PROM chips I didn't test

## Building the Monitor

* Clone this repo, preferrably to the directory `C:\Ide68k\Monitor`
* Create the directory `C:\Ide68k\rom`. In this directory all my 68008 Kit projects create and exchange
  ROM images.
* Start *IDE68K*, set `Options → Directories → Default` to `C:\Ide68k\Monitor`
  and load project `monitor.prj` and build it.
* A file `monitor.hex` is generated. Now execute
```sh
python makerom.py
```
which creates `monitor.bin` in the parallel `rom` directory.
* Load this file into the programming device and burn the chip.
* Plug the chip into the EPROM socket on the 68008 Kit and power on.
* The LED should display `68008 4.8` now.

If you don't want to build it yourself, a pre-built ROM image `monitor.bin`
is included in the release.


## Printing the keyboard sticker (optional)

The new Monitor defines several new key combinations to access all its features. Though the
monitor docs describe the keys by their original names, it may be convenient to print a new
keyboard sheet with the new commands on sticky paper and replace the original.

Just browse [the new layout](keyboard/keys.html) and print it (it has the right physical size).
For comparison, [the original layout](keyboard/keys_org.html)

Continue reading the [Monitor documentation](doc/monitor_doc.md)
