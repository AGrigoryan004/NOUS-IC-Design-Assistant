// Parameterized ROM Module with Synchronous Read and Initial Content
module rom #(
    parameter ADDR_WIDTH = 4,      // Number of address bits
    parameter DATA_WIDTH = 8,      // Number of data bits
    parameter DEPTH = 16           // Memory depth (number of locations)
)(
    input  wire                   clk,    // Clock
    input  wire [ADDR_WIDTH-1:0]  addr,   // Address input
    output reg  [DATA_WIDTH-1:0]  dout    // Data output
);

    // ROM memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    integer i;

    // Initialize ROM content
    initial begin
        // Example: Fill ROM with a pattern (address * 3 + 2)
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = i * 3 + 2;
        end
    end

    // Synchronous read
    always @(posedge clk) begin
        dout <= mem[addr];
    end

endmodule