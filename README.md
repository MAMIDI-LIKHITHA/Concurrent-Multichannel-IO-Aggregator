# Concurrent Multi-Channel I/O Aggregator

An FPGA-based proof-of-concept in **concurrent I/O handling** — three independent, uncoordinated data sources, buffered and fairly arbitrated in hardware, with no data loss and no channel starvation.

Designed in Verilog, **simulated in Icarus Verilog**, and **synthesized to gate level in Yosys** — verified end to end, not just simulation-only.

## The problem this models

Edge and IoT systems increasingly need to handle many independent devices sending data concurrently rather than one at a time. Standard architectures often process I/O sequentially, creating a bottleneck as the number of connected devices grows. This project is a small, self-contained demonstration of the underlying engineering problem: accept data from multiple independent, uncoordinated sources and service them fairly — with no data lost and no single channel starved of attention.

This is an original, independent project. It does not use or reference any third party's proprietary architecture or intellectual property.

## Architecture

```
data_gen (x3) ──▶ channel_fifo (x3) ──▶ rr_arbiter ──▶ processor ──▶ uart_tx ──▶ Host / PC
 (3 independent    (depth-4 buffer,     (round-robin    (tag +      (8N1 serial
  IoT sources)       per channel)        FSM, the        package)    hand-off)
                                          core)
```

| Module | Role |
|---|---|
| `data_gen` | Simulated IoT device; produces pseudo-random data at pseudo-random, independent intervals |
| `channel_fifo` | Depth-4 buffer per channel; holds data safely while the arbiter is busy elsewhere |
| `rr_arbiter` | **Core round-robin arbiter FSM** — fairly selects which channel is serviced each cycle |
| `processor` | Tags arbitrated data with its source channel id |
| `uart_tx` | 8N1 UART transmitter; hands processed data off to a host system |
| `top` | Top-level wiring of all instances; exposes observable output ports |
| `tb_top` | Testbench — drives simulation, logs every arbiter service event |

## How it works

1. **Three independent sources** each generate data at their own pseudo-random timing — none aware of or synchronized with the others.
2. **Each source writes into its own FIFO buffer**, so data is never lost even while the arbiter is busy servicing a different channel.
3. **The round-robin arbiter** — a 2-state FSM — checks each channel in turn. If a channel has data waiting, it pulses a read, tags the data with its channel id, and moves to the next channel. If empty, it just advances the pointer. This guarantees fairness: no channel is starved, and none can monopolize the arbiter.
4. **Serviced data is tagged and forwarded over UART** to a host — representing the hand-off to a host processor in a real system.

### Arbiter FSM

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

## Verified results

### Simulation (Icarus Verilog)
Ran a 200µs test with all three channels firing independently, logging every arbiter service event.

| Channel | Times Serviced | Share |
|---|---|---|
| Channel 0 | 61 | 32.1% |
| Channel 1 | 68 | 35.8% |
| Channel 2 | 61 | 32.1% |
| **Total** | **190** | **100%** |

Close to even across all three — confirming fair round-robin arbitration with no channel starved, even though the three sources fire completely independently. Also visually verified in GTKWave (FSM state, pointer, and output-valid signals transition correctly).

### Synthesis (Yosys / OSS CAD Suite)
The same source files were synthesized to gate level — every module mapped cleanly to real logic gates and flip-flops, with no unresolved or unsynthesizable constructs.

| Metric | Count |
|---|---|
| Total cells | 894 |
| Total wires | 658 (1,249 wire bits) |
| Total ports | 69 (186 port bits) |

This confirms the design is genuinely implementable in real hardware — not simulation-only.

## How to run it yourself

**Simulation:**
```bash
iverilog -o sim.out data_gen.v channel_fifo.v rr_arbiter.v processor.v uart_tx.v top.v tb_top.v
vvp sim.out
```

**Synthesis:**
```bash
yosys -p "read_verilog data_gen.v channel_fifo.v rr_arbiter.v processor.v uart_tx.v top.v; synth -top top; stat"
```

## Known simplifications

- Only the 8-bit data byte is sent over UART in this version; the channel id is visible in the simulation log/waveform rather than transmitted as a second byte.
- FIFO depth is small (4 entries) — enough to prove the concept without overcomplicating the design.
- This is simulation-verified; the design is written in synthesizable Verilog and should map to real hardware (e.g. a Basys 3 / Nexys board) with minimal changes if a physical board becomes available.

---

Built and verified independently as a demonstration of concurrent I/O handling on FPGA hardware.
