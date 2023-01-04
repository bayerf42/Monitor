/* test_lcd.c - Prints Hello world on the LCD */

#include "monitor4x.h"

void main(void)
{
  static const char heart[] = {0,0x0a,0x1f,0x1f,0x0e,0x04,0,0};
  *gpio1 = 0x55;
  lcd_clear();
  lcd_defchar(1, heart); // define custom character 1 with bit pattern heart
  lcd_goto(3,0);
  lcd_puts("Hello,");
  lcd_goto(5,1);
  lcd_puts("world! \001");
  monitor_loop(); // to avoid overwriting LCD with monitor output
}