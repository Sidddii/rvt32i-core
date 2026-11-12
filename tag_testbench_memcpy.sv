/*
  Testbench for Alfageme TRISC-V memcpy Benchmark
*/

module tag_testbench_memcpy;

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
    $readmemh("test_memcpy.hex", mem);
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

string copied_str = "";
always @(posedge clock) begin
    if (done) begin
        $display("");
        $display("==========================================================================");
        $display("       ALFAGEME TRISC-V MEMCPY BENCHMARK ON COMPLETE RVT32I ALU");
        $display("==========================================================================");
        
        copied_str = "";
        for (int j = 0; j < 14; j = j + 1) begin
            copied_str = {copied_str, mem[16'h2000 + j]};
        end

        $display("  Source string copied byte-by-byte using polymorphic 'st' + tagged ALU:");
        $display("  Copied string in memory: \"%s\"", copied_str);
        $display("  Hex bytes at 0x2000: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x",
            mem[16'h2000], mem[16'h2001], mem[16'h2002], mem[16'h2003],
            mem[16'h2004], mem[16'h2005], mem[16'h2006], mem[16'h2007],
            mem[16'h2008], mem[16'h2009], mem[16'h200a], mem[16'h200b],
            mem[16'h200c], mem[16'h200d]);

        if (mem[16'h2000] == "H" && mem[16'h2001] == "E" && mem[16'h2002] == "L" && mem[16'h2003] == "L" &&
            mem[16'h2004] == "O" && mem[16'h2005] == " " && mem[16'h2006] == "R" && mem[16'h2007] == "V" &&
            mem[16'h2008] == "T" && mem[16'h2009] == "3" && mem[16'h200a] == "2" && mem[16'h200b] == "I" &&
            mem[16'h200c] == "!") 
        begin
            $display("");
            $display("  RESULT: >>> MEMCPY PASSED 100%% WITH FULL RVT32I ALU + POLYMORPHIC ST! <<<");
        end else begin
            $display("");
            $display("  RESULT: >>> MEMCPY FAILED <<<");
        end
        $display("==========================================================================");
        $display("");
        $finish;
    end
end

integer cycles = 0;
always @(posedge clock) begin
    cycles <= cycles + 1;
    if (cycles > TIMEOUT) begin
        $display("ERROR: Simulation timed out after %0d cycles!", TIMEOUT);
        $finish;
    end
end

endmodule

