/*
  Comprehensive RVT32I Store (ST) Verification Testbench
 
  Verifies:
   - ST with TAG_U8 (offset 0, 1, 2, 3 byte strobe isolation)
   - ST with TAG_I8 (signed byte store)
   - ST with TAG_U16 (offset 0, 2 halfword strobe isolation)
   - ST with TAG_I16 (signed halfword store)
   - ST with TAG_I32 (full word store)
   - ST with x0 (hardcoded TAG_I32 word zeroing)
   - Round-trip ST -> Load value & tag preservation
   - Sequential byte-by-byte word assembly
 */

module tag_testbench_stores;

localparam MEM_ADDR_WIDTH = 16;
localparam TIMEOUT = (1<<14);

`include "tag_defs.vh"

reg clock;
reg reset = 1'b1;
reg stall = 1'b0;
wire trap;

wire [31:0] imem_addr;
reg  [31:0] imem_data;

wire        dmem_valid;
wire [31:0] dmem_addr;
wire [ 3:0] dmem_wstrb;
wire [31:0] dmem_wdata;
reg  [31:0] dmem_rdata;

reg  [31:0] irq = 'b0;

always #5 clock = clock === 1'b0;
always @(posedge clock) reset <= 0;

reg [7:0] mem [0:(1<<MEM_ADDR_WIDTH)-1];

wire wr_in_mem_range = (dmem_addr[31:2] < (1<<MEM_ADDR_WIDTH));
wire wr_in_output    = (dmem_addr == 32'h 02000000);

reg done = 0;
always @(posedge clock) begin
    if (!stall && !reset && dmem_valid && wr_in_output &&
        dmem_wstrb != 0 && dmem_wdata[7:0] == 8'hAA)
    begin
        done <= 1;
    end
end

integer i;
always @(posedge clock) begin
    if (!stall && !reset) begin
        imem_data <= {
            mem[{imem_addr[MEM_ADDR_WIDTH-1:2], 2'b11}],
            mem[{imem_addr[MEM_ADDR_WIDTH-1:2], 2'b10}],
            mem[{imem_addr[MEM_ADDR_WIDTH-1:2], 2'b01}],
            mem[{imem_addr[MEM_ADDR_WIDTH-1:2], 2'b00}]
        };

        if (dmem_valid) begin
            dmem_rdata <= {
                mem[{dmem_addr[MEM_ADDR_WIDTH-1:2], 2'b11}],
                mem[{dmem_addr[MEM_ADDR_WIDTH-1:2], 2'b10}],
                mem[{dmem_addr[MEM_ADDR_WIDTH-1:2], 2'b01}],
                mem[{dmem_addr[MEM_ADDR_WIDTH-1:2], 2'b00}]
            };
            for (i=0; i<4; i=i+1) begin
                if (dmem_wstrb[i]) begin
                    if (wr_in_mem_range)
                        mem[{dmem_addr[MEM_ADDR_WIDTH-1:2], i[1:0]}] <= dmem_wdata[(i*8)+: 8];
                    dmem_rdata <= 'hx;
                end
            end
        end else begin
            dmem_rdata <= 32'h XXXX_XXXX;
        end
    end
end

initial begin
    $readmemh("test_stores.hex", mem);
end

nerv dut (
    .clock(clock),
    .reset(reset),
    .stall(stall),
    .trap(trap),

    .imem_addr(imem_addr),
    .imem_data(stall ? 32'bx : imem_data),

    .dmem_valid(dmem_valid),
    .dmem_addr(dmem_addr),
    .dmem_wstrb(dmem_wstrb),
    .dmem_wdata(dmem_wdata),
    .dmem_rdata(stall ? 32'bx : dmem_rdata),

    .irq(irq)
);

// -----------------------------------------------------------------------------
// Test evaluation helper
// -----------------------------------------------------------------------------
integer pass_count = 0;
integer fail_count = 0;

task check_case;
    input [255:0] test_name;
    input [31:0]  actual_val;
    input [31:0]  expected_val;
    input [2:0]   actual_tag;
    input [2:0]   expected_tag;
    reg val_ok;
    reg tag_ok;
    begin
        val_ok = (actual_val === expected_val);
        tag_ok = (actual_tag === expected_tag);

        if (val_ok && tag_ok) begin
            $display("  [PASS] %-30s | Val: 0x%08h | Tag: %3b", test_name, actual_val, actual_tag);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] %-30s | Got val 0x%08h (exp 0x%08h), got tag %3b (exp %3b)",
                     test_name, actual_val, expected_val, actual_tag, expected_tag);
            fail_count = fail_count + 1;
        end
    end
endtask

task check_val_only;
    input [255:0] test_name;
    input [31:0]  actual_val;
    input [31:0]  expected_val;
    reg val_ok;
    begin
        val_ok = (actual_val === expected_val);

        if (val_ok) begin
            $display("  [PASS] %-30s | Mem Word: 0x%08h", test_name, actual_val);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] %-30s | Got 0x%08h (expected 0x%08h)", test_name, actual_val, expected_val);
            fail_count = fail_count + 1;
        end
    end
endtask

always @(posedge clock) begin
    if (done) begin
        $display("");
        $display("==========================================================================");
        $display("         RVT32I COMPREHENSIVE STORE (ST) VERIFICATION SUITE");
        $display("==========================================================================");
        $display("  Status Test Description               | Details");
        $display("  ------------------------------------------------------------------------");

        // Group 1: 8-bit Stores (TAG_U8 / TAG_I8) - Byte strobe isolation
        check_val_only("ST u8 offset 0 (strb 0001)", dut.dbg_reg_x11, 32'hffffff78);
        check_val_only("ST u8 offset 1 (strb 0010)", dut.dbg_reg_x12, 32'hffff78ff);
        check_val_only("ST u8 offset 2 (strb 0100)", dut.dbg_reg_x13, 32'hff78ffff);
        check_val_only("ST u8 offset 3 (strb 1000)", dut.dbg_reg_x14, 32'h78ffffff);
        check_val_only("ST i8 offset 0 (strb 0001)", dut.dbg_reg_x15, 32'hffffffef);

        // Group 2: 16-bit Stores (TAG_U16 / TAG_I16) - Halfword strobe isolation
        check_val_only("ST u16 offset 0 (strb 0011)", dut.dbg_reg_x16, 32'hffff5678);
        check_val_only("ST u16 offset 2 (strb 1100)", dut.dbg_reg_x17, 32'h5678ffff);
        check_val_only("ST i16 offset 0 (strb 0011)", dut.dbg_reg_x18, 32'hffffcdef);

        // Group 3: 32-bit Stores & Zero Register Protection
        check_val_only("ST i32 full word (strb 1111)", dut.dbg_reg_x19, 32'h12345678);
        check_val_only("ST x0 zero-clear (strb 1111)", dut.dbg_reg_x20, 32'h00000000);

        // Group 4: Round-trip Store then Load Value & Tag Preservation
        check_case("Roundtrip ST -> LBU", dut.dbg_reg_x21, 32'h00000078, dut.dbg_tag_x21, TAG_U8);
        check_case("Roundtrip ST -> LB",  dut.dbg_reg_x22, 32'hffffffef, dut.dbg_tag_x22, TAG_I8);
        check_case("Roundtrip ST -> LHU", dut.dbg_reg_x23, 32'h00005678, dut.dbg_tag_x23, TAG_U16);
        check_case("Roundtrip ST -> LH",  dut.dbg_reg_x24, 32'hffffcdef, dut.dbg_tag_x24, TAG_I16);
        check_case("Roundtrip ST -> LW",  dut.dbg_reg_x25, 32'h12345678, dut.dbg_tag_x25, TAG_I32);

        // Group 5: Sequential Byte Assembly into single word
        check_val_only("Sequential 4-byte assembly",   dut.dbg_reg_x26, 32'h44332211);

        $display("  ------------------------------------------------------------------------");
        $display("  SUMMARY: %0d PASSED, %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display("  RESULT: >>> ALL TESTS PASSED (100%%) <<<");
        else
            $display("  RESULT: >>> SOME TESTS FAILED <<<");
        $display("==========================================================================");
        $display("");
        $finish;
    end
end

// Timeout safeguard
integer cycles = 0;
always @(posedge clock) begin
    cycles <= cycles + 1;
    if (cycles > TIMEOUT) begin
        $display("ERROR: Simulation timed out after %0d cycles!", TIMEOUT);
        $finish;
    end
end

endmodule

