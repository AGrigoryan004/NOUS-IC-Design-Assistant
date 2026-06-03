// Simple Cache Memory Module in Verilog
// Direct-mapped, 4 lines, 8-bit data, 4-bit address, write-through, no write-allocate

module simple_cache (
    input clk,
    input rst,
    input read,
    input write,
    input [3:0] addr,       // 4-bit address (16 locations)
    input [7:0] wdata,      // Write data
    output reg [7:0] rdata, // Read data
    output reg hit          // Cache hit indicator
);

    // Cache parameters
    parameter CACHE_LINES = 4; // Number of cache lines
    parameter INDEX_BITS  = 2; // log2(CACHE_LINES)
    parameter TAG_BITS    = 2; // 4 - INDEX_BITS

    // Cache storage
    reg [7:0] data_array [0:CACHE_LINES-1];            // Data storage
    reg [TAG_BITS-1:0] tag_array [0:CACHE_LINES-1];    // Tag storage
    reg valid_array [0:CACHE_LINES-1];                 // Valid bits

    wire [INDEX_BITS-1:0] index;
    wire [TAG_BITS-1:0] tag;

    assign index = addr[INDEX_BITS-1:0]; // Lower bits for index
    assign tag   = addr[3:INDEX_BITS];   // Upper bits for tag

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Invalidate all cache lines on reset
            for (i = 0; i < CACHE_LINES; i = i + 1) begin
                valid_array[i] <= 0;
                tag_array[i]   <= 0;
                data_array[i]  <= 0;
            end
            rdata <= 0;
            hit   <= 0;
        end else begin
            hit <= 0;

            if (read) begin
                // Read operation
                if (valid_array[index] && tag_array[index] == tag) begin
                    // Cache hit
                    rdata <= data_array[index];
                    hit   <= 1;
                end else begin
                    // Cache miss (simulate fetching from memory: return 0)
                    rdata <= 8'h00;
                    hit   <= 0;
                end
            end

            if (write) begin
                // Write operation (write-through, update cache if hit)
                if (valid_array[index] && tag_array[index] == tag) begin
                    // Cache hit: update data
                    data_array[index] <= wdata;
                    hit <= 1;
                end else begin
                    // Cache miss: allocate new line (write-allocate = 0, so do not allocate on miss)
                    hit <= 0;
                end
                // In a real system, write-through would also update main memory here
            end
        end
    end

    // Simulate cache fill on miss (for demonstration, not realistic)
    always @(negedge clk) begin
        if (read && !(valid_array[index] && tag_array[index] == tag)) begin
            // On miss, fill cache line with dummy data (e.g., addr as data)
            data_array[index]  <= addr;
            tag_array[index]   <= tag;
            valid_array[index] <= 1;
        end
    end

endmodule