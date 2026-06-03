// Testbench for ROM
module rom_tb;

    // Parameters
    parameter ADDR_WIDTH = 4;
    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;

    // Signals
    reg clk;
    reg [ADDR_WIDTH-1:0] addr;
    wire [DATA_WIDTH-1:0] dout;

    integer i;
    reg [DATA_WIDTH-1:0] expected_data [0:DEPTH-1];

    // Instantiate ROM
    rom #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .addr(addr),
        .dout(dout)
    );

    // Clock generation: 10ns period
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        addr = 0;

        // Prepare expected data
        for (i = 0; i < DEPTH; i = i + 1) begin
            expected_data[i] = i * 3 + 2;
        end

        #10;

        // Test all addresses
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            addr = i[ADDR_WIDTH-1:0];
            @(negedge clk);
            #1;
            if (dout !== expected_data[i]) begin
                $display("ERROR: Address %0d, Expected %0h, Got %0h", i, expected_data[i], dout);
            end else begin
                $display("PASS: Address %0d, Data %0h", i, dout);
            end
        end

        $display("ROM test completed.");
        $finish;
    end

endmodule