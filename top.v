// ============================================================
// top.v
// Wires together 3 independent "IoT device" data sources,
// each with its own FIFO buffer, into a single round-robin
// arbiter, a simple processor, and a UART output -
// a small-scale demonstration of concurrent multi-channel
// I/O handling: multiple sources, serviced fairly, with
// nothing dropped and no single channel starved.
// ============================================================

module top (
    input wire clk,
    input wire rst,

    // exposed as real output ports so synthesis has something
    // externally observable to preserve (without these, a
    // synthesis tool correctly optimizes the whole design away
    // as having no effect on the outside world)
    output wire tx_line_out,
    output wire tx_busy_out,
    output wire [1:0] arb_channel_out,
    output wire arb_valid_out
);

    // ---- 3 independent simulated IoT devices ----
    wire [7:0] data0, data1, data2;
    wire       valid0, valid1, valid2;

    data_gen #(.SEED(8'hA5)) u_gen0 (.clk(clk), .rst(rst), .data(data0), .valid(valid0));
    data_gen #(.SEED(8'h5C)) u_gen1 (.clk(clk), .rst(rst), .data(data1), .valid(valid1));
    data_gen #(.SEED(8'h3E)) u_gen2 (.clk(clk), .rst(rst), .data(data2), .valid(valid2));

    // ---- one FIFO buffer per channel ----
    wire full0, full1, full2;
    wire empty0, empty1, empty2;
    wire rd_en0, rd_en1, rd_en2;
    wire [7:0] fifo_dout0, fifo_dout1, fifo_dout2;

    channel_fifo u_fifo0 (.clk(clk), .rst(rst), .wr_en(valid0), .wr_data(data0),
                           .full(full0), .rd_en(rd_en0), .rd_data(fifo_dout0), .empty(empty0));
    channel_fifo u_fifo1 (.clk(clk), .rst(rst), .wr_en(valid1), .wr_data(data1),
                           .full(full1), .rd_en(rd_en1), .rd_data(fifo_dout1), .empty(empty1));
    channel_fifo u_fifo2 (.clk(clk), .rst(rst), .wr_en(valid2), .wr_data(data2),
                           .full(full2), .rd_en(rd_en2), .rd_data(fifo_dout2), .empty(empty2));

    // ---- round-robin arbiter: the concurrency core ----
    wire [7:0] arb_data;
    wire [1:0] arb_channel;
    wire       arb_valid;

    rr_arbiter u_arb (
        .clk(clk), .rst(rst),
        .empty0(empty0), .empty1(empty1), .empty2(empty2),
        .rd_en0(rd_en0), .rd_en1(rd_en1), .rd_en2(rd_en2),
        .data0(fifo_dout0), .data1(fifo_dout1), .data2(fifo_dout2),
        .out_data(arb_data), .out_channel(arb_channel), .out_valid(arb_valid)
    );

    // ---- simple tagging/processing stage ----
    wire [9:0] pkt;
    wire       pkt_valid;

    processor u_proc (
        .clk(clk), .rst(rst),
        .in_valid(arb_valid), .in_channel(arb_channel), .in_data(arb_data),
        .out_valid(pkt_valid), .out_packet(pkt)
    );

    // ---- UART output to the "host" ----
    // NOTE (documented simplification): only the 8-bit data
    // byte (pkt[7:0]) is sent over UART in this first version;
    // the channel id (pkt[9:8]) is visible in the simulation
    // waveform/monitor instead of being transmitted as a
    // separate byte. A v2 could add a 2-byte frame
    // (channel byte + data byte) if you want to extend it.
    wire tx_line;
    wire tx_busy;

    uart_tx #(.CLKS_PER_BIT(434)) u_uart (
        .clk(clk), .rst(rst),
        .tx_start(pkt_valid), .tx_data(pkt[7:0]),
        .tx_line(tx_line), .busy(tx_busy)
    );

    // drive the top-level output ports so synthesis keeps the
    // logic that produces them
    assign tx_line_out     = tx_line;
    assign tx_busy_out     = tx_busy;
    assign arb_channel_out = arb_channel;
    assign arb_valid_out   = arb_valid;

endmodule
