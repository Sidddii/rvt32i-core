/*
  Alfageme TRISC-V memcpy Benchmark (Page 33)
  Verifies:
    1. Arithmetic pointer additions (add, addi) with ALU tag promotion
    2. Tagged byte loading (lbu -> TAG_U8)
    3. Polymorphic byte store (st -> uses TAG_U8 for 1-byte store)
    4. Loop branching (bne, beqz)
*/

.macro st reg, addr
    sb \reg, \addr
.endm

.section .text
.global main

main:
    li   a0, 0x2000          # dest buffer = 0x2000
    la   a1, src_string      # src buffer
    li   a2, 14              # len = 14 bytes ("HELLO RVT32I!\0")

    # Call memcpy(dest=a0, src=a1, len=a2)
    jal  ra, memcpy

    # Signal completion: write 0xAA to 0x02000000
    li   t0, 0x02000000
    li   t1, 0xAA
    sw   t1, 0(t0)

hang:
    j    hang

# -------------------------------------------------------------
# memcpy implementation directly from Alfageme (TRISC-V) Page 33:
# -------------------------------------------------------------
memcpy:
    beqz a2, .LBB0_3
    add  a2, a0, a2          # a2 = dest_end = dest + len
    mv   a3, a0              # a3 = curr_dest = dest
.LBB0_2:
    lbu  a4, 0(a1)           # Load byte -> gets tag TAG_U8!
    addi a1, a1, 1           # Increment src
    addi a5, a3, 1           # Increment dest
    st   a4, 0(a3)           # POLYMORPHIC STORE: writes 1 byte using a4's tag!
    mv   a3, a5
    bne  a5, a2, .LBB0_2     # Loop until all bytes copied
.LBB0_3:
    ret

.section .rodata
src_string:
    .string "HELLO RVT32I!"

