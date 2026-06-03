// Parameterized SPI Master Module
module spi_master #(
    parameter DATA_WIDTH = 8,   // Number of bits per transfer
    parameter CPOL = 0,         // Clock polarity
    parameter CPHA = 0          // Clock phase
)(
    input  wire                  clk,       // System clock
    input  wire                  rst_n,     // Active-low reset
    input  wire [DATA_WIDTH-1:0] mosi_data, // Data to transmit
    input  wire                  start,     // Start transaction
    output reg  [DATA_WIDTH-1:0] miso_data, // Data received
    output reg                   busy,      // Transaction in progress
    output reg                   done,      // Transaction done (1 clk pulse)

    // SPI signals
    output reg                   sclk,
    output reg                   mosi,
    input  wire                  miso,
    output reg                   cs_n       // Active-low chip select
);

    localparam IDLE  = 2'b00;
    localparam LOAD  = 2'b01;
    localparam TRANS = 2'b10;
    localparam DONE  = 2'b11;

    reg [1:0] state, next_state;
    reg [DATA_WIDTH-1:0] shift_reg;
    reg [DATA_WIDTH-1:0] recv_reg;
    reg [$clog2(DATA_WIDTH+1)-1:0] bit_cnt;

    // simple clock divider for SPI clock
    reg [1:0] clkdiv;
    wire sclk_edge;

    assign sclk_edge = (clkdiv == 2'b11);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clkdiv <= 2'b00;
        else if (state == TRANS)
            clkdiv <= clkdiv + 1'b1;
        else
            clkdiv <= 2'b00;
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:  if (start) next_state = LOAD;
            LOAD:  next_state = TRANS;
            TRANS: if ((bit_cnt == DATA_WIDTH) && sclk_edge) next_state = DONE;
            DONE:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Main control outputs
    always @(*) begin
        busy = (state == LOAD) || (state == TRANS);
        done = (state == DONE);
        cs_n = (state == IDLE || state == DONE) ? 1'b1 : 1'b0;
    end

    // SPI clock generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sclk <= CPOL;
        else if (state == TRANS && sclk_edge)
            sclk <= ~sclk;
        else if (state != TRANS)
            sclk <= CPOL;
    end

    // Bit counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_cnt <= 0;
        else if (state == LOAD)
            bit_cnt <= 0;
        else if (state == TRANS && sclk_edge)
            bit_cnt <= bit_cnt + 1'b1;
    end

    // Load transmit data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift_reg <= 0;
        else if (state == LOAD)
            shift_reg <= mosi_data;
        else if (state == TRANS && sclk_edge) begin
            if (bit_cnt < DATA_WIDTH)
                shift_reg <= {shift_reg[DATA_WIDTH-2:0], 1'b0};
        end
    end

    // MOSI output
    always @(*) begin
        if (state == TRANS)
            mosi = shift_reg[DATA_WIDTH-1];
        else
            mosi = 1'b0;
    end

    // Receive data from MISO
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            recv_reg <= 0;
        else if (state == LOAD)
            recv_reg <= 0;
        else if (state == TRANS && sclk_edge) begin
            if (bit_cnt < DATA_WIDTH)
                recv_reg <= {recv_reg[DATA_WIDTH-2:0], miso};
        end
    end

    // Latch received data at end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            miso_data <= 0;
        else if (state == DONE)
            miso_data <= recv_reg;
    end

endmodule