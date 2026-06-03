// Simple Parameterizable FIFO Memory Module in Verilog
// Features: Synchronous read/write, parameterizable width/depth, full/empty flags

module simple_fifo #(
    parameter DATA_WIDTH = 8,   // Width of data bus
    parameter DEPTH = 8         // Number of FIFO entries (must be power of 2)
)(
    input clk,
    input rst,
    input wr_en,                 // Write enable
    input rd_en,                 // Read enable
    input [DATA_WIDTH-1:0] din,  // Data input
    output reg [DATA_WIDTH-1:0] dout, // Data output
    output reg full,             // FIFO full flag
    output reg empty             // FIFO empty flag
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1]; // FIFO storage
    reg [ADDR_WIDTH:0] wr_ptr;            // Write pointer (one bit wider for full detection)
    reg [ADDR_WIDTH:0] rd_ptr;            // Read pointer (one bit wider for full detection)

    // Write operation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= din;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // Read operation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dout <= 0;
            rd_ptr <= 0;
        end else if (rd_en && !empty) begin
            dout <= mem[rd_ptr[ADDR_WIDTH-1:0]];
            rd_ptr <= rd_ptr + 1;
        end
    end

    // Full and empty flag logic
    always @(*) begin
        full  = ((wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                 (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]));
        empty = (wr_ptr == rd_ptr);
    end

endmodule