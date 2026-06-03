// Testbench for simple_cache
module tb_simple_cache;

    reg clk;
    reg rst;
    reg read;
    reg write;
    reg [3:0] addr;
    reg [7:0] wdata;
    wire [7:0] rdata;
    wire hit;

    // Instantiate cache
    simple_cache uut (
        .clk(clk),
        .rst(rst),
        .read(read),
        .write(write),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata),
        .hit(hit)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    // Test sequence
    initial begin
        // Initialize
        rst = 1; read = 0; write = 0; addr = 0; wdata = 0;
        #12;
        rst = 0;

        // 1. Read from address 0 (miss, fill cache)
        @(negedge clk);
        addr = 4'h0; read = 1; write = 0; wdata = 0;
        @(negedge clk);
        read = 0;

        // 2. Read from address 0 again (should be hit)
        @(negedge clk);
        addr = 4'h0; read = 1; write = 0;
        @(negedge clk);
        read = 0;

        // 3. Write to address 0 (should be hit)
        @(negedge clk);
        addr = 4'h0; write = 1; read = 0; wdata = 8'hAA;
        @(negedge clk);
        write = 0;

        // 4. Read from address 0 (should return 0xAA, hit)
        @(negedge clk);
        addr = 4'h0; read = 1; write = 0;
        @(negedge clk);
        read = 0;

        // 5. Read from address 4 (different index, miss)
        @(negedge clk);
        addr = 4'h4; read = 1; write = 0;
        @(negedge clk);
        read = 0;

        // 6. Write to address 8 (miss, no allocation)
        @(negedge clk);
        addr = 4'h8; write = 1; read = 0; wdata = 8'h55;
        @(negedge clk);
        write = 0;

        // 7. Read from address 8 (miss, then fill)
        @(negedge clk);
        addr = 4'h8; read = 1; write = 0;
        @(negedge clk);
        read = 0;

        // 8. Read from address 8 again (hit)
        @(negedge clk);
        addr = 4'h8; read = 1; write = 0;
        @(negedge clk);
        read = 0;

        // End simulation
        #20;
        $finish;
    end

    // Monitor outputs
    initial begin
        $display("Time\tAddr\tRead\tWrite\tWData\tRData\tHit");
        $monitor("%0t\t%h\t%b\t%b\t%h\t%h\t%b", $time, addr, read, write, wdata, rdata, hit);
    end

endmodule