/* test_fib.c  -  Compute Fibonacci numbers */

#include <stdio.h>

int fib(int n) {
  if (n<2)
    return 1;
  else
    return fib(n-1)+fib(n-2);
}

void main(void)
{
  int n=0;
  int res;

  while (1) {
    puts("Enter n: ");
    scanf("%d", &n);
    _trap(1);
    res = fib(n);
    printf("fib(%d) = %d\n", n, res);
  }
}
