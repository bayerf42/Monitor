// Monitor program for 68008 Microprocessor Kit V1.0
// (C) 2016 Wichit Sirichote
// CPU: Motorola 68008P10 10MHz oscillator
// 128 kB RAM, 128kB ROM
// 0x00000-0x1FFFF is RAM space
// 0x40000-0x5FFFF is ROM space
// SSP and boot vector are stored at location 0-7 in ROM.
// trap #0 is for monitor return from user code.
// Serial port is 2400 bit/s 8n1.
// Hex files for downloading accept S1 and S2, 16-bit address and 24-bit address
// Development Tool: IDE68k v3.0
// project files include
//  cswitches.a68
//  mycstart.asm
//  mycode.asm
//  lcd.c
//  main.c

///////////////////////////////////////////////////////////
// Modified 2/25/2017  Keith R. Hacke   hacke3@gmail.com
// Added code for software UART to speeds up to 9600 Baud
//  * Changed delay_bit and delay_15bit to use variable
//    so we can tweak them to get to 9600 Baud
//  * Tested with Tera Term Pro version 2.3
//    Baud:9600 Data:8 bit  Parity:None  Stop:1 bit  Flow Control:none
//  * For testing, seems to work best when in RAM if ide86
//    C compiler set to "Small Code" in memory model settings
//  * Make sure your ide68k project has files in this order:
//        cswitches.a68
//        mycstart.asm
//        main.c
//        mycode.asm
//        lcd.c
//    For whatever reason, the order seems to matter if you
//    want to get the Mon program running in RAM (for testing)
//    Not sure if it matters in EPROM.
//////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////
// Extended 2021-04-08  V 4.4 Fred Bayer fred@bayerf.de
//
// * Code cleanup and several bug fixes
// * Provide fixed entries to monitor routines
// * header/include files to call those routines from C or ASM
// * Create a crude font for LED display
// * Define custom chars on LCD
// * Add disassembler
// * Exception handlers
// * TRAP #1 for switchable breakpoints
// * Make user register editable
// * Dump registers and disassembly to serial
// * Memory layout optimized
//
// V 4.5 news:
//
// * Step over subroutine calls and traps
// * 8 and 16 bit offset calculation
// * REG COPY to toggle TRAP #1 breakpoints
// * Message when starting from odd PC
// * more comments
// * disassembler syntax fixes
// * Display target of address register
// * Edit parts of data register
//
// V 4.6 news:
//
// * Step out of a subroutine
// * New display format for status register
// * Variable LCD size
// * LCD present flag
// * Variable shift amount with INS and DEL
//
// V 4.7 news: 2022-02-05
//
// * dynamic breakpoints
// * cleanup monitor states and function names
// * fix disasm TRAP bug
// * go in stepping mode
//
// V 4.8 news: 2022-09-17
//
// * cleanup project structure
// * chase pointers in memory
//
//////////////////////////////////////////////////////////

typedef unsigned char  uchar;
typedef unsigned short ushort;
typedef unsigned int   uint;
typedef unsigned long  ulong;

// Assembler function prototypes
void go(void);
void step_into(void);
void step_over(void);
void step_cont(void);
void step_out(void);
void step_then_go(void);
void disarm_breakpoints(void);
void enable_level2(void);

// C function prototypes
void InitLcd(void);
char *Puts(char *str);
void clr_screen(void);
void goto_xy(int x,int y);
void send_long_hex(ulong n);
void read_memory(void);
void key_data(void);
void pstring(char *s);
void disassemble(ushort** addr, char* dest);
void disassemble_lcd(void);
ushort *dump_disassembly(ushort* addr);
void print_led(int offset, const char* text);
void display_register(ulong *reg);
void dot_register(void);
void format_sr(void);
void newline(void);
int  breakpoint_at(ulong address);


// Symbolic constants
#define VERSION "V4.8"
#define INIT_SSP 0x20000
#define INIT_USP 0x1fc00
#define INIT_PC  0x00400
#define INIT_SR  0x2700

#define MAX_BP   8

// Monitor states
#define STATE_AFTER_RESET     0
#define STATE_INPUT_ADDR      1
#define STATE_INPUT_DATA      2
#define STATE_SHIFT           3
#define STATE_COMP_OFFSET     5
#define STATE_COPY_START     10
#define STATE_COPY_END       11
#define STATE_COPY_DEST      12
#define STATE_INPUT_REGISTER 13
#define STATE_SHOW_REGISTER  14
#define STATE_TOGGLE_TRAP1   15


// 68008 kit I/O locations
char *const gpio1 = (char *) 0xF0000;   // 8-bit debugging LED
char *const port0 = (char *) 0x80000;   // key input
char *const port1 = (char *) 0x80002;   // digit driver
char *const port2 = (char *) 0xA0000;   // segment driver


// Bit patterns for LED segments
char const convert[]= {
  0xBD, 0x30, 0x9B, 0xBA, 0x36, 0xAE, 0xAF, 0x38, 0xBF, 0xBE, // 0123456789
  0x3F, 0xA7, 0x8D, 0xB3, 0x8F, 0x0F, 0xAD, 0x37, 0x20, 0xB1, // AbCdEFGhiJ
  0x97, 0x85, 0x29, 0x23, 0xA3, 0x1F, 0x3E, 0x03, 0xAE, 0x87, // KLMnoPqrSt
  0xB5, 0xA1, 0x94, 0x8A, 0xB6, 0x9B,                         // UvWXyZ
  0x8D, 0x26, 0xB8, 0x1C, 0x80                                // [\]^_
};

// Segments bit numbers
//    .-3-.
//    2   4
//    .-1-.
//    0   5
//    .-7-.*6

#define LED_SEG_POINT 0x40
#define LED_SEG_MINUS 0x02
#define LED_SEG_BREAK 0x1e


// Magic value to distinguish Kit from emulator and
// to avoid re-init globals after reset.
#define MAGIC 0x1138

/////////////////////////////////////////////////////////////////////////////////
// Global variables
// !!! Don't add variables here or change their order, always add them at the
// !!! end marked below. This ensures that the addresses listed in the monitor
// !!! include files don't change. You have about 260 additonal bytes available
// !!! in memory below 0x00400
/////////////////////////////////////////////////////////////////////////////////
ushort magic;          // to init certain variables only on power up
char   led_buffer[8];  // display buffer
char   line[81];       // output line buffer
char   exception_nr;
char   state;
char   entry_started;
char   beep_flag;
char   hit_a6;
char   key;

ulong  tick;
ushort disasm_lines;   // how many lines to disassemble
ushort hexdump_lines;  // how many (16 byte) lines of memory to display
char   disasm_on_lcd;  // flag to enable displaying disassembly on LCD
char   enable_trap1;   // 1 -> TRAP #1 stops program, 0 -> TRAP #1 is ignored

// delay counters
int    glob_d;
uint   glob_j;
uint   glob_b1;        // Counter for delay_bit
uint   glob_b2;        // Counter for delay_15bit
uchar  glob_n;
char   glob_i;

char   bcc_error;      // flag for checking bcc error
char   bcc;
char   save_bcc;

ulong  start, end;
ulong  display_PC, save_PC;
ushort *curr_inst, *next_inst;

// User registers
ulong  user_data[8];   // D0-D7
ulong  user_addr[7];   // A0-A6
ulong  user_usp;       // USP
ulong  user_ssp;       // SSP
ushort user_sr;        // SR
ulong  user_pc;        // PC
ulong  *edit_register; // register being edited

// new in 4.5
ulong  call_frame;     // SP limit for stepping over
char   frame_origin;   // 0 if SP limit is from SSP, other from USP
char   show_sr;        // status register display: 0 classic, 1 numeric, 2 symbolic
uchar  edit_size;      // size of data register being edited, 1, 2 or 4

// new in 4.6
char   step_mode;      // 0 for step over, 1 for step out
uchar  lcd_width;      // width of lcd in chars, typical 8, 16 or 20
uchar  lcd_lines;      // number of lines in LCD, typical 1, 2 or 4
char   lcd_present;    // 0 if missing, non-zero if present
ushort shift_size;     // number of bytes to shift with INS and DEL

// new in 4.7
short  num_bp;               // number of active breakpoints
char   bp_armed;             // breakpoints armed
ulong  break_points[MAX_BP]; // addresses of breakpoints
ushort orig_instr[MAX_BP];   // original instructions


/////////////////////////////////////////////////////////////////////////////////
// !! Current end of global variables, you can add more here.
/////////////////////////////////////////////////////////////////////////////////

//////////////////////////// Software UART 9600 bit/s /////////////////////////////////////////

void delay_bit(void)
{
  for (glob_j=0; glob_j<glob_b1; glob_j++)
    continue;
  glob_d = 0;  // Tune for 9600 Baud
  glob_d = 0;
  glob_d = 0;
  // Note d=d+1  too slow in EPROM (may be ERPOM slower than RAM??)
  glob_d = 0;
}


void delay_15bit(void)
{
  for (glob_j=0; glob_j<glob_b2; glob_j++)
    continue;
  glob_d=0;
}


void send_byte(char n)
{
  *port1 = 0x7f;  // send start bit
  delay_bit();
  for (glob_i=0; glob_i<8; glob_i++) {
    if (n&1)
      *port1 = 0xff;
    else
      *port1 = 0x7f;
    delay_bit();
    n >>= 1;
  }
  *port1 = 0xff;   // send stop bit
  delay_bit();
}


char get_byte(void)
{
  glob_n = 0;

  while (*port0&0x80)
    continue;     // wait for start bit
  delay_15bit();  // must be 1.5 bit

  for (glob_i=0; glob_i<7; glob_i++) {
    if ((*port0&0x80)!=0)
      glob_n |= 0x80;
    glob_n >>= 1;
    delay_bit();
  }
  delay_bit();   // center bit of D7
  return glob_n; // rest is for monitor processing half of D7+full period of stop bit
}


// c must be 0-9 and A-F for hex digit
uchar nibble2hex(char c)
{
  if (c<0x40)
    return c-0x30;
  else
    return c-0x37;
}


uchar gethex(void)
{
  char a,b;
  a = get_byte();
  b = get_byte();
  a = nibble2hex(a)<<4;
  b = nibble2hex(b);
  a   |= b;
  bcc += a;  // compute check sum
  return a;
}


ulong get24bitaddress(void)
{
  ulong load_address;

  load_address   = 0;
  load_address  |= gethex();
  load_address <<= 8;
  load_address  |= gethex();
  load_address <<= 8;
  load_address  |= gethex();

  return load_address;
}


ulong get16bitaddress(void)
{
  ulong load_address;

  load_address   = 0;
  load_address  |= gethex();
  load_address <<= 8;
  load_address  |= gethex();

  return load_address;
}


void read_record1(void)
{
  char i, byte_count;
  long address24bit;
  char *sload;

  bcc = 0;
  byte_count = gethex()-3;   // byte count only for data byte
  address24bit = get16bitaddress();

  sload = address24bit;
  for (i=0; i<byte_count; i++)
    *(sload+i) = gethex();

  bcc = ~bcc;      // one's complement
  *gpio1 = bcc;    // loading indicator

  save_bcc = bcc;

  if (save_bcc != gethex())
    bcc_error = 1;
}


void read_record2(void)
{
  char i, byte_count;
  long address24bit;
  char* sload;

  bcc = 0;
  byte_count = gethex()-4;   // byte count only for data byte
  address24bit = get24bitaddress();

  sload = address24bit;

  for (i=0; i<byte_count; i++)
    *(sload+i) = gethex();

  bcc = ~bcc;     // one's complement
  *gpio1 = bcc;   // loading indicator

  save_bcc = bcc;

  if (save_bcc != gethex())
    bcc_error=1;
}


void get_s_record(void)
{
  char end = 0;
  bcc_error = 0;

  while (end==0)
  {
    while (get_byte() != 'S')
      continue;

    switch(get_byte()) // get record type
    {
      case '0': end=0; break;
      case '1': read_record1(); break;
      case '2': read_record2(); break;
      case '8': end=1; break;
      case '9': end=1; break;
    }
  }

  if (bcc_error)
    pstring("\r\ncheck sum errors!\r\n");
  else
    pstring("\r\nload successfull!\r\n");

  curr_inst = display_PC;
  key_data();
}


void send_hex(char n)
{
  char k;
  k = n>>4;
  k = k&0xf;

  if (k>9)
    send_byte(k+0x37);
  else
    send_byte(k+0x30);
  k = n&0xf;
  if (k>9)
    send_byte(k+0x37);
  else
    send_byte(k+0x30);
}


void send_word_hex(ushort n)
{
  send_hex((n>>8)&0xff);
  send_hex(n&0xff);
}


void send_long_hex(ulong n)
{
  send_hex((n>>24)&0xff);
  send_hex((n>>16)&0xff);
  send_hex((n>>8)&0xff);
  send_hex(n&0xff);
}


// print string to terminal
void pstring(char *s)
{
  while (*s)
    send_byte(*s++);
}


////////////////////////////////// end of Software UART ////////////////////////////

//--------------------------produce beep when key presed ----------------------
void delay_beep(void)
{
  char j;
  for (j=0; j<0x14; j++)
    continue;
}


void beep(void)
{
  *port2=0;   // turn off display

  for (glob_d=0; glob_d<80; glob_d++) {
    *port1 = ~0x40;
    delay_beep();
    *port1 = 0xff;
    delay_beep();
  }
}

//---------------------------- end of beep -------------------------------------

void delay_on(void)
{
  for (glob_d=0; glob_d<1; glob_d++)
    continue;
}


void delay_off(void)
{
  for (glob_d=0; glob_d<10; glob_d++)
    continue;
}


char scan(void)
{
  char k = 0xf0;
  uchar n;
  char i,o;
  char u = 0;
  char q = 0;  // key code
  key = -1;    // if no key pressed key=-1

  for (i=0; i<8; i++) {
    *port1 = k;             // write digit and turn off speaker & TXD
    *port2 = led_buffer[i]; // write segment
    delay_on();

    *port2 = 0; // turn off display
    delay_off();

    o = *port0; // read key switch

    for (n=0; n<6; n++) {// check for 6 rows
      if ((o&1)==0)
        key=q; // save key if pressed
      else
        q++;
      o >>= 1;
    }
    k++;
  }
  return key;   // return scan code
}


void delay(int n)
{
  int u;
  for (u=0; u<n; u++)
    continue;
}


void address_display(void)
{
  char k;
  ulong addr = display_PC;
  for (k=3; k<8; ++k) {
    led_buffer[k] = convert[addr&0xf];
    addr >>= 4;
  }
}


void data_display(void)
{
  char* dptr = display_PC;
  uchar n = *dptr;
  led_buffer[0] = convert[n&0xf];
  n >>= 4;
  led_buffer[1] = convert[n&0xf];
}


void read_memory(void)
{
  address_display();
  data_display();
  led_buffer[2] = breakpoint_at(display_PC) ? LED_SEG_BREAK : 0;
  disassemble_lcd();
}


void dot_led(short lower, short upper)
{
  // switch on dots in LED from lower (incl.) to upper (excl.), counted from right
  short k;
  for (k=0; k<lower; ++k)
    led_buffer[k] &= ~LED_SEG_POINT;
  for (k=lower; k<upper; ++k)
    led_buffer[k] |= LED_SEG_POINT;
  for (k=upper; k<8; ++k)
    led_buffer[k] &= ~LED_SEG_POINT;
}


void dot_address(void)
{
  dot_led(3,8);
}


void dot_data(void)
{
  dot_led(0,2);
}


void dot_register(void)
{
  dot_led(0,2*edit_size);
}


void key_address(void)
{
  read_memory();
  dot_address();
  entry_started = 0;
  curr_inst = display_PC;
  disassemble_lcd();
  state = STATE_INPUT_ADDR;
}


void key_data(void)
{
  read_memory();
  dot_data();
  entry_started = 0;
  state = STATE_INPUT_DATA;
}


void start_edit_reg(void)
{
  if (edit_register != 0) {
    edit_size = 4;
    display_register(edit_register);
    dot_register();
    entry_started = 0;
    state = STATE_INPUT_REGISTER;
  }
}


void change_edit_size(void) {
  if (edit_register != 0 &&
      !entry_started &&
      edit_register < user_addr) {
    switch (edit_size) {
      case 4: edit_size = 2; break;
      case 2: edit_size = 1; break;
      case 1: edit_size = 4; break;
    }
    dot_register();
  }
}


void key_plus(void)
{
  if (state==STATE_COPY_START) {
    start = display_PC;
    print_led(7,"E");
    state = STATE_COPY_END;
    entry_started = 0;
  }
  else if (state==STATE_COPY_END) {
    end = display_PC;
    print_led(7,"d");
    state = STATE_COPY_DEST;
    entry_started = 0;
  }
  else if (state==STATE_SHIFT) {
    newline();
  }
  else if (state==STATE_INPUT_ADDR ||
           state==STATE_INPUT_DATA ||
           state==STATE_COMP_OFFSET) {
    display_PC++;
    if (display_PC >= next_inst)
      curr_inst = display_PC;
    read_memory();
    key_data();
  }
}


void key_minus(void)
{
  if (state==STATE_INPUT_ADDR ||
      state==STATE_INPUT_DATA ||
      state==STATE_COMP_OFFSET) {
    display_PC--;
    if (display_PC < curr_inst)
      curr_inst = display_PC;
    read_memory();
    key_data();
  }
}


void address_hex(void)
{
  if (!entry_started)
    display_PC = 0;

  entry_started = 1;
  display_PC  <<= 4;
  display_PC   |= key;

  curr_inst = display_PC;
  read_memory();
  dot_address();
}


void data_hex(void)
{
  char* dptr = display_PC;
  uchar n = *dptr;

  if (!entry_started)
    n=0;
  entry_started = 1;
  n <<= 4;
  n |= key;
  *dptr = n;

  if (n != *dptr) // Data stored doesn't read back the same, ignore it.
    ;

  read_memory();
  dot_data();
}


void reg_hex(void)
{
  uchar  *edit_register8;
  ushort *edit_register16;

  if (edit_register != 0) {
    switch (edit_size) {
      case 1:
        edit_register8 = edit_register;
        edit_register8 += 3;
        if (!entry_started)
          *edit_register8 = 0;
        *edit_register8 <<= 4;
        *edit_register8  |= key;
        break;

      case 2:
        edit_register16 = edit_register;
        edit_register16 += 1;
        if (!entry_started)
          *edit_register16 = 0;
        *edit_register16 <<= 4;
        *edit_register16  |= key;
        break;

      case 4:
        if (!entry_started)
          *edit_register = 0;
        *edit_register <<= 4;
        *edit_register  |= key;
        break;
    }
    entry_started = 1;
    display_register(edit_register);
    dot_register();
  }
}


void key_PC(void)
{
  display_PC = save_PC;
  curr_inst = display_PC;
  key_data();
}


void long2buffer(ulong n)
{
  char k;
  for (k=0; k<8; ++k) {
    led_buffer[k] = convert[n&0xf];
    n >>= 4;
  }
}


void display_sr(void)
{
  ushort temp  = user_sr;
  led_buffer[3] = convert[temp&0xf];
  temp >>= 4;
  led_buffer[4] = convert[temp&0xf];
  temp >>= 4;
  led_buffer[5] = convert[temp&0xf];
  temp >>= 4;
  led_buffer[6] = convert[temp&0xf];
  led_buffer[7] = 0;

  print_led(5," Sr");
}


// XNZVC
void display_ccr(void)
{
  ushort temp = user_sr;
  led_buffer[3] = (temp&1)    ? convert[1] : convert[0]; // carry flag
  led_buffer[4] = (temp&2)    ? convert[1] : convert[0]; // overflow flag
  led_buffer[5] = (temp&4)    ? convert[1] : convert[0]; // zero flag
  led_buffer[6] = (temp&8)    ? convert[1] : convert[0]; // negative flag
  led_buffer[7] = (temp&0x10) ? convert[1] : convert[0]; // extend flag

  print_led(5," Cr");
}


void display_fmt_sr(void)
{
  format_sr();
  print_led(0,line);
}


void display_register(ulong *reg)
{
  long2buffer(*reg);
  edit_register = reg;
}


// SHIFT (REG) key used with hex key 0-f in state STATE_SHIFT or STATE_SHOW_REGISTER
void select_register(void)
{
  state = STATE_SHOW_REGISTER;

  if (key<8)
    display_register(&user_data[key]);
  else if (key<14)
    display_register(&user_addr[key-8]);
  else if (key==14) {
    hit_a6 ^= 1;
    if (hit_a6) {
      switch (show_sr) {
        case 0: display_ccr();    break;
        case 1: display_sr();     break;
        case 2: display_fmt_sr(); break;
      }
      edit_register = 0; // not editable
    }
    else
      display_register(&user_addr[6]);
  }
  else { // key==15
    if (user_sr & 0x2000)
      display_register(&user_ssp);
    else
      display_register(&user_usp);
  }
}


void key_reg(void)
{
  print_led(0," SH1Ft  ");
  state = STATE_SHIFT;
  edit_register = 0;
}


// insert byte and shift bytes down
void insert_byte(void)
{
  uint j;
  char *dptr = display_PC;
  for (j=shift_size; j>0; j--)
    dptr[j] = dptr[j-1];

  dptr[1] = 0;  // insert next byte
  display_PC++;
  if (display_PC >= next_inst)
    curr_inst = display_PC;
  read_memory();
  state = STATE_INPUT_DATA;
  dot_data();
}


// delete current byte and shift bytes up
void delete_byte(void)
{
  uint j;
  char *dptr = display_PC;
  for (j=0; j<shift_size; j++)
    dptr[j] = dptr[j+1];
  read_memory();
  state = STATE_INPUT_DATA;
  dot_data();
}


void copy_block(void)
{
  state = STATE_COPY_START;

  address_display();
  dot_address();

  print_led(5," -S");
  entry_started = 0;
}


void word_enter(void)
{
  if (!entry_started)
    display_PC = 0;
  entry_started = 1;
  display_PC  <<= 4;
  display_PC   |= key;
  address_display();
  dot_address();
}


void print_error(void)
{
  print_led(0,"  Err   ");
  state = STATE_AFTER_RESET;
}


void print_exception(void)
{
  print_led(0,"Err ");

  switch (exception_nr) {
    case 0x2: print_led(4,"bUS "); break;
    case 0x3: print_led(4,"Addr"); break;
    case 0x4: print_led(4,"1LLE"); break;
    case 0x5: print_led(4,"div0"); break;
    case 0x6: print_led(4,"Chk "); break;
    case 0x7: print_led(4,"trPv"); break;
    case 0x8: print_led(4,"Priv"); break;
    //   0x9  Trace actually handled
    case 0xa: print_led(4,"LinA"); break;
    case 0xb: print_led(4,"LinF"); break;
    case 0xc: print_led(4,"1ntr"); break;
    case 0xd: print_led(4,"trAP"); break;
  }
  state = STATE_AFTER_RESET;
}


void print_odd_pc(void)
{
  print_led(0," odd PC ");
}


// Print text on LED starting at offset. Allowed chars are digits,
// letters (upper and lower), space and minus. If bit 7 of the character
// is set, the decimal point segment of the LED is switched on, too.
void print_led(int offset, const char* text)
{
  int i;
  for (i=7-offset; *text; --i,++text) {
    char c = *text & 0x7f;
    if (c == '-')
      led_buffer[i] = LED_SEG_MINUS;
    else if (c < '0' || c > '9' && c < 'A')
      led_buffer[i] = 0; // unimplemented character
    else
      led_buffer[i] = convert[nibble2hex(c>=0x60 ? c-0x20 : c)];
    if (*text & 0x80)
      led_buffer[i] |= LED_SEG_POINT;
  }
}


void copy_data(void)
{
  ulong destination = display_PC;
  long temp32 = end-start;
  char *dptr2 = start;
  char *dptr = destination;
  uint j;

  if (end <= start)
    print_error();
  else {
    for (j=0; j<temp32; j++)
      dptr[j] = dptr2[j];

    curr_inst = display_PC = destination;
    read_memory();
    dot_data();
    state = STATE_INPUT_DATA;
  }
}


void find_offset(void)
{
  ulong destination = display_PC;
  ulong delta;
  char  *off8  = start;
  short *off16 = start;

  if (start & 1) {
    // odd address -> use 8 bit offset for Bcc.S, (d8,PC,Xn)
    if (start-1 == (curr_inst & -2)) {
      // second byte of Bcc.S branch
      delta = destination-start-1;
    }
    else {
      // Assume second byte of extension word of (d8,PC,Xn) addressing mode
      delta = destination-start+1;
    }
    *off8 = delta&0xff;
  }
  else {
    // even address -> 16 bit offset for Bcc.W, DBcc, (d16,PC)
    delta = destination-start;
    *off16 = delta;
  }

  display_PC = start;
  read_memory();
  dot_data();
  state = STATE_INPUT_DATA;
}


void key_go(void)
{
  switch (state)
  {
    case STATE_COPY_DEST:
      copy_data();
      break;

    case STATE_COMP_OFFSET:
      find_offset();
      break;

    case STATE_INPUT_ADDR:
    case STATE_INPUT_DATA:
    case STATE_INPUT_REGISTER:
    case STATE_SHOW_REGISTER:
    case STATE_TOGGLE_TRAP1:
    case STATE_SHIFT:
      if (breakpoint_at(display_PC))
        step_then_go();
      else
        go();
      break;
  }
}


void compute_relative(void)
{
  state = STATE_COMP_OFFSET;
  address_display();
  dot_address();
  start = display_PC;
  print_led(5," -d");
  entry_started = 0;
}


void key_test(void)
{
  enable_level2();

  // test gpio1
  *gpio1 = 0xff;

  // test LCD
  InitLcd();
  Puts("68008 Kit " VERSION);
  goto_xy(0,1);
  Puts("128kRAM 128kROM");

  *gpio1 = 0;

  for (;;) {
    long2buffer(tick);
    scan();
  }
}


void newline(void)
{
  send_byte(0x0a);
  send_byte(0x0d);
}


// Send memory hex dump to terminal
void dump_memory(void)
{
  int j,p;
  char* dptr = display_PC;

  for (j=0; j<hexdump_lines; j++) {
    send_long_hex(dptr);
    send_byte(':');
    for (p=0; p<16; p++) {
      send_hex(dptr[p]);
      send_byte(0x20);
    }

    send_byte(0x20);

    for (p=0; p<16; p++)
    {
      char q = dptr[p];
      if (q >= 0x20 && q < 0x80)
        send_byte(q); // only printable ASCII
      else
        send_byte('.');
    }
    dptr += 16;
    newline();
  }
  display_PC = dptr; // update current display_PC
  key_address();     // update 7-segment as well
}


// Disassemble current PC and display on LCD
void disassemble_lcd()
{
  char j, k, width, lines;
  ushort *addr = curr_inst & -2; // clear bit 0
  short buf_size;

  if (disasm_on_lcd) {
    // Sanity check to avoid trashing memory
    width = lcd_width < 1 ? 1 : (lcd_width > 20 ? 20 : lcd_width);
    lines = lcd_lines < 1 ? 1 : (lcd_lines > 4  ? 4  : lcd_lines);
    buf_size = width * lines;

    for (j=0; j<buf_size; ++j)
      line[j] = ' ';
    disassemble(&addr, line);

    // replace TABs by spaces
    for (j=0; j<buf_size; ++j)
      if (line[j] == 0x09)
        line[j] = ' ';

    clr_screen();
    for (k=lines-1; k>=0; --k) {
      line[(k+1) * width] = 0;
      goto_xy(0, k);
      Puts(line + k * width);
    }

    next_inst = addr;
  }
}


// Send disassembly listing to terminal
void disassemble_list(void)
{
  char j;

  for (j=0; j<disasm_lines; ++j) {
    display_PC = dump_disassembly(display_PC);
  }
  key_address(); // update 7-segment as well
}


// Send one line of disassembly to terminal
ushort* dump_disassembly(ushort* addr)
{
  ushort *laddr;
  char  j;

  laddr = addr &= -2; // start at even address;
  send_long_hex(addr);
  send_byte(':');
  send_byte(breakpoint_at(laddr) ? '*' : ' ');
  disassemble(&addr, line);

  // Print upto 5 code words
  for (j=0; j<5; ++j) {
    if (laddr < addr)
      send_word_hex(*laddr++);
    else
      pstring("    ");
    send_byte(' ');
  }
  pstring("  ");

  // Print assembler instruction
  pstring(line);
  newline();

  return addr;
}


// Send dump of register contents to terminal
void dump_registers(void)
{
  char j;

  // First line: print 8 data registers
  pstring("D0:");
  for (j=0; j<8; j++) {
    send_byte(' ');
    send_long_hex(user_data[j]);
  }
  newline();

  // Second line: print 7 address registers, USP or SSP depending on mode
  pstring("A0:");
  for (j=0; j<7; j++) {
    send_byte(' ');
    send_long_hex(user_addr[j]);
  }
  send_byte(' ');
  if (user_sr & 0x2000)
    send_long_hex(user_ssp);
  else
    send_long_hex(user_usp);
  newline();

  // Third line: print status register, formatted, and both stack pointers
  pstring("SR: ");
  send_word_hex(user_sr);
  pstring("     ");
  format_sr();
  pstring(line);
  pstring("     USP: "); send_long_hex(user_usp);
  pstring("     SSP: "); send_long_hex(user_ssp);
  newline();

  // Fourth line: print next assembler instruction
  dump_disassembly(display_PC);
  key_address();     // update 7-segment as well
}


void format_sr(void)
{
  char *dest = line;
  *dest++ = user_sr & 0x8000 ? 'T' : '-';
  *dest++ = user_sr & 0x2000 ? 'S' : '-';
  *dest++ = ((user_sr & 0x0700) >> 8) + '0'; // Interrupt level
  *dest++ = user_sr & 0x0010 ? 'X' : '-';
  *dest++ = user_sr & 0x0008 ? 'N' : '-';
  *dest++ = user_sr & 0x0004 ? 'Z' : '-';
  *dest++ = user_sr & 0x0002 ? 'V' : '-';
  *dest++ = user_sr & 0x0001 ? 'C' : '-';
  *dest   = 0;
}


void load_srecord(void)
{
  pstring("\r\nLoad Motorola s-record: ");
  get_s_record();  // could be S1 (16-bit load address) or S2 (24-bit load address)
}


void toggle_trap1(void)
{
  enable_trap1 = !enable_trap1;
  print_led(0,"trP1 0");
  print_led(6,enable_trap1 ? "n " : "FF");
  state = STATE_TOGGLE_TRAP1; // avoid accidental SHIFT state here
}


void toggle_breakpoint(ulong address)
{
  short j,k;

  if (address & 1)
    return;

  for (j=0; j<num_bp; j++) {
    if (address == break_points[j]) {
      // breakpoint exists at address, delete it
      for (k=j; k<num_bp-1; k++)
        // slide down breakpoints above
        break_points[k] = break_points[k+1];
      num_bp--;
      return;
    }
    else if (address < break_points[j]) {
      // insert new breakpoint here
      if (num_bp < MAX_BP) {
        for (k=num_bp; k>j; k--)
          // slide up breakpoints above
          break_points[k] = break_points[k-1];
        break_points[j] = address;
        num_bp++;
        return;
      }
      else
        // no space for breakpoint
        return;
    }
    // else next
  }
  if (num_bp < MAX_BP)
    // insert new breakpoint above all previous ones
    break_points[num_bp++] = address;
}


void clear_all_breakpoints(void)
{
  num_bp = 0;
  bp_armed = 0;
}


// Send all breakpoints to terminal
void dump_breakpoints(void)
{
  short j;
  pstring("; ");
  send_byte('0' + num_bp);
  pstring(" breakpoint");
  if (num_bp != 1)
    send_byte('s');
  pstring(" set");
  newline();
  for (j=0; j<num_bp; j++) {
    dump_disassembly(break_points[j]);
  }
  key_address();
}


int breakpoint_at(ulong address)
{
  short j;
  for (j=0; j<num_bp; j++)
    if (break_points[j]==address)
      return 1;
  return 0;
}


void key_user(void)
{
  char* pc = (char*)display_PC;

  if (state==STATE_SHIFT) {
    if ((user_sr & 0x2000)  && user_ssp >= INIT_SSP ||
        !(user_sr & 0x2000) && user_usp >= INIT_USP) {
      // Top of Stack, can't step out
      print_led(0, " toP SP ");
      state = STATE_INPUT_ADDR;
    }
    else
      step_out();
  }
  else {
    if (pc[0] == 0x4e && (pc[1] == 0x40 || pc[1] == 0x41)) {
      // TRAP #0 or TRAP #1, always skip over these
      display_PC += 2;
      key_address();
    }
    else
      step_over();
  }
}


void key_exe(void)
{
  if (beep_flag==0)
    beep();  // beep when pressed

  if (key >= 0x10) {
    switch (key) { // for function key
      case 0x13: // Key ADDR
        if (state==STATE_SHIFT) {
          // use memory content as address
          if (display_PC & 1) {
            print_led(0, "odd Addr");
            state = STATE_INPUT_ADDR;
            break;
          }
          else 
            display_PC = *((ulong *)display_PC);
        }  
        else if ((state==STATE_SHOW_REGISTER ||
                  state==STATE_INPUT_REGISTER) &&
                 edit_register >= user_addr) {
          // use An as address
          display_PC = *edit_register;
        }
        key_address();
        break;

      case 0x12: // Key DATA
        if (state==STATE_SHOW_REGISTER)
          start_edit_reg();
        else if (state==STATE_INPUT_REGISTER)
          change_edit_size();
        else
          key_data();
        break;

      case 0x17: // Key +
        key_plus();
        break;

      case 0x16: // Key -
        key_minus();
        break;

      case 0x10: // Key PC
        key_PC();
        break;

      case 0x1b: // Key GO
        key_go();
        break;

      case 0x11: // Key REG
        key_reg();
        break;

      case 0x20: // Key COPY
        if (state==STATE_SHIFT ||
            state==STATE_TOGGLE_TRAP1)
          toggle_trap1();
        else
          copy_block();
        break;

      case 0x1a: // Key STEP
        if (state==STATE_SHIFT)
          step_cont();
        else
          step_into();
        break;

      case 0x1c: // Key USER
        key_user();
        break;

      case 0x18: // Key INS
        if (state==STATE_SHIFT) {
          toggle_breakpoint(display_PC);
          key_data();
        }
        else
          insert_byte();
        break;

      case 0x19: // Key DEL
        if (state==STATE_SHIFT) {
          clear_all_breakpoints();
          key_data();
        }
        else
          delete_byte();
        break;

      case 0x1f: // Key REL
        if (state==STATE_SHIFT)
          disassemble_list();
        else
          compute_relative();
        break;

      case 0x14: // Key TEST
        key_test();
        break;

      case 0x1e: // Key DUMP
        if (state==STATE_SHIFT)
          dump_registers();
        else
          dump_memory();
        break;

      case 0x1d: // Key LOAD
        if (state==STATE_SHIFT)
          dump_breakpoints();
        else
          load_srecord();
        break;

      case 0x15: // Key MUTE
        beep_flag ^= 1;
        break;
    }
  }
  else {
    switch (state) { // for hex key enter
      case STATE_INPUT_ADDR:
        address_hex();
        break;

      case STATE_INPUT_DATA:
        data_hex();
        break;

      case STATE_INPUT_REGISTER:
        reg_hex();
        break;

      case STATE_SHOW_REGISTER:
      case STATE_SHIFT:
        select_register();
        break;

      case STATE_COMP_OFFSET:
      case STATE_COPY_START:
      case STATE_COPY_END:
      case STATE_COPY_DEST:
        word_enter();
        break;
    }
  }
}


char code2internal(char n)
{
  static const char keyMap[] = {
    0x18, 0x19, 0x1a, 0x1b, 0xff, 0xff, 0x14, 0x15, // 00-07
    0x16, 0x17, 0x1c, 0xff, 0x10, 0x11, 0x12, 0x13, // 08-0f
    0x00, 0x1d, 0x0f, 0x0b, 0x07, 0x03, 0x04, 0x1e, // 10-17
    0x0e, 0x0a, 0x06, 0x02, 0x08, 0x1f, 0x0d, 0x09, // 18-1f
    0x05, 0x01, 0x0c, 0x20                          // 20-23
  };

  return keyMap[n];
}

/*
* Key matrix (raw key codes)
*
* 23  22 1E 18 12  0C 06 00 ##
* 1D  1C 1F 19 13  0D 07 01 !!
* 17  16 20 1A 14  0E 08 02 0A
* 11  10 21 1B 15  0F 09 03 **
*
* ## RESET key not in matrix, hardware reset
* !! IRQ   key not in matrix, hardware interrupt level 2
* ** REP   key not in matrix, use   btst #6,port0   to check for REP key
*/


void scan1(void)
{
  char raw_key;

  while ((scan()!= -1) && ((*port0&0x40) !=0))
    continue;
  delay(100);

  while (scan() == -1)
    continue;
  delay(100);

  raw_key = scan();

  // check key in range
  if (raw_key>=0 && raw_key<0x24) {
    key = code2internal(raw_key);
    key_exe();
  }
}


// Init global variables here, no static init supported by C compiler
void init_globals(void)
{
  beep_flag     = 0;
  hit_a6        = 0;
  edit_register = 0;

  if (magic != MAGIC) {
    // Initialize these variables only on power up, not on each reset.
    magic = MAGIC;
    disasm_lines  = 16;
    hexdump_lines = 16;
    disasm_on_lcd = 1;
    enable_trap1  = 0;

    //KH: Be sure the variable is initialized when board is reset
    //>>>+++--- 2400 b1=0x1A   b2=0x2B   FB: b1 changed from 0x1B
    //>>>+++--- 4800 b1=0x0A   b2=0x15   FB: b1 changed from 0x0B
    //>>>+++--- 9600 b1=0x02   b2=0x06
    //
    glob_b1 = 0x02;
    glob_b2 = 0x06;

    show_sr = 2; // symbolic format

    lcd_width = 16;
    lcd_lines = 2;

    shift_size = 512;
    clear_all_breakpoints();
  }
  disarm_breakpoints();
}


void main(void)
{
  init_globals();

  // Display startup banner
  print_led(0,"68008 ");
  led_buffer[1] = convert[VERSION[1]-'0'] | LED_SEG_POINT;
  led_buffer[0] = convert[VERSION[3]-'0'];

  *gpio1 = 0;

  InitLcd();

  display_PC = save_PC = INIT_PC; // pointed to RAM location after reset
  state      = STATE_AFTER_RESET;
  user_usp   = INIT_USP;
  user_ssp   = INIT_SSP;
  user_sr    = INIT_SR;
  tick       = 0;

  pstring("\r\n68008 MICROPROCESSOR KIT (C)2016 "
          "\r\nWith 9600 Baud Software UART!"
          "\r\nextended " VERSION " by Fred Bayer"
          "\r\n");

  for (;;)
    scan1();
}