// UART Module with Parameterized Baud Rate, Data Width, and Clock Frequency
module uart #(
    parameter DATA_WIDTH = 8,           // Number of data bits
    parameter CLK_FREQ   = 50_000_000,  // System clock frequency in Hz
    parameter BAUD_RATE  = 115200       // Baud rate
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Transmit interface
    input  wire [DATA_WIDTH-1:0] tx_data,
    input  wire                  tx_en,
    output wire                  tx_ready,
    output wire                  txd,

    // Receive interface
    input  wire                  rxd,
    output reg  [DATA_WIDTH-1:0] rx_data,
    output reg                   rx_ready,
    output wire                  rx_busy
);

    // Baud rate generator
    localparam integer BAUD_DIV = CLK_FREQ / BAUD_RATE;

    reg [$clog2(BAUD_DIV)-1:0] baud_cnt;
    reg baud_tick;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt  <= 0;
            baud_tick <= 0;
        end else if (baud_cnt == BAUD_DIV/2) begin
            baud_cnt  <= 0;
            baud_tick <= 1;
        end else begin
            baud_cnt  <= baud_cnt + 1;
            baud_tick <= 0;
        end
    end

    // -------------------------
    // Transmitter
    // -------------------------
    reg [DATA_WIDTH-1:0] tx_shift;
    reg [3:0] tx_bit_cnt;
    reg tx_busy;
    reg txd_reg;
    reg tx_start;

    assign tx_ready = ~tx_busy;
    assign txd = txd_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_busy    <= 0;
            tx_shift   <= 0;
            tx_bit_cnt <= 0;
            txd_reg    <= 1'b1; // Idle state is high
            tx_start   <= 0;
        end else begin
            tx_start <= 0;

            if (tx_en && ~tx_busy) begin
                tx_busy    <= 1;
                tx_shift   <= tx_data;
                tx_bit_cnt <= 0;
                txd_reg    <= 1'b0; // Start bit
                tx_start   <= 1;
            end else if (tx_busy && baud_tick) begin
                if (tx_bit_cnt < DATA_WIDTH) begin
                    txd_reg    <= tx_shift[0];
                    tx_shift   <= {1'b0, tx_shift[DATA_WIDTH-1:1]};
                    tx_bit_cnt <= tx_bit_cnt + 1;
                end else if (tx_bit_cnt == DATA_WIDTH) begin
                    txd_reg    <= 1'b1; // Stop bit
                    tx_bit_cnt <= tx_bit_cnt + 1;
                end else begin
                    tx_busy <= 0;
                    txd_reg <= 1'b1;
                end
            end
        end
    end

    // -------------------------
    // Receiver
    // -------------------------
    reg [DATA_WIDTH-1:0] rx_shift;
    reg [3:0] rx_bit_cnt;
    reg [1:0] rxd_sync;
    reg rx_sample;
    reg rx_busy_reg;
    reg [15:0] rx_baud_cnt;

    assign rx_busy = rx_busy_reg;

    // Synchronize RXD to clk
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rxd_sync <= 2'b11;
        else
            rxd_sync <= {rxd_sync[0], rxd};
    end

    // Receiver state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_busy_reg <= 0;
            rx_bit_cnt  <= 0;
            rx_shift    <= 0;
            rx_baud_cnt <= 0;
            rx_ready    <= 0;
            rx_data     <= 0;
            rx_sample   <= 0;
        end else begin
            rx_ready  <= 0;
            rx_sample <= 0;

            if (!rx_busy_reg) begin
                // Wait for start bit (falling edge)
                if (rxd_sync == 2'b10) begin
                    rx_busy_reg <= 1;
                    rx_baud_cnt <= BAUD_DIV + (BAUD_DIV/2); // sample in middle
                    rx_bit_cnt  <= 0;
                end
            end else begin
                if (rx_baud_cnt == 0) begin
                    rx_baud_cnt <= BAUD_DIV - 1;

                    if (rx_bit_cnt == 0) begin
                        // Start bit, ignore
                        rx_bit_cnt <= rx_bit_cnt + 1;
                    end else if (rx_bit_cnt <= DATA_WIDTH) begin
                        rx_shift   <= {rxd_sync[1], rx_shift[DATA_WIDTH-1:1]};
                        rx_bit_cnt <= rx_bit_cnt + 1;
                    end else if (rx_bit_cnt == DATA_WIDTH + 1) begin
                        // Stop bit
                        rx_data     <= rx_shift;
                        rx_ready    <= 1;
                        rx_busy_reg <= 0;
                    end
                end else begin
                    rx_baud_cnt <= rx_baud_cnt - 1;
                end
            end
        end
    end

endmodule