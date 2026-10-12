/*
Tag Register File

Maintains a 32 entry x 3 bit tag storage parallel to the standard RV32I integer register file.
 - x0 is hardwired to TAG_I32 (3'b110).
 - Writes to x0 are ignored.
 - On reset, all entries initialize to TAG_I32.
 */

module tag_regfile #(
    parameter NUMREGS = 32
) (
    input  wire        clock,
    input  wire        reset,

    // Read ports
    input  wire [4:0]  rs1_addr,
    output wire [2:0]  rs1_tag,

    input  wire [4:0]  rs2_addr,
    output wire [2:0]  rs2_tag,

    // Write port
    input  wire        wr_en,
    input  wire [4:0]  wr_addr,
    input  wire [2:0]  wr_tag
);

    `include "tag_defs.vh"

    reg [2:0] tags [0:NUMREGS-1];

    // Read ports: x0 is hardwired to TAG_I32
    assign rs1_tag = (rs1_addr == 5'd0) ? TAG_I32 : tags[rs1_addr];
    assign rs2_tag = (rs2_addr == 5'd0) ? TAG_I32 : tags[rs2_addr];

    // Synchronous write & synchronous reset
    integer i;
    always @(posedge clock) begin
        if (reset) begin
            for (i = 0; i < NUMREGS; i = i + 1)
                tags[i] <= TAG_I32;
        end else if (wr_en && wr_addr != 5'd0) begin
            tags[wr_addr] <= wr_tag;
        end
    end

endmodule

