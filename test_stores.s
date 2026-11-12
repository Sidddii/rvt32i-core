/*
  Comprehensive RVT32I Store Verification Suite (ST)
  
  Tests:
    1. ST with TAG_U8: byte strobe 0001 at offset 0 (preserves upper 3 bytes)
    2. ST with TAG_U8: byte strobe 0010 at offset 1
    3. ST with TAG_U8: byte strobe 0100 at offset 2
    4. ST with TAG_U8: byte strobe 1000 at offset 3
    5. ST with TAG_I8: signed byte store
    6. ST with TAG_U16: halfword strobe 0011 at offset 0 (preserves upper 2 bytes)
    7. ST with TAG_U16: halfword strobe 1100 at offset 2 (preserves lower 2 bytes)
    8. ST with TAG_I16: signed halfword store
    9. ST with TAG_I32: full word store (strobe 1111)
   10. ST with x0 (hardcoded TAG_I32): full word zeroing (strobe 1111)
   11. Round-trip ST -> LBU (value & tag check)
   12. Round-trip ST -> LB  (value & tag check)
   13. Round-trip ST -> LHU (value & tag check)
   14. Round-trip ST -> LH  (value & tag check)
   15. Round-trip ST -> LW  (value & tag check)
   16. Sequential multi-byte assembly into a single word
*/

.macro st reg, addr
    sb \reg, \addr
.endm

.section .text
.global main

main:
    # -------------------------------------------------------------
    # Step 1: Base address for source data (0x1000) and dest (0x2000)
    # -------------------------------------------------------------
    li   x4, 0x1000         # Source data base address
    li   x5, 0x2000         # Destination write buffer base address

    # Setup source data in memory using standard SW
    li   x1, 0xFFFFFFFF
    sw   x1, 0(x4)          # 0x1000: 0xFFFFFFFF (for resetting test words)
    li   x1, 0x12345678
    sw   x1, 4(x4)          # 0x1004: 0x12345678
    li   x1, 0x89ABCDEF
    sw   x1, 8(x4)          # 0x1008: 0x89ABCDEF
    li   x1, 0xDEADBEEF
    sw   x1, 12(x4)         # 0x100C: 0xDEADBEEF
    li   x1, 0x44332211
    sw   x1, 16(x4)         # 0x1010: 0x44332211

    # Load registers to establish specific tags:
    lbu  x6, 4(x4)          # x6  = 0x00000078, tag TAG_U8  (000)
    lb   x7, 8(x4)          # x7  = 0xFFFFFFEF, tag TAG_I8  (100)
    lhu  x8, 4(x4)          # x8  = 0x00005678, tag TAG_U16 (001)
    lh   x9, 8(x4)          # x9  = 0xFFFFCDEF, tag TAG_I16 (101)
    lw   x10, 4(x4)         # x10 = 0x12345678, tag TAG_I32 (110)

    # =============================================================
    # Test 1: ST u8 at offset 0 (strobe 0001)
    # =============================================================
    lw   x1, 0(x4)          # x1 = 0xFFFFFFFF
    sw   x1, 0(x5)          # Initialise 0x2000 to 0xFFFFFFFF
    st   x6, 0(x5)          # Store byte 0x78 (TAG_U8)
    lw   x11, 0(x5)         # x11 should be 0xFFFFFF78

    # =============================================================
    # Test 2: ST u8 at offset 1 (strobe 0010)
    # =============================================================
    sw   x1, 4(x5)          # Initialise 0x2004 to 0xFFFFFFFF
    st   x6, 5(x5)          # Store byte 0x78 at 0x2005
    lw   x12, 4(x5)         # x12 should be 0xFFFF78FF

    # =============================================================
    # Test 3: ST u8 at offset 2 (strobe 0100)
    # =============================================================
    sw   x1, 8(x5)          # Initialise 0x2008 to 0xFFFFFFFF
    st   x6, 10(x5)         # Store byte 0x78 at 0x200A
    lw   x13, 8(x5)         # x13 should be 0xFF78FFFF

    # =============================================================
    # Test 4: ST u8 at offset 3 (strobe 1000)
    # =============================================================
    sw   x1, 12(x5)         # Initialise 0x200C to 0xFFFFFFFF
    st   x6, 15(x5)         # Store byte 0x78 at 0x200F
    lw   x14, 12(x5)        # x14 should be 0x78FFFFFF

    # =============================================================
    # Test 5: ST i8 at offset 0 (strobe 0001, signed byte)
    # =============================================================
    sw   x1, 16(x5)         # Initialise 0x2010 to 0xFFFFFFFF
    st   x7, 16(x5)         # Store byte 0xEF (TAG_I8)
    lw   x15, 16(x5)        # x15 should be 0xFFFFFFEF

    # =============================================================
    # Test 6: ST u16 at offset 0 (strobe 0011)
    # =============================================================
    sw   x1, 20(x5)         # Initialise 0x2014 to 0xFFFFFFFF
    st   x8, 20(x5)         # Store half 0x5678 (TAG_U16)
    lw   x16, 20(x5)        # x16 should be 0xFFFF5678

    # =============================================================
    # Test 7: ST u16 at offset 2 (strobe 1100)
    # =============================================================
    sw   x1, 24(x5)         # Initialise 0x2018 to 0xFFFFFFFF
    st   x8, 26(x5)         # Store half 0x5678 at 0x201A
    lw   x17, 24(x5)        # x17 should be 0x5678FFFF

    # =============================================================
    # Test 8: ST i16 at offset 0 (strobe 0011, signed half)
    # =============================================================
    sw   x1, 28(x5)         # Initialise 0x201C to 0xFFFFFFFF
    st   x9, 28(x5)         # Store half 0xCDEF (TAG_I16)
    lw   x18, 28(x5)        # x18 should be 0xFFFFCDEF

    # =============================================================
    # Test 9: ST i32 at offset 0 (strobe 1111)
    # =============================================================
    sw   x1, 32(x5)         # Initialise 0x2020 to 0xFFFFFFFF
    st   x10, 32(x5)        # Store word 0x12345678 (TAG_I32)
    lw   x19, 32(x5)        # x19 should be 0x12345678

    # =============================================================
    # Test 10: ST x0 (hardcoded TAG_I32 zeroing)
    # =============================================================
    lw   x1, 12(x4)         # x1 = 0xDEADBEEF
    sw   x1, 36(x5)         # Initialise 0x2024 to 0xDEADBEEF
    st   x0, 36(x5)         # Store x0 (TAG_I32)
    lw   x20, 36(x5)        # x20 should be 0x00000000

    # =============================================================
    # Test 11-15: Round-trip Store then Load Tag Verification
    # =============================================================
    st   x6, 40(x5)         # Store u8 (0x78)
    lbu  x21, 40(x5)        # Load u8 back -> val 0x78, tag TAG_U8

    st   x7, 44(x5)         # Store i8 (0xEF)
    lb   x22, 44(x5)        # Load i8 back -> val 0xFFFFFFEF, tag TAG_I8

    st   x8, 48(x5)         # Store u16 (0x5678)
    lhu  x23, 48(x5)        # Load u16 back -> val 0x5678, tag TAG_U16

    st   x9, 52(x5)         # Store i16 (0xCDEF)
    lh   x24, 52(x5)        # Load i16 back -> val 0xFFFFCDEF, tag TAG_I16

    st   x10, 56(x5)        # Store i32 (0x12345678)
    lw   x25, 56(x5)        # Load i32 back -> val 0x12345678, tag TAG_I32

    # =============================================================
    # Test 16: Sequential Byte-by-Byte Assembly into a Single Word
    # =============================================================
    sw   x0, 60(x5)         # Clear word at 0x203C to 0x00000000
    lbu  x1, 16(x4)         # 0x11
    lbu  x2, 17(x4)         # 0x22
    lbu  x3, 18(x4)         # 0x33
    lbu  x27, 19(x4)        # 0x44
    st   x1, 60(x5)         # Byte 0 = 0x11
    st   x2, 61(x5)         # Byte 1 = 0x22
    st   x3, 62(x5)         # Byte 2 = 0x33
    st   x27, 63(x5)        # Byte 3 = 0x44
    lw   x26, 60(x5)        # x26 should be 0x44332211

    # =============================================================
    # Done signal: write 0xAA to 0x02000000
    # =============================================================
    li   x28, 0x02000000
    li   x29, 0xAA
    sw   x29, 0(x28)

hang:
    j    hang

