// 3 Bits Tag Definition
// Bit 2: Sign (1 = Signed, 0 = Unsigned)
// Bits [1:0]: Width (00 = 8-bit, 01 = 16-bit, 10 = 32-bit, 11 = reserved)




localparam [2:0] TAG_U8  = 3'b000; // Unsigned 8 bit
localparam [2:0] TAG_U16 = 3'b001; // Unsigned 16 bit
localparam [2:0] TAG_U32 = 3'b010; // Unsigned 32 bit
localparam [2:0] TAG_I8  = 3'b100; // Signed 8 bit
localparam [2:0] TAG_I16 = 3'b101; // Signed 16 bit
localparam [2:0] TAG_I32 = 3'b110; // Signed 32 bit (default / reset)