// Simple AXI4-Lite Slave Module with Parameterized Address/Data Widths
module axi4lite_slave #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 16
)(
    input  wire                      ACLK,
    input  wire                      ARESETN,

    // Write address channel
    input  wire [ADDR_WIDTH-1:0]     AWADDR,
    input  wire                      AWVALID,
    output reg                       AWREADY,

    // Write data channel
    input  wire [DATA_WIDTH-1:0]     WDATA,
    input  wire [(DATA_WIDTH/8)-1:0] WSTRB,
    input  wire                      WVALID,
    output reg                       WREADY,

    // Write response channel
    output reg [1:0]                 BRESP,
    output reg                       BVALID,
    input  wire                      BREADY,

    // Read address channel
    input  wire [ADDR_WIDTH-1:0]     ARADDR,
    input  wire                      ARVALID,
    output reg                       ARREADY,

    // Read data channel
    output reg [DATA_WIDTH-1:0]      RDATA,
    output reg [1:0]                 RRESP,
    output reg                       RVALID,
    input  wire                      RREADY
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    integer i;

    localparam OKAY   = 2'b00;
    localparam SLVERR = 2'b10;

    reg [ADDR_WIDTH-1:0] awaddr_reg;
    reg                  awaddr_valid;

    reg [ADDR_WIDTH-1:0] araddr_reg;
    reg                  araddr_valid;

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            AWREADY      <= 0;
            WREADY       <= 0;
            BRESP        <= OKAY;
            BVALID       <= 0;
            ARREADY      <= 0;
            RDATA        <= 0;
            RRESP        <= OKAY;
            RVALID       <= 0;
            awaddr_reg   <= 0;
            awaddr_valid <= 0;
            araddr_reg   <= 0;
            araddr_valid <= 0;

            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= 0;
        end else begin
            // Default pulse-style ready
            AWREADY <= 0;
            WREADY  <= 0;
            ARREADY <= 0;

            // Capture write address
            if (!awaddr_valid && AWVALID) begin
                AWREADY      <= 1;
                awaddr_reg   <= AWADDR;
                awaddr_valid <= 1;
            end

            // Capture write data
            if (awaddr_valid && WVALID && !BVALID) begin
                WREADY <= 1;

                if (awaddr_reg < DEPTH) begin
                    for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
                        if (WSTRB[i])
                            mem[awaddr_reg][8*i +: 8] <= WDATA[8*i +: 8];
                    end
                    BRESP <= OKAY;
                end else begin
                    BRESP <= SLVERR;
                end

                BVALID       <= 1;
                awaddr_valid <= 0;
            end else if (BVALID && BREADY) begin
                BVALID <= 0;
            end

            // Capture read address
            if (!araddr_valid && ARVALID && !RVALID) begin
                ARREADY      <= 1;
                araddr_reg   <= ARADDR;
                araddr_valid <= 1;
            end

            // Drive read data
            if (araddr_valid) begin
                if (araddr_reg < DEPTH) begin
                    RDATA <= mem[araddr_reg];
                    RRESP <= OKAY;
                end else begin
                    RDATA <= 0;
                    RRESP <= SLVERR;
                end
                RVALID       <= 1;
                araddr_valid <= 0;
            end else if (RVALID && RREADY) begin
                RVALID <= 0;
            end
        end
    end

endmodule