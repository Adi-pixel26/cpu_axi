typedef unsigned int u32;
typedef int s32;

#define RESULT_BASE   ((volatile u32 *)0x00001000)
#define MMIO_LED_BASE ((volatile u32 *)0x04000000)  /* MMIO Peripheral */

/* ========================================================
 * LED Control & Helper Functions
 * ======================================================== */

/* Write directly to all 6 LEDs (bitmask: bits 0 to 5) */
static inline void led_write(u32 val)
{
    *MMIO_LED_BASE = val & 0x3F;
}

/* Read back current state of all 6 LEDs */
static inline u32 led_read(void)
{
    return *MMIO_LED_BASE & 0x3F;
}

/* ========================================================
 * CPU Test Calculations
 * ======================================================== */
static volatile u32 numbers[8] = {
    10, 20, 30, 40, 50, 60, 70, 80
};

static volatile u32 bss_test[4];

__attribute__((noinline))
static u32 sum_array(volatile u32 *array, u32 count)
{
    u32 sum = 0;
    u32 i;
    for (i = 0; i < count; i++)
        sum += array[i];
    return sum;
}

__attribute__((noinline))
static s32 signed_divide(s32 a, s32 b)
{
    return a / b;
}

__attribute__((noinline))
static u32 stack_probe(u32 value)
{
    volatile u32 local[4];
    local[0] = value;
    local[1] = value + 1;
    local[2] = local[0] ^ local[1];
    local[3] = local[2] + 0x55;
    return local[3];
}

/* ========================================================
 * Main Program
 * ======================================================== */
int main(void)
{
    volatile u32 *result = RESULT_BASE;

    u32 sum      = sum_array(numbers, 8);      /* 360 */
    u32 product  = 123 * 45;                   /* 5535 */
    u32 quotient = product / 45;               /* 123 */

    result[0] = sum;
    result[1] = product;
    result[2] = quotient;
    result[3] = 0x12345678;
    result[4] = bss_test[0];
    result[5] = (u32)signed_divide(-84, 7);
    result[6] = stack_probe(0x1234);
    result[7] = sum + product;

    /* ========================================================
     * CONTROLLING SPECIFIC LEDs
     * ======================================================== */

    // Keep all six CPU-controlled LEDs visibly ON for the first MMIO test.
    // These map to physical LEDR[9:4]; LEDR[3:0] show debug status.
    led_write(0x3F);

    // Read the same hardware register back for JTAG verification.
    result[8] = led_read();

    while (1) {
        /* Leave the LEDs ON until the CPU is reset. */
    }
}
