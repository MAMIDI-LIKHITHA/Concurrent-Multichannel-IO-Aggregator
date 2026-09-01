// ============================================================
// channel_fifo.v
// Small synchronous FIFO (depth 4, width 8) sitting between
// each data_gen and the arbiter. Holds data safely if the
// arbiter is busy servicing another channel when this
// channel's data arrives - this is what prevents data loss
// under concurrent load.
// ============================================================

module channel_fifo #(
    parameter AW = 2                 // address width -> depth = 2^AW = 4
)(
    input  wire       clk,
    input  wire       rst,

    input  wire        wr_en,
    input  wire [7:0]  wr_data,
    output wire         full,

    input  wire        rd_en,
    output reg  [7:0]  rd_data,
    output wire         empty
);

    reg [7:0] mem [0:(1<<AW)-1];
    reg [AW:0] wr_ptr, rd_ptr;   // one extra bit lets us tell full vs empty apart

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[AW] != rd_ptr[AW]) &&
                   (wr_ptr[AW-1:0] == rd_ptr[AW-1:0]);

    // write side
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= {(AW+1){1'b0}};
        end else if (wr_en && !full) begin
            mem[wr_ptr[AW-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // read side
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rd_ptr  <= {(AW+1){1'b0}};
            rd_data <= 8'd0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr[AW-1:0]];
            rd_ptr  <= rd_ptr + 1'b1;
        end
    end

endmodule
