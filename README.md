# RV32I Core: Design and Verification

A multicycle RV32I subset core in SystemVerilog, and the constrained-random testbench that verified it to 100% code coverage and then found three bugs in an unseen pipelined CPU.

Built during Silicon Jackets (Georgia Tech's student chip-design team) onboarding, Fall 2026: Digital Design track first, then Design Verification. This repo holds only my own work. The club's scaffolding, build system, and encrypted reference CPUs are not included, so it is a portfolio snapshot rather than a buildable project.

## Highlights

| | |
|---|---|
| Core | Multicycle RV32I subset: decode, ALU, FSM control, load/store, `beq`, `ebreak`. Directed regression 12/12. |
| Directed tests | 32 tests: arithmetic wrap, shift-amount masking, x0, RAW and load-use hazards, memory boundaries, far branches, PC wrap, reset recovery |
| Constrained random | Random program generator with instruction and external-port constraints |
| Assertions | 7 SVA properties; each proven to fire with a forced violation (logs in `docs/evidence/`) |
| Coverage | **100%** overall code coverage (2040/2040) on the DUT, Xcelium + IMC |
| pyuvm testbench | Extra, beyond onboarding: UVM in Python (pyuvm on cocotb) with a Python golden model and scoreboard; 44/44 directed + random programs pass (`tb/pyuvm/`) |
| Timing script | `pd/slack_rank.py` ranks the 10 worst setup and hold paths from a timing report and shows where violations cluster |
| Bugs found | Assertion 3.3 caught a sticky `halted` bug in my own core; 3.4 caught a driver race. Bug hunt found 3 bugs in an encrypted pipelined CPU (below). |

## Bug hunt results (encrypted pipelined CPU)

1. **Shift amount used `rs2[5:0]` instead of `rs2[4:0]`.** Found by random program; directed test `shift_amount_low5` also caught it.
2. **`beq` right after `lw` compared the stale register.** A missing load-use stall.
3. **Load right after store returned the store's data on a partial address match.** Bad store-to-load forwarding.

Each bug has a minimal reproducer, seed, waveform screenshot (`docs/screenshots/`), and root-cause write-up in [`docs/testplan_final.md`](docs/testplan_final.md#4-encrypted-cpu-bug-hunt).

## Layout

```
rtl/    alu.sv, decode.sv, cpu_top.sv     my RTL (fetch, register file, SRAM wrapper were provided)
tb/     cpu_tb_top.sv, driver, monitor,   club scaffold + my sequences, assertions, CRV,
        scoreboard, seq/xbar items        coverage and monitor fixes
        exclusions.vRefine                coverage exclusions with justification
tb/pyuvm/                                 pyuvm testbench + Python golden model (my extra work)
pd/     slack_rank.py                     timing-report parser that ranks worst setup/hold paths
docs/   testplan_initial.md               plan reviewed before implementation
        testplan_final.md                 final plan, coverage closure, bug-hunt reports
        evidence/                         forced-violation logs, one per assertion
        screenshots/                      waveforms for each bug, final coverage
```

## Tools

SystemVerilog, Cadence Xcelium (`xrun`), IMC coverage, SimVision. Python, pyuvm, cocotb.
