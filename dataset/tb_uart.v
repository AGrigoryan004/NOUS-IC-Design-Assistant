// Testbench for UART
module tb_uart;

    parameter DATA_WIDTH = 8;
    parameter CLK_FREQ   = 10_000_000; // 10 MHz for simulation speed
    parameter BAUD_RATE  = 115200;

    reg clk;
    reg rst_n;

    // UART signals
    reg  [DATA_WIDTH-1:0] tx_data;
    reg                   tx_en;
    wire                  tx_ready;
    wire                  txd;
    reg                   rxd;
    wire [DATA_WIDTH-1:0] rx_data;
    wire                  rx_ready;
    wire                  rx_busy;

    // Instantiate UART
    uart #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .tx_en(tx_en),
        .tx_ready(tx_ready),
        .txd(txd),
        .rxd(rxd),
        .rx_data(rx_data),
        .rx_ready(rx_ready),
        .rx_busy(rx_busy)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #50 clk = ~clk; // 10 MHz clock (period = 100ns)
    end

    // UART RX line is looped back from TX for self-test
    always @(posedge clk)
        rxd <= txd;

    // Test sequence
    initial begin
        rst_n   = 0;
        tx_en   = 0;
        tx_data = 0;
        rxd     = 1;
        #200;
        rst_n = 1;

        // Wait for UART to be ready
        @(posedge clk);
        repeat (10) @(posedge clk);

        // Transmit bytes
        send_byte(8'h55);
        wait_rx();

        send_byte(8'hA5);
        wait_rx();

        send_byte(8'hFF);
        wait_rx();

        send_byte(8'h00);
        wait_rx();

        // Wait and finish
        #10000;
        $finish;
    end

    // Task to send a byte
    task send_byte(input [DATA_WIDTH-1:0] data);
    begin
        @(posedge clk);
        while (!tx_ready) @(posedge clk);
        tx_data = data;
        tx_en   = 1;
        @(posedge clk);
        tx_en   = 0;
        $display("Time %0t: Sent byte 0x%02h", $time, data);
    end
    endtask

    // Task to wait for received byte
    task wait_rx;
    begin
        wait (rx_ready == 1);
        $display("Time %0t: Received byte 0x%02h", $time, rx_data);
        @(posedge clk);
    end
    endtask

    // Monitor UART signals
    initial begin
        $display("Time\tTXD\tRXD\tTX_Ready\tRX_Ready\tTX_Data\tRX_Data");
        forever begin
            @(posedge clk);
            $display("%0t\t%b\t%b\t%b\t\t%b\t\t%02h\t%02h",
                     $time, txd, rxd, tx_ready, rx_ready, tx_data, rx_data);
        end
    end

endmodule