// ============================================================
// data_gen.v
// Simulates one "IoT device" sending data at pseudo-random,
// independent intervals. Three instances of this run in
// parallel in top.v, none of them aware of each other -
// exactly like real independent IoT devices.
// ============================================================

module data_gen #(
    parameter [7:0] SEED = 8'hA5   // different seed per instance -> different timing/data
)(
    input  wire       clk,
    input  wire       rst,
    output reg  [7:0] data,        // the "sensor reading" this device produces
    output reg        valid        // pulses high for 1 cycle when data is ready
);

    reg [7:0]  lfsr;          // simple linear-feedback shift register for pseudo-randomness
    reg [15:0] delay_cnt;
    reg [15:0] delay_target;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lfsr          <= SEED;
            delay_cnt     <= 16'd0;
            delay_target  <= {8'h00, SEED} + 16'd50; // first event delay
            valid         <= 1'b0;
            data          <= 8'd0;
        end else begin
            valid <= 1'b0; // default: no new data this cycle

            if (delay_cnt >= delay_target) begin
                // time to "fire" - device has new data ready
                data          <= lfsr;
                valid         <= 1'b1;
                delay_cnt     <= 16'd0;
                // pick a new pseudo-random wait time using current lfsr value
                delay_target  <= {8'h00, lfsr} + 16'd20;
                // advance the LFSR (simple XOR feedback taps)
                lfsr          <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
            end else begin
                delay_cnt <= delay_cnt + 16'd1;
            end
        end
    end

endmodule
