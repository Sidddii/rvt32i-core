/*
 Canonical Form Normalizer for RVT32I

 Enforces the architectural invariant that all values in the register file are stored in canonical form.:
 Narrow values (8-bit, 16-bit) stored in the 32-bit register file must always
 be canonicalized (sign extended or zero extended according to their tag)
 at writeback.
 */

module tag_canonicalizer (
    input  wire [31:0] in_val,
    input  wire [2:0]  in_tag,
    output reg  [31:0] out_val
);

    `include "tag_defs.vh"

    always @(*) begin
        case (in_tag)
            TAG_U8:  out_val = {24'b0, in_val[7:0]}; // If the tag is unsigned 8 bit, zero extend to 32 bits
            TAG_I8:  out_val = {{24{in_val[7]}}, in_val[7:0]}; // If the tag is signed 8-bit, sign extend to 32 bits
            TAG_U16: out_val = {16'b0, in_val[15:0]}; // If the tag is unsigned 16 bit, zero extend to 32 bits
            TAG_I16: out_val = {{16{in_val[15]}}, in_val[15:0]}; // If the tag is signed 16-bit, sign extend to 32 bits
            TAG_U32: out_val = in_val; // If the tag is unsigned or signed 32 bit, no change needed
            TAG_I32: out_val = in_val;
            default: out_val = in_val; // Default case - no change needed
        endcase
    end

endmodule

