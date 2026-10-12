/*
 Comprehensive Load Verification Suite for RVT32I
  Covers:
    1. Positive values: LB, LBU, LH, LHU, LW, LWU
    2. Negative values (sign vs zero extension): LB, LBU, LH, LHU, LW, LWU
    3. Byte offsets within word (offsets +0, +1, +2, +3)
    4. Halfword offsets within word (offsets +0, +2)
    5. x0 protection: loading to x0 must not change x0 value (0) or tag (i32)
    6. Back-to-back pipeline loads without intervening instructions
 
 Output: writes magic 0xAA to 0x02000000 when complete.
 */

.section .text
.global main

main:
    # -------------------------------------------------------------
    # Step 1: Base address at 0x1000
    # -------------------------------------------------------------
    li   x5, 0x1000

    # -------------------------------------------------------------
    # Memory Pattern 1: Positive values
    # Word at 0x1000: 0x12345678
    #   Byte 0 = 0x78 (positive)
    #   Half 0 = 0x5678 (positive)
    # -------------------------------------------------------------
    li   x6, 0x12345678
    sw   x6, 0(x5)

    # -------------------------------------------------------------
    # Memory Pattern 2: Negative/MSB-set values
    # Word at 0x1004: 0x89ABCDEF
    #   Byte 0 = 0xEF (MSB set, negative for signed)
    #   Byte 1 = 0xCD (MSB set)
    #   Byte 2 = 0xAB (MSB set)
    #   Byte 3 = 0x89 (MSB set)
    #   Half 0 = 0xCDEF (MSB set, negative for signed)
    #   Half 1 = 0x89AB (MSB set, negative for signed)
    #   Word   = 0x89ABCDEF (MSB set)
    # -------------------------------------------------------------
    li   x6, 0x89ABCDEF
    sw   x6, 4(x5)

    # =============================================================
    # Test Group 1: Positive Values
    # =============================================================
    lb   x10, 0(x5)         # LB  pos  -> expected 0x00000078, tag i8  (100)
    lbu  x11, 0(x5)         # LBU pos  -> expected 0x00000078, tag u8  (000)
    lh   x12, 0(x5)         # LH  pos  -> expected 0x00005678, tag i16 (101)
    lhu  x13, 0(x5)         # LHU pos  -> expected 0x00005678, tag u16 (001)
    lw   x14, 0(x5)         # LW  pos  -> expected 0x12345678, tag i32 (110)

    # =============================================================
    # Test Group 2: Negative Values (Sign vs Zero Extension)
    # =============================================================
    lb   x15, 4(x5)         # LB  neg  -> expected 0xFFFFFFEF, tag i8  (100)
    lbu  x16, 4(x5)         # LBU neg  -> expected 0x000000EF, tag u8  (000)
    lh   x17, 4(x5)         # LH  neg  -> expected 0xFFFFCDEF, tag i16 (101)
    lhu  x18, 4(x5)         # LHU neg  -> expected 0x0000CDEF, tag u16 (001)
    lw   x19, 4(x5)         # LW  neg  -> expected 0x89ABCDEF, tag i32 (110)

    # =============================================================
    # Test Group 3: Byte & Halfword Offset Addressing
    # =============================================================
    lbu  x20, 5(x5)         # Byte at offset 1 -> 0xCD, tag u8
    lbu  x21, 6(x5)         # Byte at offset 2 -> 0xAB, tag u8
    lbu  x22, 7(x5)         # Byte at offset 3 -> 0x89, tag u8
    lh   x23, 6(x5)         # Half at offset 2 -> 0xFFFF89AB, tag i16
    lhu  x24, 6(x5)         # Half at offset 2 -> 0x000089AB, tag u16

    # =============================================================
    # Test Group 4: Back-to-Back Pipeline Stress Loads
    # (Two consecutive loads without any other instructions)
    # =============================================================
    lb   x25, 4(x5)         # 1st load
    lh   x26, 4(x5)         # 2nd consecutive load immediately following

    # =============================================================
    # Test Group 5: x0 Protection Rule
    # Attempting to load into x0 must not modify x0 (value remains 0,
    # tag remains i32)
    # =============================================================
    lb   x0, 4(x5)          # Must be discarded

    # =============================================================
    # Signal Done to Testbench: write 0xAA to 0x02000000
    # =============================================================
    li   x7, 0x02000000
    li   x8, 0xAA
    sw   x8, 0(x7)

hang:
    j    hang
