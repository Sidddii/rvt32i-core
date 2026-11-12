/*
  Testbench for RVT32I Fibonacci Benchmark
  Verifies:
    1. Iterative Fibonacci with tag promotion and polymorphic stores
    2. Recursive Fibonacci fib(10) with stack frame and function call recursion
*/

module tag_testbench_fibonacci;

localparam MEM_ADDR_WIDTH = 16;
localparam TIMEOUT = (1<<20);

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
    for (i = 0; i < (1<<MEM_ADDR_WIDTH); i = i + 1)
        mem[i] = 8'h00;
    $readmemh("test_fibonacci.hex", mem);
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

// Function to read 32-bit word from memory array
function [31:0] read_word(input [15:0] addr);
    read_word = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
endfunction

integer expected_fib [0:10];
integer passed = 1;
integer val;

integer cycles = 0;
always @(posedge clock) begin
    cycles <= cycles + 1;
    if (cycles > TIMEOUT) begin
        $display("ERROR: Simulation timed out after %0d cycles!", TIMEOUT);
        $finish;
    end
end

always @(posedge clock) begin
    if (!reset && trap) begin
        $display("ERROR: Processor trapped! Trap at cycle %0d", cycles);
        $finish;
    end

    if (done) begin
        expected_fib[0]  = 0;
        expected_fib[1]  = 1;
        expected_fib[2]  = 1;
        expected_fib[3]  = 2;
        expected_fib[4]  = 3;
        expected_fib[5]  = 5;
        expected_fib[6]  = 8;
        expected_fib[7]  = 13;
        expected_fib[8]  = 21;
        expected_fib[9]  = 34;
        expected_fib[10] = 55;

        $display("");
        $display("==========================================================================");
        $display("          RVT32I FIBONACCI BENCHMARK VERIFICATION");
        $display("==========================================================================");
        $display("  Part 1: Iterative Fibonacci Sequence (Memory at 0x2000):");
        $display("  ------------------------------------------------------------------------");
        $display("  Idx  | Expected | Actual in Memory | Status");
        $display("  ------------------------------------------------------------------------");
        for (i = 0; i <= 10; i = i + 1) begin
            val = read_word(16'h2000 + (i * 4));
            if (val === expected_fib[i]) begin
                $display("  F%-3d | %-8d | %-16d | PASS [OK]", i, expected_fib[i], val);
            end else begin
                $display("  F%-3d | %-8d | %-16d | FAIL [MISMATCH]", i, expected_fib[i], val);
                passed = 0;
            end
        end

        $display("  ------------------------------------------------------------------------");
        $display("  Part 2: Recursive Fibonacci fib(10)");
        $display("  ------------------------------------------------------------------------");
        val = read_word(16'h2100);
        $display("  fib(10) Result at 0x2100: %0d (Expected: 55)", val);
        if (val === 55) begin
            $display("  Recursive fib(10) Status : PASS [OK]");
        end else begin
            $display("  Recursive fib(10) Status : FAIL [Expected 55, got %0d]", val);
            passed = 0;
        end

        $display("==========================================================================");
        if (passed) begin
            $display("  OVERALL RESULT: >>> ALL FIBONACCI TESTS PASSED 100%% ON RVT32I! <<<");
        end else begin
            $display("  OVERALL RESULT: >>> SOME FIBONACCI TESTS FAILED <<<");
        end
        $display("==========================================================================");
        $display("");
        $finish;
    end
end

endmodule
