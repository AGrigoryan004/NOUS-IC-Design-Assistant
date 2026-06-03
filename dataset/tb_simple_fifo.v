// Testbench for simple_fifo
module tb_simple_fifo;

    parameter DATA_WIDTH = 8;
    parameter DEPTH = 8;

    reg clk;
    reg rst;
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0] din;
    wire [DATA_WIDTH-1:0] dout;
    wire full;
    wire empty;

    // Instantiate FIFO
    simple_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .din(din),
        .dout(dout),
        .full(full),
        .empty(empty)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    // Test sequence
    initial begin
        // Initialize
        rst = 1; wr_en = 0; rd_en = 0; din = 0;
        #12;
        rst = 0;

        // 1. Write data into FIFO until full
        $display("---- Writing to FIFO ----");
        repeat (DEPTH) begin
            @(negedge clk);
            wr_en = 1; rd_en = 0; din = $random;
        end
        @(negedge clk);
        wr_en = 1; // Attempt to write when full (overflow)
        din = 8'hAA;
        @(negedge clk);
        wr_en = 0;

        // 2. Read data from FIFO until empty
        $display("---- Reading from FIFO ----");
        repeat (DEPTH) begin
            @(negedge clk);
            wr_en = 0; rd_en = 1;
        end
        @(negedge clk);
        rd_en = 1; // Attempt to read when empty (underflow)
        @(negedge clk);
        rd_en = 0;

        // 3. Simultaneous write and read
        $display("---- Simultaneous Write and Read ----");
        @(negedge clk);
        wr_en = 1; rd_en = 1; din = 8'h55;
        @(negedge clk);
        wr_en = 0; rd_en = 0;

        // End simulation
        #20;
        $finish;
    end

    // Monitor outputs
    initial begin
        $display("Time\twr_en\trd_en\tdin\tdout\tfull\tempty");
        $monitor("%0t\t%b\t%b\t%h\t%h\t%b\t%b", $time, wr_en, rd_en, din, dout, full, empty);
    end

endmodule