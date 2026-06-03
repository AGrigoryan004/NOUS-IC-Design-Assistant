// Testbench for SRAM
module sram_tb;

    // Parameters
    parameter ADDR_WIDTH = 4;
    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;

    // Signals
    reg clk;
    reg rst;
    reg we;
    reg [ADDR_WIDTH-1:0] addr;
    reg [DATA_WIDTH-1:0] din;
    wire [DATA_WIDTH-1:0] dout;

    integer i;
    reg [DATA_WIDTH-1:0] expected_data [0:DEPTH-1];

    // Instantiate SRAM
    sram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .we(we),
        .addr(addr),
        .din(din),
        .dout(dout)
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

        // Write data to several addresses
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            we = 1;
            addr = i[ADDR_WIDTH-1:0];
            din = i * 3; // Example data pattern
            expected_data[i] = i * 3;
        end

        // Disable write
        @(negedge clk);
        we = 0;
        din = 0;

        // Read back and check data
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            addr = i[ADDR_WIDTH-1:0];
            #1; // Small delay for output to settle
            if (dout !== expected_data[i]) begin
                $display("ERROR: Address %0d, Expected %0h, Got %0h", i, expected_data[i], dout);
            end else begin
                $display("PASS: Address %0d, Data %0h", i, dout);
            end
        end

        // Finish simulation
        $display("SRAM test completed.");
        $finish;
    end

endmodule