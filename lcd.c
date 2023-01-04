char *const LCD_command_write = (char *) 0x60000;
char *const LCD_data_write = (char *)    0x60001;
char *const LCD_command_read = (char *)  0x60002;
char *const LCD_data_read = (char *)     0x60003;

#define BUSY 0x80

extern char lcd_present;
extern uchar lcd_width;
extern uchar lcd_lines;

int LcdReady(void)
{
  int timeout = 0;
  while (*LCD_command_read&BUSY && ++timeout<200)
    continue; // wait until busy flag =0
  return timeout;
}

void clr_screen(void)
{
  if (lcd_present) {
    LcdReady();
    *LCD_command_write=0x01;
  }
}


void goto_xy(int x,int y)
{
  if (lcd_present) {
    LcdReady();
    switch (y) {
      case 0: *LCD_command_write=0x80+x; break;
      case 1: *LCD_command_write=0xC0+x; break;
      case 2: *LCD_command_write=0x94+x; break;
      case 3: *LCD_command_write=0xd4+x; break;
    }
  }
}


void InitLcd(void)
{
  lcd_present = LcdReady() < 100;
  *LCD_command_write=0x38;
  LcdReady();
  *LCD_command_write=0x0c;
  clr_screen();
  goto_xy(0,0);
}


char *Puts(char *str)
{
  unsigned char i;
  if (lcd_present) {
    for (i=0; str[i] != '\0'; i++) {
      LcdReady();
      *LCD_data_write=str[i];
    }
  }
  return str;
}

void putch_lcd(char ch)
{
  if (lcd_present) {
    LcdReady();
    *LCD_data_write=ch;
  }
}


void def_char(char ch, char* bits)
{
  unsigned char i;
  if (lcd_present) {
    LcdReady();
    *LCD_command_write=0x40|(ch<<3);
    for (i=0; i<8; i++) {
      LcdReady();
      *LCD_data_write=bits[i];
    }
  }
}