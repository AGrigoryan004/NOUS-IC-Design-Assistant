// Testbench for AXI4-Lite Slave
module axi4lite_slave_tb;

    parameter ADDR_WIDTH = 4;
    parameter DATA_WIDTH = 32;
    parameter DEPTH = 16;

    reg                      ACLK;
    reg                      ARESETN;

    // Write address channel
    reg  [ADDR_WIDTH-1:0]    AWADDR;
    reg                      AWVALID;
    wire                     AWREADY;

    // Write data channel
    reg  [DATA_WIDTH-1:0]    WDATA;
    reg  [(DATA_WIDTH/8)-1:0] WSTRB;
    reg                      WVALID;
    wire                     WREADY;

    // Write response channel
    wire [1:0]               BRESP;
    wire                     BVALID;
    reg                      BREADY;

    // Read address channel
    reg  [ADDR_WIDTH-1:0]    ARADDR;
    reg                      ARVALID;
    wire                     ARREADY;

    // Read data channel
    wire [DATA_WIDTH-1:0]    RDATA;
    wire [1:0]               RRESP;
    wire                     RVALID;
    reg                      RREADY;

    integer i;
    reg [DATA_WIDTH-1:0] expected_mem [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] rdata_tmp;

    // Instantiate DUT
    axi4lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .ACLK(ACLK),
        .ARESETN(ARESETN),
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        .WDATA(WDATA),
        .WSTRB(WSTRB),
        .WVALID(WVALID),
        .WREADY(WREADY),
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        .RDATA(RDATA),
        .RRESP(RRESP),
        .RVALID(RVALID),
        .RREADY(RREADY)
    );

    // Clock generation
    always #5 ACLK = ~ACLK;

    // AXI4-Lite write task
    task axi_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [(DATA_WIDTH/8)-1:0] wstrb;
        begin
            @(posedge ACLK);
            AWADDR  = addr;
            AWVALID = 1;
            WDATA   = data;
            WSTRB   = wstrb;
            WVALID  = 1;

            wait (AWREADY || WREADY);
            @(posedge ACLK);
            AWVALID = 0;
            WVALID  = 0;

            BREADY = 1;
            wait (BVALID);
            @(posedge ACLK);

            if (BRESP !== 2'b00)
                $display("AXI WRITE ERROR: Address %0d, BRESP=%b", addr, BRESP);
            else
                $display("AXI WRITE OK: Address %0d, Data %0h", addr, data);

            BREADY = 0;
        end
    endtask

    // AXI4-Lite read task
    task axi_read;
        input  [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data_out;
        begin
            @(posedge ACLK);
            ARADDR  = addr;
            ARVALID = 1;
            RREADY  = 1;

            wait (ARREADY);
            @(posedge ACLK);
            ARVALID = 0;

            wait (RVALID);
            data_out = RDATA;
            @(posedge ACLK);

            if (RRESP !== 2'b00)
                $display("AXI READ ERROR: Address %0d, RRESP=%b", addr, RRESP);
            else
                $display("AXI READ OK: Address %0d, Data %0h", addr, RDATA);

            RREADY = 0;
        end
    endtask

    initial begin
        // Initialize signals
        ACLK    = 0;
        ARESETN = 0;
        AWADDR  = 0;
        AWVALID = 0;
        WDATA   = 0;
        WSTRB   = {DATA_WIDTH/8{1'b1}};
        WVALID  = 0;
        BREADY  = 0;
        ARADDR  = 0;
        ARVALID = 0;
        RREADY  = 0;

        for (i = 0; i < DEPTH; i = i + 1)
            expected_mem[i] = 0;

        // Reset
        #20;
        ARESETN = 1;
        #20;

        // Write to all addresses
        for (i = 0; i < DEPTH; i = i + 1) begin
            axi_write(i[ADDR_WIDTH-1:0], 32'hA5A50000 + i, {DATA_WIDTH/8{1'b1}});
            expected_mem[i] = 32'hA5A50000 + i;
        end

        // Read and check all addresses
        for (i = 0; i < DEPTH; i = i + 1) begin
            axi_read(i[ADDR_WIDTH-1:0], rdata_tmp);
            if (rdata_tmp !== expected_mem[i])
                $display("ERROR: Address %0d, Expected %0h, Got %0h", i, expected_mem[i], rdata_tmp);
            else
                $display("PASS: Address %0d, Data %0h", i, rdata_tmp);
        end

        // Partial write
        $display("Testing partial write (WSTRB)...");
        axi_write(2, 32'hDEADBEEF, 4'b0011);
        expected_mem[2][15:0]  = 16'hBEEF;
        expected_mem[2][31:16] = 16'hA5A5;

        axi_read(2, rdata_tmp);
        if (rdata_tmp !== expected_mem[2])
            $display("ERROR: Partial write, Expected %0h, Got %0h", expected_mem[2], rdata_tmp);
        else
            $display("PASS: Partial write, Data %0h", rdata_tmp);

        // Out-of-range test
        $display("Testing out-of-range address...");
        axi_write(DEPTH, 32'h12345678, {DATA_WIDTH/8{1'b1}});
        axi_read(DEPTH, rdata_tmp);

        $display("AXI4-Lite test completed.");
        $finish;
    end

endmodule