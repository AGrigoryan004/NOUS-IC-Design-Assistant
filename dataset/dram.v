// Simple DRAM Module with Refresh
module dram #(
    parameter ADDR_WIDTH = 4,      // Number of address bits
    parameter DATA_WIDTH = 8,      // Number of data bits
    parameter DEPTH = 16,          // Memory depth (number of locations)
    parameter REFRESH_CYCLES = 8   // Number of cycles between refreshes
)(
    input wire clk,                    // Clock
    input wire rst,                    // Reset (active high)
    input wire we,                     // Write enable
    input wire [ADDR_WIDTH-1:0] addr,  // Address
    input wire [DATA_WIDTH-1:0] din,   // Data input
    output reg [DATA_WIDTH-1:0] dout,  // Data output
    output reg refresh_active          // Indicates refresh is occurring
);

    // Memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Refresh counter and row pointer
    reg [$clog2(REFRESH_CYCLES)-1:0] refresh_cnt;
    reg [$clog2(DEPTH)-1:0] refresh_row;

    integer i;

    // Simulate DRAM cell decay
    reg [31:0] last_refresh [0:DEPTH-1];
    reg [31:0] cycle_count;

    // Synchronous logic
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                mem[i] <= {DATA_WIDTH{1'b0}};
                last_refresh[i] <= 0;
            end
            dout <= {DATA_WIDTH{1'b0}};
            refresh_cnt <= 0;
            refresh_row <= 0;
            refresh_active <= 0;
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            // Refresh logic: every REFRESH_CYCLES, refresh one row
            if (refresh_cnt == REFRESH_CYCLES-1) begin
                refresh_cnt <= 0;
                refresh_row <= (refresh_row == DEPTH-1) ? 0 : refresh_row + 1;
                last_refresh[refresh_row] <= cycle_count;
                refresh_active <= 1;
            end else begin
                refresh_cnt <= refresh_cnt + 1;
                refresh_active <= 0;
            end

            // Simulate cell decay
            for (i = 0; i < DEPTH; i = i + 1) begin
                if ((cycle_count - last_refresh[i]) > (REFRESH_CYCLES*4))
                    mem[i] <= {DATA_WIDTH{1'b0}};
            end

            // Synchronous write/read
            if (we) begin
                mem[addr] <= din;
                dout <= din; // Write-through
                last_refresh[addr] <= cycle_count; // Writing refreshes the cell
            end else begin
                dout <= mem[addr];
            end
        end
    end

endmodule