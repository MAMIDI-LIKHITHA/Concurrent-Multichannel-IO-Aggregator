// ============================================================
// rr_arbiter.v
// THE CORE MODULE. Decides which of the 3 channels gets
// serviced next, using round-robin (fair, take-turns)
// arbitration - so no single channel can be starved and no
// channel has to wait indefinitely just because another
// channel is busy.
//
// FSM states:
//   S_CHECK   - look at the channel the pointer is on.
//               if it has data waiting (not empty), pulse
//               its read-enable and move to S_CAPTURE.
//               if it's empty, advance the pointer to the
//               next channel and stay in S_CHECK.
//   S_CAPTURE - the FIFO's registered output is now valid
//               (1 cycle after rd_en). Tag it with the
//               channel id, raise out_valid for 1 cycle,
//               advance the pointer, and go back to S_CHECK.
// ============================================================

module rr_arbiter (
    input  wire       clk,
    input  wire       rst,

    // status from the 3 channel FIFOs
    input  wire        empty0,
    input  wire        empty1,
    input  wire        empty2,

    // read-enable pulses back to the 3 channel FIFOs
    output reg          rd_en0,
    output reg          rd_en1,
    output reg          rd_en2,

    // registered data outputs from the 3 channel FIFOs
    input  wire [7:0]  data0,
    input  wire [7:0]  data1,
    input  wire [7:0]  data2,

    // single arbitrated output stream
    output reg  [7:0]  out_data,
    output reg  [1:0]  out_channel,
    output reg          out_valid
);

    localparam S_CHECK   = 1'b0;
    localparam S_CAPTURE = 1'b1;

    reg       state;
    reg [1:0] ptr;   // which channel (0,1,2) we are currently pointing at

    wire cur_empty = (ptr == 2'd0) ? empty0 :
                     (ptr == 2'd1) ? empty1 : empty2;

    function [1:0] next_ptr;
        input [1:0] p;
        begin
            next_ptr = (p == 2'd2) ? 2'd0 : p + 2'd1;
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= S_CHECK;
            ptr         <= 2'd0;
            rd_en0      <= 1'b0;
            rd_en1      <= 1'b0;
            rd_en2      <= 1'b0;
            out_valid   <= 1'b0;
            out_channel <= 2'd0;
            out_data    <= 8'd0;
        end else begin
            // defaults each cycle - these are pulses, not held levels
            rd_en0    <= 1'b0;
            rd_en1    <= 1'b0;
            rd_en2    <= 1'b0;
            out_valid <= 1'b0;

            case (state)
                S_CHECK: begin
                    if (!cur_empty) begin
                        // this channel has data waiting - service it
                        if (ptr == 2'd0)      rd_en0 <= 1'b1;
                        else if (ptr == 2'd1) rd_en1 <= 1'b1;
                        else                  rd_en2 <= 1'b1;

                        out_channel <= ptr;
                        state       <= S_CAPTURE;
                    end else begin
                        // nothing here right now - move on to the next channel
                        ptr <= next_ptr(ptr);
                        // stays in S_CHECK; next channel gets checked next cycle
                    end
                end

                S_CAPTURE: begin
                    // FIFO's rd_data is now valid (registered on the edge
                    // that moved us into this state)
                    out_data  <= (out_channel == 2'd0) ? data0 :
                                 (out_channel == 2'd1) ? data1 : data2;
                    out_valid <= 1'b1;
                    ptr       <= next_ptr(out_channel);
                    state     <= S_CHECK;
                end

                default: state <= S_CHECK;
            endcase
        end
    end

endmodule
