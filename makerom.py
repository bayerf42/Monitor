### Python script to build a ROM image containing the Monitor for 68008 Kit from HEX file

## Create an EPROM image by moving the HEX file's content from 0x040000 to 0x000000
## and patch first 8 bytes from HEX file (boot vector, initial SSP and PC)
## to 0x000000

import bincopy

rom_path = "../roms/"
rom_base = 0x40000

rom = bincopy.BinFile("monitor.hex")
bootvector = rom[0:8]

rom.fill()
rom.exclude(0, rom_base)
image = rom.as_binary()
image[0:8] = bootvector

with open(rom_path + "monitor.bin","wb") as dest:
  dest.write(image)
