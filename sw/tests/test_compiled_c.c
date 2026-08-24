// test_compiled_c: real compiler output (calls/stack, structs/arrays, loops, arithmetic) against the core.

#define SIM_PUTC (*(volatile unsigned char *)0x10000008)

static void sim_puts(const char *s) {
    while (*s) SIM_PUTC = (unsigned char)*s++;
}

// ---- function calls / stack ----

static int add3(int a, int b, int c) {
    return a + b + c;
}

static int fib(int n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);   // forces real stack use via recursion
}

// ---- struct / array access ----

struct point { int x; int y; };

static int sum_points(struct point *pts, int n) {
    int total = 0;
    for (int i = 0; i < n; i++)
        total += pts[i].x + pts[i].y;
    return total;
}

// ---- loop / shift-and-add arithmetic ----

static int sum_stride_five(void) {
    int total = 0;
    for (int i = 1; i <= 4; i++)
        total += i * 5;   // variable * constant -> shift-and-add, no HW multiply
    return total;
}

int main(void) {
    sim_puts("test_compiled_c: start\n");

    int a = add3(1, 2, 3);
    if (a != 6) return 1;

    int f = fib(8);
    if (f != 21) return 2;

    struct point pts[3];
    pts[0].x = 1; pts[0].y = 2;
    pts[1].x = 3; pts[1].y = 4;
    pts[2].x = 5; pts[2].y = 6;
    int s = sum_points(pts, 3);
    if (s != 21) return 3;

    int t = sum_stride_five();
    if (t != 50) return 4;

    sim_puts("test_compiled_c: pass\n");
    return 0;
}
