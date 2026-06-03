// Testbench for Memory Controller
module tb_memory_controller;

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter MEM_DEPTH  = 16;

    reg clk;
    reg rst_n;
    reg read_en;
    reg write_en;
    reg [ADDR_WIDTH-1:0] addr;
    reg [DATA_WIDTH-1:0] write_data;
    wire [DATA_WIDTH-1:0] read_data;
    wire ready;

    // Instantiate the memory controller
    memory_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .read_en(read_en),
        .write_en(write_en),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data),
        .ready(ready)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        read_en = 0;
        write_en = 0;
        addr = 0;
        write_data = 0;

        // Apply reset
        #12;
        rst_n = 1;

        // Write data to address 3
        @(negedge clk);
        addr = 4'd3;
        write_data = 8'hA5;
        write_en = 1;
        read_en = 0;

        @(negedge clk);
        write_en = 0;

        // Write data to address 7
        @(negedge clk);
        addr = 4'd7;
        write_data = 8'h5A;
        write_en = 1;

        @(negedge clk);
        write_en = 0;

        // Read data from address 3
        @(negedge clk);
        addr = 4'd3;
        read_en = 1;

        @(negedge clk);
        read_en = 0;

        // Read data from address 7
        @(negedge clk);
        addr = 4'd7;
        read_en = 1;

        @(negedge clk);
        read_en = 0;

        // Read data from address 0 (should be default 0)
        @(negedge clk);
        addr = 4'd0;
        read_en = 1;

        @(negedge clk);
        read_en = 0;

        // Finish simulation
        #20;
        $finish;
    end

    // Monitor outputs
    initial begin
        $display("Time\tAddr\tWriteEn\tReadEn\tWriteData\tReadData\tReady");
        $monitor("%0t\t%0d\t%b\t%b\t%h\t\t%h\t\t%b",
                 $time, addr, write_en, read_en, write_data, read_data, ready);
    end

endmodule