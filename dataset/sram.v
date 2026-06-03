// Simple SRAM Module
module sram #(
    parameter ADDR_WIDTH = 4,      // Number of address bits
    parameter DATA_WIDTH = 8,      // Number of data bits
    parameter DEPTH = 16           // Memory depth (number of locations)
)(
    input wire clk,                    // Clock
    input wire rst,                    // Reset (active high)
    input wire we,                     // Write enable
    input wire [ADDR_WIDTH-1:0] addr,  // Address
    input wire [DATA_WIDTH-1:0] din,   // Data input
    output reg [DATA_WIDTH-1:0] dout   // Data output
);

    // Memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    integer i;

    // Memory initialization on reset
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= {DATA_WIDTH{1'b0}};
            dout <= {DATA_WIDTH{1'b0}};
        end else begin
            if (we) begin
                mem[addr] <= din;      // Write operation
                dout <= din;           // Output written data (write-through)
            end else begin
                dout <= mem[addr];     // Read operation
            end
        end
    end

endmodule