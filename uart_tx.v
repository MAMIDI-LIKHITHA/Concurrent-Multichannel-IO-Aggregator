// ============================================================
// uart_tx.v
// Simple 8N1 UART transmitter. Represents the "host interface"
// side of the design - the arbitrated, processed result being
// handed off to a controlling processor (stands in for the
// x86 host side in the real MobilFlex concept).
//
// CLKS_PER_BIT = clock_freq / baud_rate
// Default below assumes a 50 MHz clock and 115200 baud
// (50,000,000 / 115200 ~= 434). Change to match your clock.
// ============================================================

module uart_tx #(
    parameter CLKS_PER_BIT = 434
)(
    input  wire       clk,
    input  wire       rst,

    input  wire        tx_start,
    input  wire [7:0]  tx_data,

    output reg          tx_line,
    output reg          busy
);

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  data_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= S_IDLE;
            tx_line  <= 1'b1;   // idle line is high
            busy     <= 1'b0;
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            data_reg <= 8'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx_line <= 1'b1;
                    busy    <= 1'b0;
                    if (tx_start && !busy) begin
                        data_reg <= tx_data;
                        busy     <= 1'b1;
                        clk_cnt  <= 16'd0;
                        state    <= S_START;
                    end
                end

                S_START: begin
                    tx_line <= 1'b0; // start bit
                    if (clk_cnt < CLKS_PER_BIT-1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        bit_idx <= 3'd0;
                        state   <= S_DATA;
                    end
                end

                S_DATA: begin
                    tx_line <= data_reg[bit_idx];
                    if (clk_cnt < CLKS_PER_BIT-1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        if (bit_idx < 3'd7)
                            bit_idx <= bit_idx + 1'b1;
                        else
                            state <= S_STOP;
                    end
                end

                S_STOP: begin
                    tx_line <= 1'b1; // stop bit
                    if (clk_cnt < CLKS_PER_BIT-1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        busy    <= 1'b0;
                        state   <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
