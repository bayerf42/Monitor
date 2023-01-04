/* test_disasm.c  -  How to call the disassembler from C */

#include <stdio.h>
#include "monitor4x.h"

void main(void)
{
  static char buf[50];
  ushort* pc = &main; // disassemble ourselves;
  int loop = 1;

  _trap(1);
  printf("PC = %06x\n", pc);
  while (loop) {
    if (*pc == 0x4e75) // RTS
      loop = 0;
    disassemble(&pc, buf);
    printf("inst = %-32s\t PC = %06x\n", buf, pc);
  }
}