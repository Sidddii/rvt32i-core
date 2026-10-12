/*
  Comprehensive RVT32I Load Verification Testbench
 
  Checks:
   - Correct 32 bit register value (handling sign vs zero extension)
   - Correct 3 bit physical tag
   - Offset byte and halfword extraction
   - Back to back load sequencing
   - Hardware protection of x0
 */

module tag_testbench;

localparam MEM_ADDR_WIDTH = 16;
localparam TIMEOUT = (1<<13);

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
    $readmemh("test_loads.hex", mem);
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
            $display("  [PASS] %-28s | Val: 0x%08h | Tag: %3b", test_name, actual_val, actual_tag);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] %-28s | Got val 0x%08h (exp 0x%08h), got tag %3b (exp %3b)",
                     test_name, actual_val, expected_val, actual_tag, expected_tag);
            fail_count = fail_count + 1;
        end
    end
endtask

always @(posedge clock) begin
    if (done) begin
        $display("");
        $display("==========================================================================");
        $display("         RVT32I COMPREHENSIVE LOAD VERIFICATION SUITE");
        $display("==========================================================================");
        $display("  Status Test Description             | Actual Value | Actual Tag");
        $display("  ------------------------------------------------------------------------");

        // Group 1: Positive values
        check_case("LB   positive byte",       dut.dbg_reg_x10, 32'h00000078, dut.dbg_tag_x10, TAG_I8);
        check_case("LBU  positive byte",       dut.dbg_reg_x11, 32'h00000078, dut.dbg_tag_x11, TAG_U8);
        check_case("LH   positive half",       dut.dbg_reg_x12, 32'h00005678, dut.dbg_tag_x12, TAG_I16);
        check_case("LHU  positive half",       dut.dbg_reg_x13, 32'h00005678, dut.dbg_tag_x13, TAG_U16);
        check_case("LW   positive word",       dut.dbg_reg_x14, 32'h12345678, dut.dbg_tag_x14, TAG_I32);

        // Group 2: Negative / MSB-set values (sign vs zero extension)
        check_case("LB   negative sign-extend", dut.dbg_reg_x15, 32'hffffffef, dut.dbg_tag_x15, TAG_I8);
        check_case("LBU  negative zero-extend", dut.dbg_reg_x16, 32'h000000ef, dut.dbg_tag_x16, TAG_U8);
        check_case("LH   negative sign-extend", dut.dbg_reg_x17, 32'hffffcdef, dut.dbg_tag_x17, TAG_I16);
        check_case("LHU  negative zero-extend", dut.dbg_reg_x18, 32'h0000cdef, dut.dbg_tag_x18, TAG_U16);
        check_case("LW   signed word MSB-set",  dut.dbg_reg_x19, 32'h89abcdef, dut.dbg_tag_x19, TAG_I32);

        // Group 3: Byte & Halfword Offsets within Word
        check_case("LBU  byte offset 1",       dut.dbg_reg_x20, 32'h000000cd, dut.dbg_tag_x20, TAG_U8);
        check_case("LBU  byte offset 2",       dut.dbg_reg_x21, 32'h000000ab, dut.dbg_tag_x21, TAG_U8);
        check_case("LBU  byte offset 3",       dut.dbg_reg_x22, 32'h00000089, dut.dbg_tag_x22, TAG_U8);
        check_case("LH   halfword offset 2",   dut.dbg_reg_x23, 32'hffff89ab, dut.dbg_tag_x23, TAG_I16);
        check_case("LHU  halfword offset 2",   dut.dbg_reg_x24, 32'h000089ab, dut.dbg_tag_x24, TAG_U16);

        // Group 4: Back-to-Back Pipeline Stress
        check_case("LB   back-to-back #1",     dut.dbg_reg_x25, 32'hffffffef, dut.dbg_tag_x25, TAG_I8);
        check_case("LH   back-to-back #2",     dut.dbg_reg_x26, 32'hffffcdef, dut.dbg_tag_x26, TAG_I16);

        // Group 5: Zero-Register Protection (x0)
        check_case("x0   constant-0 protection", dut.dbg_reg_x0,  32'h00000000, dut.dbg_tag_x0,  TAG_I32);

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

reg [31:0] cycles = 0;
always @(posedge clock) begin
    cycles <= cycles + 32'h1;
    if (trap || (cycles >= TIMEOUT)) begin
        $display("TIMEOUT or TRAP after %0d cycles (testbench did not complete cleanly)", cycles);
        $finish;
    end
end

endmodule
