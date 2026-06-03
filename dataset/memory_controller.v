// Basic Memory Controller Module
module memory_controller #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter MEM_DEPTH  = 16
)(
    input wire clk,
    input wire rst_n,
    input wire read_en,
    input wire write_en,
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] write_data,
    output reg [DATA_WIDTH-1:0] read_data,
    output reg ready
);

    // Internal memory array
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Ready signal logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ready <= 1'b0;
        else if (read_en || write_en)
            ready <= 1'b1;
        else
            ready <= 1'b0;
    end

    // Read and Write Operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_data <= {DATA_WIDTH{1'b0}};
        end else begin
            if (write_en) begin
                mem[addr] <= write_data; // Write operation
            end
            if (read_en) begin
                read_data <= mem[addr];  // Read operation
            end
        end
    end

endmodule