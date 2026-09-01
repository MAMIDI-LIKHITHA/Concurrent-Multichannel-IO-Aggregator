// ============================================================
// processor.v
// Deliberately simple. Takes whatever the arbiter just
// selected and packages it: {channel_id[1:0], data[7:0]}.
// Kept minimal on purpose - the arbiter is the part of this
// project that proves the concurrency concept, not this stage.
// ============================================================

module processor (
    input  wire       clk,
    input  wire       rst,

    input  wire        in_valid,
    input  wire [1:0]  in_channel,
    input  wire [7:0]  in_data,

    output reg         out_valid,
    output reg  [9:0]  out_packet   // {channel[1:0], data[7:0]}
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_valid  <= 1'b0;
            out_packet <= 10'd0;
        end else begin
            out_valid <= in_valid;
            if (in_valid)
                out_packet <= {in_channel, in_data};
        end
    end

endmodule
