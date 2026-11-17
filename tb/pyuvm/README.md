# pyuvm testbench (UVM in Python)

An extra testbench I built beyond the onboarding scope. The required onboarding testbench is
class-based SystemVerilog; this one rebuilds the same idea with real UVM structure in Python
using [pyuvm](https://github.com/pyuvm/pyuvm) on [cocotb](https://www.cocotb.org/), and adds a
Python golden model so every program is checked automatically. Built with Claude Code as my
coding agent.

## What it does

| Piece | File | Job |
|---|---|---|
| Golden model | `rv32_golden.py` | Executes the 9-instruction subset (add, sub, sll, srl, addi, lw, sw, beq, ebreak) architecturally and predicts the final registers and data memory. Includes a small assembler so tests can be written in assembly. |
| Sequences | `test_rv32_pyuvm.py` | `DirectedSeq` (wraparound, shift-amount masking, load-use `beq`, x0) and `RandomProgramSeq` (constrained-random programs: hazard-biased registers, word-aligned memory offsets, forward in-bounds branches, always ends in `ebreak`). |
| Driver | `test_rv32_pyuvm.py` | Only component that drives DUT pins: reset, load ISRAM/DSRAM over the external port, pulse `en_cpu_i`, wait for the halt pulse, then read state back. |
| Monitor | `test_rv32_pyuvm.py` | Passive. Rebuilds the halt and every read response from the pins, so a broken driver can't make a broken DUT look correct. |
| Scoreboard | `test_rv32_pyuvm.py` | Runs each program through the golden model (with a shadow copy of data memory, because the SRAMs keep their contents across resets) and compares all 32 registers and 64 data words. |

```
ProgramSeq -> Sequencer -> Driver --pins--> chip_top
                             |                  |
                  expected   |                  | pins (passive)
                             v                  v
                        Scoreboard <-- actual -- Monitor
                             |
                             +-- RV32Model golden prediction
```

## Results

- Golden model matches all 12 club directed tests (registers and data memory).
- Directed + 40 random programs (seed 7): **44/44 pass** on my core.
- Sanity check: injecting a shift-amount bug (`rs2[5:0]` instead of `rs2[4:0]`, the same class
  of bug as bug 1 in the encrypted-CPU hunt) fails `shift_low5` and a random program.

## Running it

The club's `chip_top`, memory controller, SRAM wrapper, and SRAM model are not in this public
repo, so point `RTL_DIR` at a full onboarding checkout.

```bash
pip install -r requirements.txt
make SIM=xcelium RTL_DIR=~/Silicon-Jackets-Onboarding/src/verilog         # SJ server
make SIM=xcelium TESTCASE=RandomTest SEED=1234 NUM_PROGRAMS=200            # reproduce / scale
```
