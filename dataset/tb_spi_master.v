// Testbench for SPI Master
module tb_spi_master;

    parameter DATA_WIDTH = 8;
    parameter CPOL = 0;
    parameter CPHA = 0;

    reg clk;
    reg rst_n;
    reg [DATA_WIDTH-1:0] mosi_data;
    reg start;
    wire [DATA_WIDTH-1:0] miso_data;
    wire busy, done;
    wire sclk, mosi, cs_n;
    wire miso;

    // Simple SPI slave model
    reg [DATA_WIDTH-1:0] slave_shift;
    reg [DATA_WIDTH-1:0] slave_data;
    reg miso_reg;

    assign miso = miso_reg;

    // Instantiate SPI master
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CPOL(CPOL),
        .CPHA(CPHA)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .mosi_data(mosi_data),
        .start(start),
        .miso_data(miso_data),
        .busy(busy),
        .done(done),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz
    end

    // Simple slave behavior:
    // shifts out slave_data MSB-first while transaction is active
    always @(negedge sclk or posedge cs_n or negedge rst_n) begin
        if (!rst_n) begin
            slave_shift <= 8'hA5;
            slave_data  <= 8'hA5;
            miso_reg    <= 1'b0;
        end else if (cs_n) begin
            slave_shift <= slave_data;
            miso_reg    <= slave_data[DATA_WIDTH-1];
        end else begin
            miso_reg    <= slave_shift[DATA_WIDTH-1];
            slave_shift <= {slave_shift[DATA_WIDTH-2:0], 1'b0};
        end
    end

    // Update next slave response after each transaction
    always @(posedge cs_n or negedge rst_n) begin
        if (!rst_n)
            slave_data <= 8'hA5;
        else if (!busy)
            slave_data <= slave_data + 8'h11;
    end

    // Test sequence
    reg [DATA_WIDTH-1:0] test_vectors [0:3];
    reg [DATA_WIDTH-1:0] expected_slave_data [0:3];
    integer i;

    initial begin
        test_vectors[0] = 8'h55;
        test_vectors[1] = 8'hAA;
        test_vectors[2] = 8'hFF;
        test_vectors[3] = 8'h00;

        expected_slave_data[0] = 8'hA5;
        expected_slave_data[1] = 8'hB6;
        expected_slave_data[2] = 8'hC7;
        expected_slave_data[3] = 8'hD8;

        rst_n = 0;
        start = 0;
        mosi_data = 0;

        #100;
        rst_n = 1;
        #100;

        for (i = 0; i < 4; i = i + 1) begin
            mosi_data = test_vectors[i];

            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;

            wait(done);
            @(posedge clk);

            $display("Time %0t: Sent MOSI=0x%02h, Received MISO=0x%02h, Expected MISO=0x%02h",
                     $time, mosi_data, miso_data, expected_slave_data[i]);

            if (miso_data !== expected_slave_data[i])
                $display("ERROR: MISO mismatch! Got 0x%02h, expected 0x%02h",
                         miso_data, expected_slave_data[i]);
            else
                $display("PASS: MISO data matches expected value.");

            #100;
        end

        $display("SPI Master Testbench completed.");
        #200;
        $finish;
    end

    // Monitor signals
    initial begin
        $display("Time\tCS_N\tSCLK\tMOSI\tMISO\tMOSI_Data\tMISO_Data\tBusy\tDone");
        forever begin
            @(posedge clk);
            $display("%0t\t%b\t%b\t%b\t%b\t%02h\t\t%02h\t\t%b\t%b",
                     $time, cs_n, sclk, mosi, miso, mosi_data, miso_data, busy, done);
        end
    end

endmodule