// Testbench for I2C Master
module tb_i2c_master;

    parameter DATA_WIDTH = 8;
    parameter CLK_FREQ   = 1_000_000;
    parameter I2C_FREQ   = 100_000;

    reg clk;
    reg rst_n;

    reg                  start;
    reg                  rw;
    reg  [6:0]           addr;
    reg  [DATA_WIDTH-1:0] wr_data;
    wire [DATA_WIDTH-1:0] rd_data;
    wire                 busy, done, ack_error;
    wire                 scl;
    wire                 sda;

    // DUT
    i2c_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_FREQ(CLK_FREQ),
        .I2C_FREQ(I2C_FREQ)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .rw(rw),
        .addr(addr),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .busy(busy),
        .done(done),
        .ack_error(ack_error),
        .scl(scl),
        .sda(sda)
    );

    // Simple slave model
    reg sda_slave_oe;
    reg sda_slave_out;
    assign sda = sda_slave_oe ? sda_slave_out : 1'bz;

    reg [7:0] slave_mem;
    integer bit_count;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 MHz
    end

    // Very simple dummy I2C slave behavior
    initial begin
        sda_slave_oe = 0;
        sda_slave_out = 1;
        slave_mem = 8'hA5;
        bit_count = 0;
    end

    // For write ACK
    always @(negedge scl) begin
        if (busy) begin
            if (!rw) begin
                // ACK phase
                if (bit_count == 8) begin
                    sda_slave_oe  <= 1;
                    sda_slave_out <= 0;
                    bit_count <= 0;
                end else begin
                    sda_slave_oe <= 0;
                    bit_count <= bit_count + 1;
                end
            end
        end else begin
            sda_slave_oe <= 0;
            bit_count <= 0;
        end
    end

    // For read data
    always @(posedge scl) begin
        if (busy && rw) begin
            if (bit_count < 8) begin
                sda_slave_oe  <= 1;
                sda_slave_out <= slave_mem[7-bit_count];
                bit_count <= bit_count + 1;
            end else begin
                sda_slave_oe <= 0;
                bit_count <= 0;
            end
        end else if (!busy) begin
            sda_slave_oe <= 0;
            bit_count <= 0;
        end
    end

    initial begin
        rst_n   = 0;
        start   = 0;
        rw      = 0;
        addr    = 7'h42;
        wr_data = 8'h00;

        #100;
        rst_n = 1;
        #100;

        // Write test
        wr_data = 8'h5A;
        rw = 0;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done);
        @(posedge clk);
        if (!ack_error)
            $display("WRITE PASS: Wrote 0x%02h", wr_data);
        else
            $display("WRITE FAIL: NACK received");

        #200;

        // Read test
        rw = 1;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done);
        @(posedge clk);
        $display("READ DONE: rd_data = 0x%02h", rd_data);

        #200;
        $display("I2C Master Testbench completed.");
        $finish;
    end

    initial begin
        $display("Time\tSCL\tSDA\tStart\tRW\tAddr\tWr_Data\tRd_Data\tBusy\tDone\tAckErr");
        forever begin
            @(posedge clk);
            $display("%0t\t%b\t%b\t%b\t%b\t%02h\t%02h\t%02h\t%b\t%b\t%b",
                     $time, scl, sda, start, rw, addr, wr_data, rd_data, busy, done, ack_error);
        end
    end

endmodule