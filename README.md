# Concurrent Multi-Channel I/O Aggregator (FPGA demo, Verilog)

A small, self-contained FPGA project demonstrating concurrent,
fair multi-channel I/O handling — the same category of problem
MobilFlex's LOT concept addresses (multiple simultaneous
device-to-host transactions instead of one at a time).

**This is an original, independent project built from public,
general engineering concepts — it does not use or reference
any of MobilFlex's actual architecture or IP.**

## What it demonstrates

- 3 independent simulated "IoT devices" (`data_gen.v`), each
  producing data at its own pseudo-random, uncoordinated timing
- A small FIFO buffer per channel (`channel_fifo.v`) so no data
  is lost while waiting to be serviced
- A **round-robin arbiter** (`rr_arbiter.v`) — the core of the
  project — that fairly rotates between channels so no single
  channel is starved
- A simple tagging/processing stage (`processor.v`)
- A UART transmitter (`uart_tx.v`) representing the hand-off to
  a host system

## Files

| File | Purpose |
|---|---|
| `data_gen.v` | Simulated IoT device / data source |
| `channel_fifo.v` | Per-channel buffer (depth 4) |
| `rr_arbiter.v` | Round-robin arbiter FSM (core logic) |
| `processor.v` | Tags arbitrated data with channel id |
| `uart_tx.v` | UART transmitter to host |
| `top.v` | Top-level wiring |
| `tb_top.v` | Testbench / simulation driver |

## How to run

### Option A: Icarus Verilog (already verified working)
```
iverilog -o sim.out data_gen.v channel_fifo.v rr_arbiter.v processor.v uart_tx.v top.v tb_top.v
vvp sim.out
```
This prints a live log of every time the arbiter services a
channel, and writes `waves.vcd` (open with GTKWave to see the
waveforms).

### Option B: Vivado
1. Create a new RTL project.
2. Add all `.v` files above as design sources, with `tb_top.v`
   set as the simulation source.
3. Run Behavioral Simulation.
4. View the waveform, or check the Tcl console log for the
   `$display` output from the testbench.

### Option C: ModelSim
```
vlog data_gen.v channel_fifo.v rr_arbiter.v processor.v uart_tx.v top.v tb_top.v
vsim tb_top
run -all
```

## Verified result (from actual simulation run)

Out of ~190 events over the test run, the three channels were
serviced:
- Channel 0: 61 times
- Channel 1: 68 times
- Channel 2: 61 times

Close to even across all three — proof the round-robin
arbitration is fair and no channel is starved, even though the
3 simulated devices fire completely independently of each
other.

## Known simplifications (documented on purpose)

- Only the 8-bit data byte is sent over UART in this version;
  the channel id is visible in the simulation log/waveform
  rather than transmitted as a second byte. A v2 could add a
  2-byte UART frame (channel byte + data byte).
- FIFO depth is small (4 entries) — enough to prove the
  concept without overcomplicating the design.
- This is simulation-only (no physical FPGA board used yet);
  the design is written in synthesizable Verilog and should map
  to real hardware (e.g. a Basys 3 / Nexys board) with minimal
  changes if a board becomes available later.

## Round-robin arbiter FSM

```
        ┌────────────────────────────────────┐
        │                                     │
        ▼                                     │
   ┌─────────┐   current channel empty?  ┌────┴────┐
   │ S_CHECK │──────── yes ──────────────▶│ advance │
   │         │                            │ pointer │
   └────┬────┘                            └─────────┘
        │
        │ no (data waiting)
        │ -> pulse rd_en for that channel
        ▼
   ┌───────────┐
   │ S_CAPTURE │  data is now valid (FIFO registered it)
   │           │  -> tag with channel id, raise out_valid
   │           │  -> advance pointer to next channel
   └─────┬─────┘
         │
         └──────────────► back to S_CHECK
```
