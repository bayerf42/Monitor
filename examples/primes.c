#include <stdio.h>
#include <malloc.h>
void sieve(char *, unsigned int);

int main(void)
{
  char *array;
  unsigned int n=0;

  puts("Enter n: ");
  scanf("%d", &n);

  _trap(1);

  array =(char *)malloc(n + 1);
  if (array) {
    sieve(array,n);
  }
  else
    puts("Out of heap.\n");
  return 0;
}

void sieve(char *a, unsigned int n)
{
  unsigned int i=0, j=0;

  _trap(1);

  for (i=0; i<=n; i++)
    a[i] = 1;

  _trap(1);

  for (i=2; i<=n; i++)
    if (a[i])
      for (j=2*i; j<=n; j+=i)
        a[j] = 0;

  _trap(1);

  printf("\nPrimes numbers from 1 to %d are : ", n);
  for (i=2; i<=n; i++)
    if (a[i])
      printf("%d, ", i);
  printf("\n\n");
}