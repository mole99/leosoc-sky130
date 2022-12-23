// SPDX-FileCopyrightText: © 2022 Leo Moser <https://codeberg.org/mole99>
// SPDX-License-Identifier: GPL-3.0-or-later

void main(int mhartid);
void tx_uart(char data);
char rx_uart(void);
int rx_uart_nonblocking(char* data);
void write(const char* message);
int get_instret(void);
int get_cycle(void);
void write_int(int num);

volatile int*  led  = (int*) 0x000F0000;
volatile char* svga = (char*)0x00010000;
volatile int* uart  = (int*) 0x000A0000; 

void __attribute__ ((noinline)) busy_loop(unsigned max);

// 3 instructions per iteration
void __attribute__ ((noinline)) busy_loop(unsigned max) {
    for (unsigned i = 0; i < max; i++) {
        __asm__ volatile("" : "+g" (i) : :);
    }
}

#define RX_FLAG (1<<31) // high for received, clears on read
#define TX_FLAG (1<<30) // high on tx busy

void tx_uart(char data)
{
    while(*uart & TX_FLAG);
    *uart = data;
}

char rx_uart(void)
{
    while(!(*uart & RX_FLAG));
    return *uart;
}

int rx_uart_nonblocking(char* data)
{
    int value = *uart;
    *data = value & 0xFF;
    return((value & RX_FLAG) > 0);
}

void write(const char* message)
{
    while(*message != 0)
    {
        tx_uart(*message);
        message++;
    }
}

int get_instret(void)
{
    int instret;
    __asm__ volatile ("rdinstret %0" : "=r"(instret));
    return instret;
}

int get_cycle(void)
{
    int cycle;
    __asm__ volatile ("rdcycle %0" : "=r"(cycle));
    return cycle;
}

void write_int(int num)
{
    if (num > 9)
    {
        int a = num / 10;
        num -= 10 * a;
        write_int(a);
    }
    tx_uart('0' + num);
}

typedef struct {
    char r : 3;
    char g : 3;
    char b : 2;
} color_t;

void main(int mhartid)
{
    int value = 0;
    
    value = !value;
    *led = value;

    value = !value;
    *led = value;

    value = !value;
    *led = value;

    if (mhartid)
    {
        //tx_uart('#');
        while (1)
        {
            // Takes around 1s
            //busy_loop(500000);

            value = !value;
            *led = value;
        }
    }
    
    //write("Hello World on LeoRV32 :)\n");
    //write("Running on RV32I, f=12MHz\n");

    int width = 100;
    int height = 75;

    // Draw test graphics
    for (int y = 0; y < height; y++)
    {
        for (int x = 0; x < width; x++)
        {
            color_t color = {y * 8 / height, (height-y) * 8 / height, x * 4 / width};
            if (x == 0 || x == width-1 || y == 0 || y == height-1)
            {
                if (y%2) svga[y*width+x] = 0x00;
                else svga[y*width+x] = 0xFF;
            }
            else svga[y*width+x] = *(char*)&color;
        }
    }
    
    write("!");
    
    // Clear additional half line
    for (int x = 0; x < width; x++)
    {
        svga[height*width+x] = 0xFF;
    }

    while (1)
    {
        value = rx_uart();
        tx_uart(value);
        
        switch (value)
        {
            case 'I':
                write("\ninstret: ");
                write_int(get_instret());
                write("\n");
                break;
            case 'C':
                write("\ncycle:   ");
                write_int(get_cycle());
                write("\n");
                break;
            case 'R':
                write("\nratio cycle / instret:   ");
                int instret;
                __asm__ volatile ("rdinstret %0" : "=r"(instret));
                int cycle;
                __asm__ volatile ("rdcycle %0" : "=r"(cycle));
                write_int(cycle / instret);
                write("\n");
                break;
        }
    }
}

