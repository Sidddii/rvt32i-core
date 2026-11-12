/*
  RVT32I Fibonacci Benchmark Test
  Based on Baig & Dalsgaard (2026).
  
  Tests:
    1. Iterative Fibonacci with Tag Promotion and Polymorphic Store:
       - F0 loaded via lbu (TAG_U8)
       - F1 loaded via lhu (TAG_U16)
       - Subsequent Fi computed via ADD (tag promotion)
       - Values written to buffer via polymorphic ST
    2. Recursive Fibonacci (Listing A.5 / C.5 from Baig & Dalsgaard):
       - fib(10) computed via recursive function calls (jal / jalr / stack frame)
       - Expected result: fib(10) = 55 (0x37)
*/

.section .text
.global main

main:
    # Set up stack pointer (aligned to 16 bytes)
    li   sp, 0x4000

    # -------------------------------------------------------------
    # Part 1: Iterative Fibonacci (0 .. 10)
    # -------------------------------------------------------------
    la   t0, initial_f0      # Load pointer to initial F0
    la   t1, initial_f1      # Load pointer to initial F1
    lbu  s0, 0(t0)           # s0 = F0 = 0 (TAG_U8)
    lhu  s1, 0(t1)           # s1 = F1 = 1 (TAG_U16)

    li   t2, 0x2000          # Output buffer for iterative sequence
    sw   s0, 0(t2)           # Store F0 (offset 0)
    sw   s1, 4(t2)           # Store F1 (offset 4)

    li   t3, 2               # Loop index i = 2
    li   t4, 11              # Loop limit = 11 (computes up to F10)
    addi t5, t2, 8           # Current write pointer = 0x2008

iter_loop:
    add  s2, s0, s1          # s2 = s0 + s1 (tag promotion in hardware!)
    sw   s2, 0(t5)           # Store Fi using polymorphic ST
    mv   s0, s1              # s0 = s1
    mv   s1, s2              # s1 = s2
    addi t5, t5, 4           # Increment write pointer
    addi t3, t3, 1           # i++
    bne  t3, t4, iter_loop   # Loop until i == 11

    # -------------------------------------------------------------
    # Part 2: Recursive Fibonacci fib(10)
    # -------------------------------------------------------------
    li   a0, 10              # Compute fib(10)
    jal  ra, fib_recursive
    # Result returns in a0 = 55 (0x37)
    li   t2, 0x2100
    sw   a0, 0(t2)           # Store recursive result at 0x2100

    # -------------------------------------------------------------
    # Signal Completion to Testbench: write 0xAA to 0x02000000
    # -------------------------------------------------------------
    li   t0, 0x02000000
    li   t1, 0xAA
    sw   t1, 0(t0)

hang:
    j    hang

# -----------------------------------------------------------------
# Recursive fib(n):
#   if (n <= 1) return n;
#   return fib(n - 1) + fib(n - 2);
# -----------------------------------------------------------------
fib_recursive:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    mv   s0, a0              # s0 = n
    li   t0, 1
    ble  s0, t0, fib_base

    # fib(n - 1)
    addi a0, s0, -1
    jal  ra, fib_recursive
    mv   s1, a0              # s1 = fib(n - 1)

    # fib(n - 2)
    addi a0, s0, -2
    jal  ra, fib_recursive
    # a0 = fib(n - 2)

    # return fib(n - 1) + fib(n - 2)
    add  a0, s1, a0
    j    fib_exit

fib_base:
    mv   a0, s0

fib_exit:
    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

.section .rodata
.balign 4
initial_f0:
    .byte 0
.balign 2
initial_f1:
    .half 1
