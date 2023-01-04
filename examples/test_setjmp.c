/* Test setjmp patch */

/*
 * Test for the setjmp patch.
 * The original library std68k.lib uses TRAP #0 to implement setjmp/longjmp.
 * This conflicts with 68008 Kit use of TRAP #0 to return to monitor.
 * So the library has been patched (std68k_patched.lib) to use TRAP #2 instead.
 *
 * You need this patch only if
 * 1. you use setjmp/longjmp at all in your C code
 * 2. you want to single step through the implementation of setjmp/longjmp
 *
*/

#include <stdio.h>
#include "setjmp_patched.h" // wrong underscore in original

jmp_buf jb;

void foo(int n)
{
  printf("n=%d\n",n);
  if (n>0) {
    _trap(1);
    foo(n-1);
  }
  else {
    _trap(1);
    longjmp(jb, 42);
  }
  printf("not reached\n");
}

void main(void)
{
  int res;
  res = setjmp(jb);
  if (res==0) {
    printf("Installed handler\n");
    _trap(0);
    foo(2);
  }
  else {
    printf("Handler invoked %d\n",res);

  }
  printf("End\n");
}

