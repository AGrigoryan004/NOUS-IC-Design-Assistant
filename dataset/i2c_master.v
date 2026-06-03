// I2C Master Module with Parameterized Data Width and Clock Frequency
module i2c_master #(
    parameter DATA_WIDTH = 8,
    parameter CLK_FREQ   = 50_000_000,
    parameter I2C_FREQ   = 100_000
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Control interface
    input  wire                  start,
    input  wire                  rw,        // 0: Write, 1: Read
    input  wire [6:0]            addr,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output reg                   busy,
    output reg                   done,
    output reg                   ack_error,

    // I2C signals
    output reg                   scl,
    inout  wire                  sda
);

    localparam integer DIVIDER = CLK_FREQ / (I2C_FREQ * 4);

    localparam [3:0]
        IDLE      = 4'd0,
        START_ST  = 4'd1,
        ADDR_ST   = 4'd2,
        ADDR_ACK  = 4'd3,
        WRITE_ST  = 4'd4,
        WRITE_ACK = 4'd5,
        READ_ST   = 4'd6,
        READ_ACK  = 4'd7,
        STOP_ST   = 4'd8,
        DONE_ST   = 4'd9;

    reg [3:0] state;
    reg [$clog2(DIVIDER):0] clk_cnt;
    reg tick;

    reg [3:0] bit_cnt;
    reg [7:0] addr_byte;
    reg [DATA_WIDTH-1:0] shift_reg;

    reg sda_out;
    reg sda_oe;

    assign sda = sda_oe ? sda_out : 1'bz;
    wire sda_in = sda;

    // Clock divider for slow I2C timing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            tick <= 0;
        end else if (busy) begin
            if (clk_cnt == DIVIDER - 1) begin
                clk_cnt <= 0;
                tick <= 1;
            end else begin
                clk_cnt <= clk_cnt + 1;
                tick <= 0;
            end
        end else begin
            clk_cnt <= 0;
            tick <= 0;
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            scl <= 1'b1;
            sda_out <= 1'b1;
            sda_oe <= 1'b1;
            rd_data <= 0;
            busy <= 0;
            done <= 0;
            ack_error <= 0;
            bit_cnt <= 0;
            addr_byte <= 0;
            shift_reg <= 0;
        end else begin
            done <= 0;

            if (tick) begin
                case (state)
                    IDLE: begin
                        scl <= 1'b1;
                        sda_out <= 1'b1;
                        sda_oe <= 1'b1;
                        busy <= 0;
                        ack_error <= 0;
                        bit_cnt <= 0;
                        if (start) begin
                            busy <= 1;
                            addr_byte <= {addr, rw};
                            shift_reg <= wr_data;
                            state <= START_ST;
                        end
                    end

                    START_ST: begin
                        // START: SDA goes low while SCL high
                        scl <= 1'b1;
                        sda_out <= 1'b0;
                        sda_oe <= 1'b1;
                        bit_cnt <= 0;
                        state <= ADDR_ST;
                    end

                    ADDR_ST: begin
                        // Put address bit, pulse clock
                        scl <= 1'b0;
                        sda_out <= addr_byte[7];
                        sda_oe <= 1'b1;
                        addr_byte <= {addr_byte[6:0], 1'b0};
                        state <= ADDR_ACK;
                    end

                    ADDR_ACK: begin
                        scl <= 1'b1;
                        if (bit_cnt < 7) begin
                            bit_cnt <= bit_cnt + 1;
                            state <= ADDR_ST;
                        end else begin
                            bit_cnt <= 0;
                            scl <= 1'b0;
                            sda_oe <= 1'b0; // release SDA for ACK
                            state <= rw ? READ_ST : WRITE_ST;
                        end
                    end

                    WRITE_ST: begin
                        scl <= 1'b0;
                        sda_out <= shift_reg[DATA_WIDTH-1];
                        sda_oe <= 1'b1;
                        shift_reg <= {shift_reg[DATA_WIDTH-2:0], 1'b0};
                        state <= WRITE_ACK;
                    end

                    WRITE_ACK: begin
                        scl <= 1'b1;
                        if (bit_cnt < DATA_WIDTH-1) begin
                            bit_cnt <= bit_cnt + 1;
                            state <= WRITE_ST;
                        end else begin
                            bit_cnt <= 0;
                            scl <= 1'b0;
                            sda_oe <= 1'b0; // release for ACK
                            if (sda_in)
                                ack_error <= 1'b1;
                            state <= STOP_ST;
                        end
                    end

                    READ_ST: begin
                        scl <= 1'b1;
                        sda_oe <= 1'b0;
                        shift_reg <= {shift_reg[DATA_WIDTH-2:0], sda_in};
                        if (bit_cnt < DATA_WIDTH-1) begin
                            bit_cnt <= bit_cnt + 1;
                            state <= READ_ACK;
                        end else begin
                            bit_cnt <= 0;
                            rd_data <= {shift_reg[DATA_WIDTH-2:0], sda_in};
                            state <= READ_ACK;
                        end
                    end

                    READ_ACK: begin
                        scl <= 1'b0;
                        if (bit_cnt == 0 && rw) begin
                            sda_oe <= 1'b1;
                            sda_out <= 1'b1; // NACK after single-byte read
                            state <= STOP_ST;
                        end else begin
                            state <= READ_ST;
                        end
                    end

                    STOP_ST: begin
                        scl <= 1'b1;
                        sda_oe <= 1'b1;
                        sda_out <= 1'b1;
                        state <= DONE_ST;
                    end

                    DONE_ST: begin
                        busy <= 0;
                        done <= 1;
                        state <= IDLE;
                    end

                    default: begin
                        state <= IDLE;
                    end
                endcase
            end
        end
    end

endmodule