/* SETJMP.H for CC68K */

#ifndef __SETJMP_DEF_
#define __SETJMP_DEF_

typedef struct {
    unsigned long  D2;    /*  0 */
    unsigned long  D3;    /*  4 */
    unsigned long  D4;    /*  8 */
    unsigned long  D5;    /* 12 */
    unsigned long  D6;    /* 16 */
    unsigned long  D7;    /* 20 */
    unsigned long  A2;    /* 24 */
    unsigned long  A3;    /* 28 */
    unsigned long  A4;    /* 32 */
    unsigned long  A5;    /* 36 */
    unsigned long  A6;    /* 40 */
    unsigned short SR;    /* 44 */
    unsigned long  PC;    /* 46 */
    unsigned long  SP;    /* 50 */
} jmp_buf[1];

void longjmp(jmp_buf, int);
int setjmp(jmp_buf);

#endif
