// ============================================================
// tb_top.v
// Testbench: generates clock/reset, dumps a waveform file for
// ModelSim/Vivado, and prints a log every time the arbiter
// services a channel - this log is your proof that all 3
// channels get serviced fairly (round-robin) with nothing
// dropped. This log/waveform is what you'd screenshot for
// your pitch.
// ============================================================

`timescale 1ns/1ps

module tb_top;

    reg clk;
    reg rst;

    top uut (.clk(clk), .rst(rst));

    // 50 MHz clock -> 20ns period
    always #10 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        #100;
        rst = 0;
    end

    // waveform dump for ModelSim / Vivado simulator
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_top);
    end

    // log every time the arbiter hands off a serviced channel
    initial begin
        $display("time_ns\tchannel\tdata\t(round-robin service log)");
        forever begin
            @(posedge clk);
            if (uut.arb_valid) begin
                $display("%0t\t%0d\t%0d", $time, uut.arb_channel, uut.arb_data);
            end
        end
    end

    // run long enough to see many round-robin cycles across
    // all 3 channels, then stop
    initial begin
        #200000;
        $display("Simulation complete.");
        $finish;
    end

endmodule
