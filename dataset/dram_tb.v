// Testbench for DRAM
module dram_tb;

    // Parameters
    parameter ADDR_WIDTH = 4;
    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;
    parameter REFRESH_CYCLES = 8;

    // Signals
    reg clk;
    reg rst;
    reg we;
    reg [ADDR_WIDTH-1:0] addr;
    reg [DATA_WIDTH-1:0] din;
    wire [DATA_WIDTH-1:0] dout;
    wire refresh_active;

    integer i;
    reg [DATA_WIDTH-1:0] expected_data [0:DEPTH-1];

    // Instantiate DRAM
    dram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .REFRESH_CYCLES(REFRESH_CYCLES)
    ) uut (
        .clk(clk),
        .rst(rst),
        .we(we),
        .addr(addr),
        .din(din),
        .dout(dout),
        .refresh_active(refresh_active)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;
        we = 0;
        addr = 0;
        din = 0;

        // Wait for reset
        #12;
        rst = 0;

        // Write data to all addresses
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            we = 1;
            addr = i[ADDR_WIDTH-1:0];
            din = i * 5 + 7; // Example data pattern
            expected_data[i] = i * 5 + 7;
        end

        // Disable write
        @(negedge clk);
        we = 0;
        din = 0;

        // Wait for a few refresh cycles to ensure data is retained
        repeat (REFRESH_CYCLES*5) @(negedge clk);

        // Read back and check data
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            addr = i[ADDR_WIDTH-1:0];
            #1;
            if (dout !== expected_data[i]) begin
                $display("ERROR: Address %0d, Expected %0h, Got %0h", i, expected_data[i], dout);
            end else begin
                $display("PASS: Address %0d, Data %0h", i, dout);
            end
        end

        // Test data loss if refresh is not performed
        $display("Testing data loss due to lack of refresh...");
        rst = 1;
        repeat (REFRESH_CYCLES*6) @(negedge clk);
        rst = 0;

        // Wait for decay to occur
        repeat (REFRESH_CYCLES*5) @(negedge clk);

        // Read back and check for data loss
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            addr = i[ADDR_WIDTH-1:0];
            #1;
            if (dout !== {DATA_WIDTH{1'b0}}) begin
                $display("ERROR: Address %0d, Expected decay to 0, Got %0h", i, dout);
            end else begin
                $display("PASS: Address %0d, Data decayed to 0 as expected", i);
            end
        end

        $display("DRAM test completed.");
        $finish;
    end

endmodule