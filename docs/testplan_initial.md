# Fall 2026 DV Onboarding Test Plan

<!--
Make two copies of this template:
  1. testplan_initial.md, submitted before implementing tests.
  2. testplan_final.md, updated after implementation and coverage closure.

Keep the initial copy unchanged after review. HTML comments are editing
instructions and disappear from rendered Markdown.
-->
## Document information

| Field | Value |
| --- | --- |
| Verification engineer | Matthew Fischer, matthewfischer_93858, mfischer61 |
| Plan revision | Initial |
| Date | 2026-09-25 |

### Revision history

| Revision | Date | Changes |
| --- | --- | --- |
| Initial | 2026-09-25| Initial planned tests |
| Final | YYYY-MM-DD | <!-- Tests or constraints added after debugging and coverage review --> |

## 1. Functional tests

<!--
Plan tests for the CPU functionality supported by this onboarding. Organize
related behavior together. Include both individual instruction behavior and
multi-instruction sequences where ordering or dependencies matter.

Add as many rows and detailed test records as needed. Do not put every CPU
operation into one large program: each failure should identify a reasonably
small area to debug.
-->

### Functional-test summary

| Test ID | Test name | Functionality being tested | Expected result | Status |
| --- | --- | --- | --- | --- |
| 1.1 | `addi_basic_signs` | `addi` with positive and negative immediates, and a dependent `addi` | x1=0x5, x2=0xFFFFFFFB, x3=0x69, x4=0x0 | Planned |
| 1.2 | `addi_imm_limits` | `addi` at the 12-bit immediate limits also testing 32-bit wraparound | x1=0x7FF, x2=0xFFFFF800, x3=0xFFFFFFFF, x4=0x0, x5=0x800 | Planned |
| 1.3 | `add_basic` | `add` with positive/negative operands and `x0` as a source | x3=0x4, x4=0xFFFFFFFA, x5=0x7, x6=0x0 | Planned |
| 1.4 | `add_overflow_wrap` | `add` 32-bit wraparound, chained with `srl` | x3=0x0, x4=0x7FFFFFFF, x5=0x80000000, x6=0x0 | Planned |
| 1.5 | `sub_basic` | `sub` operand order and identity/zero cases | x3=0x7, x4=0xFFFFFFF9, x5=0x0, x6=0xFFFFFFFD, x7=0xA | Planned |
| 1.6 | `sub_wrap_min_int` | `sub` at INT_MIN boundary and distinguishes `sub` from `add` | x3=0x80000000, x4=0x7FFFFFFF, x5=0x80000000, x6=0xFFFFFFFF | Planned |
| 1.7 | `sll_amounts` | `sll` at shift amounts 0 and 31 | results 0x1, 0x80000000, 0xFFFFFFFF, 0x80000000 | Planned |
| 1.8 | `srl_logical_fill` | `srl` zero-fills from the top to make sure it's not arithmetic | results 0x7FFFFFFF, 0x1, 0xFFFFFFFF, 0x1 | Planned |
| 1.9 | `shift_amount_low5` | Shift amount uses only the low 5 bits of rs2 (mod 32) | shamt 32→shift0, 33→shift1, −1→shift31; 0x80000000 srl 33 = 0x40000000 | Planned |
| 1.10 | `addi_rd_equals_rs1` | rd==rs1 read-modify-write chaining together `addi`/`add` | x1=0xD→0x1A, x2=0x1A | Planned |
| 1.11 | `waw_overwrite` | Back-to-back writes to the same register (WAW) resolve to the last write | x1=0x3, x2=0x3 | Planned |
| 1.12 | `x0_hardwired` | Makes sure that writes to `x0` are discarded and that `x0` always reads 0 | x2=0x9, x3=0x0, x4=0x0 | Planned |
| 1.13 | `lw_offsets` | `lw` at offset 0, positive/negative base+offset combos | x-regs load 0x11111111, 0xDEADBEEF, 0xFFFFFFFF, 0x80000000, 0x12345678, 0xCAFEF00D, 0x0; word 1 never loaded (decoy) | Planned |
| 1.14 | `sw_offsets` | `sw` at multiple words including a negative-offset store, and store at x0 | dmem[0]=0x123, dmem[1]=0xFFFFFFFF, dmem[9]=0x123, dmem[10]=0xFFFFFFFF, dmem[2]=0x0 | Planned |
| 1.15 | `sw_then_lw_same_word` | Store-then-load and load-then-modify-then-store to the same address | x-regs 0x4D then 0x4E; dmem[3]=0x4E | Planned |
| 1.16 | `mem_boundaries` | `lw`/`sw` at the top of the addressable data-memory range (word 511/1023) | dmem[1023]=0xFFFFFFFF, dmem[511] round-trips | Planned |
| 1.17 | `beq_taken_skips` | Make sure that `beq` skips the intervening instructions | x3=0x0, x4=0x0, x5=0x1 | Planned |
| 1.18 | `beq_not_taken` | `beq` always falls through on inequality to the next instrcution, including an MSB-only difference | x3=0x1, x7=0x1 | Planned |
| 1.19 | `beq_x0_and_plus4` | `beq x0,x0` (always-taken) at +4 and +8 targets | x1=0x1, x2=0x0, x3=0x3 | Planned |
| 1.20 | `beq_backward_loop` | Backward-taken `beq` still loops and exits correctly | x1=0x0, x2=0xF, x4=0x1 | Planned |
| 1.21 | `beq_over_ebreak` | A taken branch over an `ebreak` must ignore it and not halt (basically checking the branching again) | x2=0x2 | Planned |
| 1.22 | `raw_alu_distances` | RAW hazards at dependency distances 1–3 resolve correctly, make sure the register holds values through multiple clock cycles| x5=0x17, x6=0xA | Planned |
| 1.23 | `load_use_hazards` | A load result is consumed immediately as add/shift/base/store-data/branch operand | x2=0x14, x4=0xA0, x6=0x0BADF00D, x7=0x0, dmem[8]=0x0BADF00D, x8=0x0 | Planned |
| 1.24 | `store_operand_hazards` | `sw` reads rs1/rs2 in the same cycle they're updated by adjacent instructions | dmem[5]=0x63, dmem[6]=0x64, dmem[7]=0x64 | Planned |
| 1.25 | `branch_operand_hazard` | `beq` reads operands updated immediately before it, checking the clocking of the FSM | x3=0x0, x4=0x1 | Planned |
| 1.26 | `unsupported_encodings_nop` | Unsupported opcodes (xor/sra/all-zero/slti/lui) decode as no-ops and don't execute anything | x3–x6=0x0, x7=0x7 | Planned |
| 1.27 | `ebreak_stops_execution` | `ebreak` halts immediately and ensures that nothing after it executes | x2=0x0, no store to dmem | Planned |
| 1.28 | `restart_after_reset` | A reset between two `run_directed` programs clears all registers and then can reinitialize after | x1=0x0, x2=0x0, x3=0x3 | Planned |
| 1.29 | `external_port_windows` | External read/write ports access ISRAM/DSRAM/register window directly (CPU idle) | ISRAM/DSRAM words 0 and 1023 round-trip (both ends); register window reads 0x0 | Planned |
| 1.30 | `external_halt_recovery` | `halt_cpu_now` stops the CPU mid-program without messing up the memory | ISRAM contents match the loaded program after the external halt | Planned |


### Functional-test details

<!-- Duplicate this complete record for every functional test. -->

### 1.1 — `addi_basic_signs`

**Functionality:** `addi` adds a sign-extended 12-bit immediate to `rs1`, for both positive and negative immediates. A later `addi` must read the result of an earlier one.

**Initial state:**

- Registers: All 0 (reset by `run_directed`).
- Data memory: None (`addi` does not access memory).
- Other setup: `run_directed` defaults (2000-cycle timeout, 16 dmem words read back).

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(5)),     // x1 = 0 + 5
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(-5)),    // x2 = 0 + (-5)
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(1), .imm(100)),   // x3 = x1 + 100
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(2), .imm(5)),     // x4 = x2 + 5
  EBREAK_WORD
};
run_directed("addi_basic_signs", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000005` | 0 + 5 |
| `x2` | `32'hFFFFFFFB` | 0 + (−5); negative immediate sign-extended to 32 bits |
| `x3` | `32'h00000069` | 5 + 100 = 105 = 0x69; reads x1 written by an earlier instruction |
| `x4` | `32'h00000000` | −5 + 5 = 0; negative value plus positive immediate |
| All other registers | `32'h00000000` | Not written |

**Pass criteria:** The CPU halts on `ebreak` before the 2000-cycle timeout. All 32 register reads need to match the expected values and `x0` reading 0. Data memory is unchanged, and there should be no scoreboard, monitor, or assertion errors.

**Final result:** Pending (will complete this in `testplan_final.md`).

### 1.2 — `addi_imm_limits`

**Functionality:** `addi` sign-extends the largest (+2047) and smallest (−2048) 12-bit immediates correctly. The result is a full 32-bit value that is not truncated to 12 bits. Also tests that it wraps modulo 2^32 when it goes past 0xFFFFFFFF.

**Initial state:**

- Registers: All 0 (reset by `run_directed`).
- Data memory: None (`addi` does not access memory).
- Other setup: `run_directed` defaults (2000-cycle timeout, 16 dmem words read back).

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(2047)),    // largest immediate
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(-2048)),   // smallest immediate
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(-1)),      // should be all ones
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(3), .imm(1)),       // 0xFFFFFFFF + 1 wraps
  asm_instr(.op(OP_ADDI), .rd(5), .rs1(1), .imm(1)),       // 2047 + 1 does not wrap
  EBREAK_WORD
};
run_directed("addi_imm_limits", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h000007FF` | +2047, the largest 12-bit immediate; sign bit is 0 so upper bits are 0 |
| `x2` | `32'hFFFFF800` | −2048, the smallest 12-bit immediate (0x800); sign bit 1 copied into bits 31:12 |
| `x3` | `32'hFFFFFFFF` | −1; all 32 bits set |
| `x4` | `32'h00000000` | 0xFFFFFFFF + 1 wraps to 0; carry out of bit 31 is dropped |
| `x5` | `32'h00000800` | 2047 + 1 = 2048; result is 32 bits, so it is not truncated to 12 bits |
| All other registers | `32'h00000000` | Not written |

**Pass criteria:** The CPU halts on `ebreak` before the 2000-cycle timeout. All 32 register reads match the expected values, with `x0` reading 0. Data memory is unchanged, and there are no scoreboard, monitor, or assertion errors.

**Final result:** Pending (completed in `testplan_final.md`).

### 1.3 — `add_basic`

**Functionality:** `add` performs register-register addition (`rd = rs1 + rs2`). This includes a negative operand and with `x0` as a source register.

**Initial state:**

- Registers: All 0 (reset by `run_directed`).
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(7)),    // x1 = 7
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(-3)),   // x2 = -3 = 0xFFFFFFFD
  asm_instr(.op(OP_ADD),  .rd(3), .rs1(1), .rs2(2)),    // x3 = x1 + x2
  asm_instr(.op(OP_ADD),  .rd(4), .rs1(2), .rs2(2)),    // x4 = x2 + x2
  asm_instr(.op(OP_ADD),  .rd(5), .rs1(1), .rs2(0)),    // x5 = x1 + x0
  asm_instr(.op(OP_ADD),  .rd(6), .rs1(0), .rs2(0)),    // x6 = x0 + x0
  EBREAK_WORD
};
run_directed("add_basic", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000007` | 7 |
| `x2` | `32'hFFFFFFFD` | −3, sign-extended by `addi` |
| `x3` | `32'h00000004` | 7 + (−3) = 4 |
| `x4` | `32'hFFFFFFFA` | −3 + (−3) = −6 |
| `x5` | `32'h00000007` | 7 + 0; `add` reads `x0` correctly as a source |
| `x6` | `32'h00000000` | 0 + 0 |
| All other registers | `32'h00000000` | Not written |

**Pass criteria:** Halts on `ebreak` before the 2000-cycle timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending (completed in `testplan_final.md`).

### 1.4 — `add_overflow_wrap`

**Functionality:** `add` performs plain 32-bit addition with silent wraparound, or no overflow warning basically. Chaining the wrapped result into `srl` and back into `add` exercises the same wraparound at both ends of the 32-bit range.

**Initial state:**

- Registers: All 0 (reset by `run_directed`).
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(-1)),   // x1 = -1 = 0xFFFFFFFF
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)),    // x2 = 1
  asm_instr(.op(OP_ADD),  .rd(3), .rs1(1), .rs2(2)),    // x3 = x1 + x2
  asm_instr(.op(OP_SRL),  .rd(4), .rs1(1), .rs2(2)),    // x4 = x1 >> x2
  asm_instr(.op(OP_ADD),  .rd(5), .rs1(4), .rs2(2)),    // x5 = x4 + x2
  asm_instr(.op(OP_ADD),  .rd(6), .rs1(5), .rs2(5)),    // x6 = x5 + x5
  EBREAK_WORD
};
run_directed("add_overflow_wrap", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'hFFFFFFFF` | -1 |
| `x2` | `32'h00000001` | 1 |
| `x3` | `32'h00000000` | 0xFFFFFFFF + 1 wraps to 0 via `add` (not just `addi`) |
| `x4` | `32'h7FFFFFFF` | 0xFFFFFFFF >> 1, logical shift, top bit zero-filled |
| `x5` | `32'h80000000` | 0x7FFFFFFF + 1 |
| `x6` | `32'h00000000` | 0x80000000 + 0x80000000 wraps to 0 |
| All other registers | `32'h00000000` | Not written |

**Pass criteria:** Halts on `ebreak` before the 2000-cycle timeout. All 32 registers match, with `x0` reading 0. Data memory is unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending (completed in `testplan_final.md`).

### 1.5 — `sub_basic`

**Functionality:** `sub` computes `rs1 - rs2`. This test checks that the operand order is not swapped, which is a common mistake, and also that `x0` behaves correctly as either operand.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(10)),   // x1 = 10
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(3)),    // x2 = 3
  asm_instr(.op(OP_SUB),  .rd(3), .rs1(1), .rs2(2)),    // x3 = x1 - x2
  asm_instr(.op(OP_SUB),  .rd(4), .rs1(2), .rs2(1)),    // x4 = x2 - x1 (order check)
  asm_instr(.op(OP_SUB),  .rd(5), .rs1(1), .rs2(1)),    // x5 = x1 - x1
  asm_instr(.op(OP_SUB),  .rd(6), .rs1(0), .rs2(2)),    // x6 = x0 - x2
  asm_instr(.op(OP_SUB),  .rd(7), .rs1(1), .rs2(0)),    // x7 = x1 - x0
  EBREAK_WORD
};
run_directed("sub_basic", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h0000000A` | 10 |
| `x2` | `32'h00000003` | 3 |
| `x3` | `32'h00000007` | 10 − 3 |
| `x4` | `32'hFFFFFFF9` | 3 − 10 = −7; catches a swapped-operand bug |
| `x5` | `32'h00000000` | 10 − 10 |
| `x6` | `32'hFFFFFFFD` | 0 − 3 = −3 |
| `x7` | `32'h0000000A` | 10 − 0 |
| All other registers | `32'h00000000` | Not written |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.6 — `sub_wrap_min_int`

**Functionality:** `sub` at 32'h80000000 (`INT_MIN`) must not overflow or misbehave: subtracting 1 from it, negating it, and negating 1 all wrap it correctly within the bit. `x6 = 0 - x1` in particular only reads `32'hFFFFFFFF`. If `sub` were mis-decoded as `add` (if the `funct7` bit 30 was ignored), `x6` would instead read `32'h00000001`.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),    // x1 = 1
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(31)),   // x2 = 31 (shift amount)
  asm_instr(.op(OP_SLL),  .rd(3), .rs1(1), .rs2(2)),    // x3 = 1 << 31 = 0x80000000
  asm_instr(.op(OP_SUB),  .rd(4), .rs1(3), .rs2(1)),    // x4 = x3 - 1
  asm_instr(.op(OP_SUB),  .rd(5), .rs1(0), .rs2(3)),    // x5 = 0 - x3
  asm_instr(.op(OP_SUB),  .rd(6), .rs1(0), .rs2(1)),    // x6 = 0 - x1
  EBREAK_WORD
};
run_directed("sub_wrap_min_int", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000001` | 1 |
| `x2` | `32'h0000001F` | 31 |
| `x3` | `32'h80000000` | 1 << 31, built via `sll` since there's no load-immediate for a value of this size |
| `x4` | `32'h7FFFFFFF` | 0x80000000 − 1 |
| `x5` | `32'h80000000` | 0 − 0x80000000 wraps to itself because `INT_MIN` has no positive counterpart |
| `x6` | `32'hFFFFFFFF` | 0 − 1 = −1; would read `32'h00000001` if `sub` were mis-decoded as `add` |
| All other registers | `32'h00000000` | Not written |

**Pass criteria:** Halts on `ebreak` before the timeout of 2,000 cycles. All 32 registers are matching, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.7 — `sll_amounts`

**Functionality:** `sll` shifts `rs1` left by the low 5 bits of `rs2`. This test covers shift amount 0 (no-op) and 31 (moves the LSB or preserves the MSB) against both a single-bit value and an all-ones value.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),    // x1 = 1
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(0)),    // x2 = 0 (shift amount)
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(31)),   // x3 = 31 (shift amount)
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(-1)),   // x4 = 0xFFFFFFFF
  asm_instr(.op(OP_SLL),  .rd(6), .rs1(1), .rs2(2)),    // x6 = 1 << 0
  asm_instr(.op(OP_SLL),  .rd(7), .rs1(1), .rs2(3)),    // x7 = 1 << 31
  asm_instr(.op(OP_SLL),  .rd(8), .rs1(4), .rs2(2)),    // x8 = 0xFFFFFFFF << 0
  asm_instr(.op(OP_SLL),  .rd(9), .rs1(4), .rs2(3)),    // x9 = 0xFFFFFFFF << 31
  EBREAK_WORD
};
run_directed("sll_amounts", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x6` | `32'h00000001` | 1 << 0 |
| `x7` | `32'h80000000` | 1 << 31 |
| `x8` | `32'hFFFFFFFF` | 0xFFFFFFFF << 0 |
| `x9` | `32'h80000000` | 0xFFFFFFFF << 31 because only the LSB survives, shifted all the way to bit 31 |
| All other registers | see program | `x1`=1, `x2`=0, `x3`=31, `x4`=0xFFFFFFFF |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.8 — `srl_logical_fill`

**Functionality:** `srl` must zero-fill the high bits regardless of the sign of `rs1`. This distinguishes it from an arithmetic shift, which the CPU doesn't implement.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),    // x1 = 1
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(-1)),   // x2 = 0xFFFFFFFF
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(31)),   // x3 = 31 (shift amount)
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(1)),    // x4 = 1 (shift amount)
  asm_instr(.op(OP_ADDI), .rd(5), .rs1(0), .imm(0)),    // x5 = 0 (shift amount)
  asm_instr(.op(OP_SLL),  .rd(6), .rs1(1), .rs2(3)),    // x6 = 1 << 31 = 0x80000000
  asm_instr(.op(OP_SRL),  .rd(7), .rs1(2), .rs2(4)),    // x7 = 0xFFFFFFFF >> 1
  asm_instr(.op(OP_SRL),  .rd(8), .rs1(2), .rs2(3)),    // x8 = 0xFFFFFFFF >> 31
  asm_instr(.op(OP_SRL),  .rd(9), .rs1(2), .rs2(5)),    // x9 = 0xFFFFFFFF >> 0
  asm_instr(.op(OP_SRL),  .rd(10),.rs1(6), .rs2(3)),    // x10 = 0x80000000 >> 31
  EBREAK_WORD
};
run_directed("srl_logical_fill", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x7` | `32'h7FFFFFFF` | 0xFFFFFFFF >> 1, top bit zero-filled, whereas an arithmetic shift would give 0xFFFFFFFF |
| `x8` | `32'h00000001` | 0xFFFFFFFF >> 31 |
| `x9` | `32'hFFFFFFFF` | shift by 0 is a no-op |
| `x10` | `32'h00000001` | 0x80000000 >> 31 |
| All other registers | see program | `x1`=1, `x2`=0xFFFFFFFF, `x3`=31, `x4`=1, `x5`=0, `x6`=0x80000000 |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.9 — `shift_amount_low5`

**Functionality:** Per the ISA, the shift amount is the low 5 bits of `rs2` and the rest of `rs2` is ignored. Shift amounts of 32 and 33 must behave like 0 and 1, and −1 (all ones) must behave like 31.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),    // x1 = 1
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(32)),   // x2 = 32 -> low 5 bits = 0
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(33)),   // x3 = 33 -> low 5 bits = 1
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(-1)),   // x4 = 0xFFFFFFFF -> low 5 bits = 31
  asm_instr(.op(OP_SLL),  .rd(5), .rs1(1), .rs2(2)),    // x5 = 1 << (32 & 0x1F) = 1 << 0
  asm_instr(.op(OP_SLL),  .rd(6), .rs1(1), .rs2(3)),    // x6 = 1 << (33 & 0x1F) = 1 << 1
  asm_instr(.op(OP_SLL),  .rd(7), .rs1(1), .rs2(4)),    // x7 = 1 << (-1 & 0x1F) = 1 << 31
  asm_instr(.op(OP_SRL),  .rd(8), .rs1(7), .rs2(3)),    // x8 = 0x80000000 >> (33 & 0x1F) = >> 1
  asm_instr(.op(OP_SRL),  .rd(9), .rs1(7), .rs2(2)),    // x9 = 0x80000000 >> (32 & 0x1F) = >> 0
  EBREAK_WORD
};
run_directed("shift_amount_low5", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x5` | `32'h00000001` | shift amount 32 truncates to 0 |
| `x6` | `32'h00000002` | shift amount 33 truncates to 1 |
| `x7` | `32'h80000000` | shift amount −1 truncates to 31 |
| `x8` | `32'h40000000` | 0x80000000 >> 1 (33→1) |
| `x9` | `32'h80000000` | 0x80000000 >> 0 (32→0), unchanged |
| All other registers | see program | `x1`=1, `x2`=32, `x3`=33, `x4`=0xFFFFFFFF |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.10 — `addi_rd_equals_rs1`

**Functionality:** `rd == rs1` means each instruction must read the register's just-written value and not a stale one. This chains three `addi x1,x1,imm` in a row, then `add x1,x1,x1` (`rd == rs1 == rs2` simultaneously). And then it copies the result to `x2` to ultimately confirm it landed correctly.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),    // x1 = 0 + 1 = 1
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1)),    // x1 = 1 + 1 = 2
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1)),    // x1 = 2 + 1 = 3
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(10)),   // x1 = 3 + 10 = 13
  asm_instr(.op(OP_ADD),  .rd(1), .rs1(1), .rs2(1)),    // x1 = 13 + 13 = 26
  asm_instr(.op(OP_ADD),  .rd(2), .rs1(1), .rs2(0)),    // x2 = x1
  EBREAK_WORD
};
run_directed("addi_rd_equals_rs1", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h0000001A` | 1+1+1+10 = 13, then 13+13 = 26 = 0x1A |
| `x2` | `32'h0000001A` | Copy of `x1`, confirming the `rd==rs1==rs2` `add` landed correctly |
| All other registers | `32'h00000000` | Not written |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.11 — `waw_overwrite`

**Functionality:** Three back-to-back `addi`s target `x1` with no instruction reading it in between. The architectural result must be the last write. A correctly pipelined CPU that isn't forwarding/ordering writes correctly might let one of the earlier writes execute incorrectly.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),    // x1 = 1
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(2)),    // x1 = 2 (overwrites and doesn't read old x1)
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(3)),    // x1 = 3 (overwrites again)
  asm_instr(.op(OP_ADD),  .rd(2), .rs1(1), .rs2(0)),    // x2 = x1
  EBREAK_WORD
};
run_directed("waw_overwrite", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000003` | Last of the three writes wins |
| `x2` | `32'h00000003` | Confirms `x1` reads back the last write, not 1 or 2 |
| All other registers | `32'h00000000` | Not written |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.12 — `x0_hardwired`

**Functionality:** `x0` must read 0 no matter what writes to it. This attempts a write from every writing instruction type (`addi`, `add`, `sub`, `sll`, `srl`, `lw` from a nonzero memory word) with `rd=0`, and checks immediately after the first attempt that `x0` didn't briefly become 5. It also checks `x0+0` and `x0+x0` right after several attempted writes, to catch a forwarding path that might bypasses the "hardwired to 0" check on read instead of on write.

**Initial state:**

- Registers: All 0.
- Data memory: word 0 = `32'hDEADBEEF` (preloaded, so the `lw x0,...` attempt has a real nonzero value to discard).
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
data = '{32'hDEADBEEF};
preload_dmem(data, 0);

prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(9)),    // x1 = 9
  asm_instr(.op(OP_ADDI), .rd(0), .rs1(0), .imm(5)),    // attempt: x0 = 5
  asm_instr(.op(OP_ADD),  .rd(2), .rs1(0), .rs2(1)),    // x2 = x0 + x1, checked right after the attempt
  asm_instr(.op(OP_ADD),  .rd(0), .rs1(1), .rs2(1)),    // attempt: x0 = 18
  asm_instr(.op(OP_SUB),  .rd(0), .rs1(1), .rs2(0)),    // attempt: x0 = 9 (also reads x0 as a source)
  asm_instr(.op(OP_SLL),  .rd(0), .rs1(1), .rs2(1)),    // attempt: x0 = 9 << 9
  asm_instr(.op(OP_SRL),  .rd(0), .rs1(1), .rs2(1)),    // attempt: x0 = 9 >> 9
  asm_instr(.op(OP_LW),   .rd(0), .rs1(0), .imm(0)),    // attempt: x0 = dmem[0] = 0xDEADBEEF
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(0)),    // x3 = x0 + 0 (immediate path)
  asm_instr(.op(OP_ADD),  .rd(4), .rs1(0), .rs2(0)),    // x4 = x0 + x0 (register path, right after several write attempts)
  EBREAK_WORD
};
run_directed("x0_hardwired", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000009` | 9 |
| `x2` | `32'h00000009` | `x0` still 0 right after the first write attempt: 0+9=9, not 5+9=14 |
| `x3` | `32'h00000000` | `x0` + 0 |
| `x4` | `32'h00000000` | `x0` + `x0`, checked right after five more write attempts including an `lw` of a nonzero word |
| All other registers | `32'h00000000` | Not written; `x0` reads 0 in every readback |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0 in every cycle it's read. Data memory unchanged (the `lw` doesn't write anywhere). No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.13 — `lw_offsets`

**Functionality:** `lw` computes `rs1 + imm` as a byte address and reads the data-memory word at `addr[11:2]`. Word 1 is deliberately never loaded, so it just acts as a decoy so an off-by-one addressing bug by reading the adjacent word doesn't go unnoticed.

**Initial state:**

- Registers: All 0.
- Data memory: words 0–7 = `32'h11111111, 32'h22222222, 32'hDEADBEEF, 32'h80000000, 32'hFFFFFFFF, 32'h00000000, 32'h12345678, 32'hCAFEF00D` (preloaded).
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
data = '{32'h11111111, 32'h22222222, 32'hDEADBEEF, 32'h80000000,
         32'hFFFFFFFF, 32'h00000000, 32'h12345678, 32'hCAFEF00D};
preload_dmem(data, 0);

prog = '{
  asm_instr(.op(OP_LW),   .rd(1), .rs1(0), .imm(0)),    // x1 = dmem[word 0]
  asm_instr(.op(OP_LW),   .rd(2), .rs1(0), .imm(8)),    // x2 = dmem[word 2]
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(16)),   // x3 = 16 (base register, word 4)
  asm_instr(.op(OP_LW),   .rd(4), .rs1(3), .imm(0)),    // x4 = dmem[word 4]
  asm_instr(.op(OP_LW),   .rd(5), .rs1(3), .imm(-4)),   // x5 = dmem[word 3], negative offset
  asm_instr(.op(OP_LW),   .rd(6), .rs1(3), .imm(8)),    // x6 = dmem[word 6], positive offset
  asm_instr(.op(OP_LW),   .rd(7), .rs1(0), .imm(28)),   // x7 = dmem[word 7]
  asm_instr(.op(OP_LW),   .rd(8), .rs1(0), .imm(20)),   // x8 = dmem[word 5] = 0, checks a real zero load
  EBREAK_WORD
};
run_directed("lw_offsets", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h11111111` | Word 0, zero base and offset |
| `x2` | `32'hDEADBEEF` | Word 2 via `0(x0)`; word 1 is never touched, this helps catcch off-by-one |
| `x3` | `32'h00000010` | 16, the base register |
| `x4` | `32'hFFFFFFFF` | Word 4 via `0(x3)` |
| `x5` | `32'h80000000` | Word 3 via `-4(x3)`, negative offset |
| `x6` | `32'h12345678` | Word 6 via `8(x3)`, positive offset |
| `x7` | `32'hCAFEF00D` | Word 7 via `28(x0)` |
| `x8` | `32'h00000000` | Word 5, a genuine zero value |
| All other registers | `32'h00000000` | Not written |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers must match, with `x0` reading 0. Data memory unchanged from preload. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.14 — `sw_offsets`

**Functionality:** `sw` computes `rs1 + imm` as a byte address and writes `rs2` to `addr[11:2]`. Words 3–8 are preloaded and never targeted, so any stray write shows up as a mismatch. The scoreboard also checks these five stores land in the program order.

**Initial state:**

- Registers: All 0.
- Data memory: words 0–10 = `32'hA5A5A5A5` (preloaded sentinel).
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
data = '{11{32'hA5A5A5A5}};
preload_dmem(data, 0);

prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm('h123)),  // x1 = 0x123 (store data)
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(-1)),     // x2 = 0xFFFFFFFF (store data)
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(40)),     // x3 = 40 (base register, word 10)
  asm_instr(.op(OP_SW),   .rs1(0), .rs2(1), .imm(0)),     // dmem[word 0]  = x1
  asm_instr(.op(OP_SW),   .rs1(0), .rs2(2), .imm(4)),     // dmem[word 1]  = x2
  asm_instr(.op(OP_SW),   .rs1(0), .rs2(2), .imm(40)),    // dmem[word 10] = x2, direct immediate addressing
  asm_instr(.op(OP_SW),   .rs1(3), .rs2(1), .imm(-4)),    // dmem[word 9]  = x1, negative offset from x3
  asm_instr(.op(OP_SW),   .rs1(0), .rs2(0), .imm(8)),     // dmem[word 2]  = x0 = 0
  EBREAK_WORD
};
run_directed("sw_offsets", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000123` | Store data value |
| `x2` | `32'hFFFFFFFF` | Store data value |
| `x3` | `32'h00000028` | 40, the base register |
| `dmem[0]` | `32'h00000123` | `sw x1, 0(x0)` |
| `dmem[1]` | `32'hFFFFFFFF` | `sw x2, 4(x0)` |
| `dmem[2]` | `32'h00000000` | `sw x0, 8(x0)`, stores 0 through the hardwired register |
| `dmem[3]`–`dmem[8]` | `32'hA5A5A5A5` | Untouched; this confirms no off-by-one write |
| `dmem[9]` | `32'h00000123` | `sw x1, -4(x3)`, negative offset |
| `dmem[10]` | `32'hFFFFFFFF` | `sw x2, 40(x0)`, direct immediate address |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory and store order match exactly. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.15 — `sw_then_lw_same_word`

**Functionality:** Stores a value, reads it back, increments it based on the loaded value, stores again, and reads back again. This checks that each load sees the most recent store to the same address, not a stale value.

**Initial state:**

- Registers: All 0.
- Data memory: word 3 = `32'hAAAAAAAA` (preloaded, overwritten by the first store).
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
data = '{32'hAAAAAAAA};
preload_dmem(data, 3);

prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(77)),   // x1 = 77 = 0x4D
  asm_instr(.op(OP_SW),   .rs1(0), .rs2(1), .imm(12)),  // dmem[word 3] = 0x4D
  asm_instr(.op(OP_LW),   .rd(2), .rs1(0), .imm(12)),   // x2 = dmem[word 3] = 0x4D
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(2), .imm(1)),    // x2 = 0x4D + 1 = 0x4E
  asm_instr(.op(OP_SW),   .rs1(0), .rs2(2), .imm(12)),  // dmem[word 3] = 0x4E
  asm_instr(.op(OP_LW),   .rd(3), .rs1(0), .imm(12)),   // x3 = dmem[word 3] = 0x4E
  EBREAK_WORD
};
run_directed("sw_then_lw_same_word", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h0000004D` | 77 |
| `x2` | `32'h0000004E` | Loaded 0x4D back, then +1 |
| `x3` | `32'h0000004E` | Loaded back the second store and confirmed that the first store's overwrite of the preload took effect |
| `dmem[3]` | `32'h0000004E` | Final store value |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory and store order match. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.16 — `mem_boundaries`

**Functionality:** Data memory is 1024 words (4 KiB), so therefore word 1023 sits at the top edge of the addressable range and word 511 can be reached by two different `rs1`+`imm` combinations. This will help us confirm that neither boundary is off-by-one and that both address expressions for word 511 go to the same location.

**Initial state:**

- Registers: All 0.
- Data memory: word 1023 = `32'h5A5A5A5A` (preloaded).
- Other setup: `run_directed(..., 2000, 1024)`, we want to make sure that the readback must cover all 1024 words to reach word 1023. A default 16-word readback would miss it entirely.

**Program:**

```systemverilog
data = '{32'h5A5A5A5A};
preload_dmem(data, 1023);

prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(2044)),   // x1 = 2044 = byte address of word 511
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(1), .imm(2044)),   // x2 = 4088
  asm_instr(.op(OP_LW),   .rd(3), .rs1(2), .imm(4)),      // x3 = dmem[word 1023] (4088+4=4092)
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(-1)),     // x4 = 0xFFFFFFFF (new store data)
  asm_instr(.op(OP_SW),   .rs1(2), .rs2(4), .imm(4)),     // dmem[word 1023] = 0xFFFFFFFF
  asm_instr(.op(OP_LW),   .rd(5), .rs1(2), .imm(4)),      // x5 = dmem[word 1023], confirms the store is visible
  asm_instr(.op(OP_ADDI), .rd(6), .rs1(0), .imm('h111)),  // x6 = 0x111 (store data for word 511)
  asm_instr(.op(OP_SW),   .rs1(1), .rs2(6), .imm(0)),     // dmem[word 511] = 0x111, via 0(x1)
  asm_instr(.op(OP_LW),   .rd(7), .rs1(0), .imm(2044)),   // x7 = dmem[word 511], via 2044(x0) -- different address expression
  EBREAK_WORD
};
run_directed("mem_boundaries", prog, 2000, 1024);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h000007FC` | 2044 |
| `x2` | `32'h00000FF8` | 4088 |
| `x3` | `32'h5A5A5A5A` | Preloaded value read back from word 1023 |
| `x5` | `32'hFFFFFFFF` | Value just stored, read back from the same top-boundary word |
| `x7` | `32'h00000111` | Word 511 read via `2044(x0)`, confirming it sees the same word written via `0(x1)` |
| `dmem[1023]` | `32'hFFFFFFFF` | Final stored value at the top boundary |
| `dmem[511]` | `32'h00000111` | Final stored value at the aliased word |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory and store order match. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.17 — `beq_taken_skips`

**Functionality:** With equal operands, `beq` must jump to `pc+imm` and the two instructions in between must never execute.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(5)),   // pc 0:  x1 = 5
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(5)),   // pc 4:  x2 = 5
  asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(2), .imm(12)), // pc 8:  taken, target = 8+12 = 20
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(1)),   // pc 12: must be skipped
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(1)),   // pc 16: must be skipped
  asm_instr(.op(OP_ADDI), .rd(5), .rs1(0), .imm(1)),   // pc 20: branch target
  EBREAK_WORD
};
run_directed("beq_taken_skips", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x3` | `32'h00000000` | Skipped by the taken branch |
| `x4` | `32'h00000000` | Skipped by the taken branch |
| `x5` | `32'h00000001` | Branch target executed |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.18 — `beq_not_taken`

**Functionality:** With unequal operands, `beq` must fall through to `pc+4` rather than jumping. The branch target (`pc+8`) is set up to skip a poison instruction, so that way a stuck-in-place comparator is caught. The second half uses `0x80000000` vs. `0`, which differ only in the MSB, to catch a comparator that only checks the low 31 bits.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(5)),    // x1 = 5
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(6)),    // x2 = 6
  asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(2), .imm(8)),   // not taken (5 != 6)
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(1)),    // x3 = 1, proves fallthrough (would be skipped if incorrectly taken)
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(1)),    // x4 = 1 (base value)
  asm_instr(.op(OP_ADDI), .rd(5), .rs1(0), .imm(31)),   // x5 = 31 (shift amount)
  asm_instr(.op(OP_SLL),  .rd(6), .rs1(4), .rs2(5)),    // x6 = 1 << 31 = 0x80000000
  asm_instr(.op(OP_BEQ),  .rs1(6), .rs2(0), .imm(8)),   // not taken (0x80000000 != 0), MSB-only difference
  asm_instr(.op(OP_ADDI), .rd(7), .rs1(0), .imm(1)),    // x7 = 1, proves fallthrough again
  EBREAK_WORD
};
run_directed("beq_not_taken", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x3` | `32'h00000001` | Fallthrough after a plain unequal comparison |
| `x6` | `32'h80000000` | 1 << 31 |
| `x7` | `32'h00000001` | Fallthrough after comparing values that differ only in the most significan bit|

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.19 — `beq_x0_and_plus4`

**Functionality:** `beq x0,x0,imm` is always taken. At `+4` the target is the same address the CPU would reach by falling through, which catches a bug where a taken branch to the "next" instruction causes it to execute twice (e.g. from a pipeline not squashing correctly). At `+8` it must skip exactly one instruction.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_BEQ),  .rs1(0), .rs2(0), .imm(4)),   // pc 0: taken, target = 0+4 = 4
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1)),    // pc 4: x1 = 0 + 1 (must execute exactly once)
  asm_instr(.op(OP_BEQ),  .rs1(0), .rs2(0), .imm(8)),   // pc 8: taken, target = 8+8 = 16
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)),    // pc 12: must be skipped
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(3)),    // pc 16: branch target
  EBREAK_WORD
};
run_directed("beq_x0_and_plus4", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000001` | Incremented exactly once, and makes sure not twice, by the degenerate `+4` branch |
| `x2` | `32'h00000000` | Skipped by the `+8` branch |
| `x3` | `32'h00000003` | Branch target |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.20 — `beq_backward_loop`

**Functionality:** A 5-iteration counted loop: the body increments an accumulator by 3 and decrements a counter, then a forward `beq` exits when the counter hits 0, and findally a backward `beq x0,x0` jumps back to the top otherwise. This is the only test with a negative branch immediate so it has to be robust.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(5)),    // pc 0:  x1 = 5 (counter)
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(0)),    // pc 4:  x2 = 0 (accumulator)
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(2), .imm(3)),    // pc 8:  LOOP: x2 += 3
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(-1)),   // pc 12: x1 -= 1
  asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(0), .imm(8)),   // pc 16: if x1==0, exit (target = 16+8 = 24)
  asm_instr(.op(OP_BEQ),  .rs1(0), .rs2(0), .imm(-12)), // pc 20: else loop back (target = 20-12 = 8)
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(1)),    // pc 24: EXIT: x4 = 1
  EBREAK_WORD
};
run_directed("beq_backward_loop", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000000` | Counter decremented 5 times: 5→4→3→2→1→0 |
| `x2` | `32'h0000000F` | Accumulator incremented by 3 five times: 15 = 0xF |
| `x4` | `32'h00000001` | Reached only via the moving forward exit branch |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.21 — `beq_over_ebreak`

**Functionality:** Places a raw `EBREAK_WORD` directly in the instruction stream where a taken branch jumps over it. A CPU that fetches speculatively and doesn't appropriately flush on a taken branch could accidentally retire that `ebreak` and halt one instruction early. In that case `x2` would never be written.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),   // pc 0:  x1 = 1
  asm_instr(.op(OP_BEQ),  .rs1(0), .rs2(0), .imm(8)),   // pc 4:  taken, target = 4+8 = 12
  EBREAK_WORD,                                          // pc 8:  must never retire
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(2)),    // pc 12: branch target, x2 = 2
  EBREAK_WORD                                            // pc 16: real halt
};
run_directed("beq_over_ebreak", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000001` | just a sanity marker before the branch |
| `x2` | `32'h00000002` | this is only reachable if the skipped `ebreak` never retired |

**Pass criteria:** Halts on the second `ebreak` (pc 16) before the timeout, not the first (pc 8). All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.22 — `raw_alu_distances`

**Functionality:** `x1` is read by three later `addi`s at increasing distance from the instruction that wrote it. First is immediately after, then two instructions later, then three instructions later. This covers any pipeline-forwarding path that only handles the shortest distance correctly.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(10)),   // x1 = 10
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(1), .imm(1)),    // x2 = x1 + 1, distance 1
  asm_instr(.op(OP_ADDI), .rd(7), .rs1(0), .imm(100)),  // filler, independent of x1
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(1), .imm(2)),    // x3 = x1 + 2, distance 2
  asm_instr(.op(OP_ADDI), .rd(8), .rs1(0), .imm(200)),  // filler
  asm_instr(.op(OP_ADDI), .rd(9), .rs1(0), .imm(300)),  // filler
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(1), .imm(3)),    // x4 = x1 + 3, distance 3
  asm_instr(.op(OP_ADD),  .rd(5), .rs1(3), .rs2(2)),    // x5 = x3 + x2
  asm_instr(.op(OP_SUB),  .rd(6), .rs1(5), .rs2(4)),    // x6 = x5 - x4
  EBREAK_WORD
};
run_directed("raw_alu_distances", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x2` | `32'h0000000B` | 10 + 1, distance-1 read of `x1` |
| `x3` | `32'h0000000C` | 10 + 2, distance-2 read of `x1` |
| `x4` | `32'h0000000D` | 10 + 3, distance-3 read of `x1` |
| `x5` | `32'h00000017` | 12 + 11 = 23 |
| `x6` | `32'h0000000A` | 23 − 13 = 10 |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.23 — `load_use_hazards`

**Functionality:** A `lw` result is often needed immediately by the next instruction, which is the hazard most likely to need a pipeline stall or extra forwarding path. This exercises that immediate consumption in five different operand roles, but back to back.

**Initial state:**

- Registers: All 0.
- Data memory: words 0–8 = `32'd10, 32'd3, 32'h0, 32'h0, 32'h0BADF00D, 32'h0, 32'h0, 32'h0, 32'hFFFFFFFF` (preloaded).
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
data = '{32'd10, 32'd3, 32'h0, 32'h0, 32'h0BADF00D, 32'h0, 32'h0, 32'h0, 32'hFFFFFFFF};
preload_dmem(data, 0);

prog = '{
  asm_instr(.op(OP_LW),   .rd(1), .rs1(0), .imm(0)),    // x1 = dmem[0] = 10
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(1), .imm(10)),   // load-use as ALU data: x2 = x1 + 10 = 20
  asm_instr(.op(OP_LW),   .rd(3), .rs1(0), .imm(4)),    // x3 = dmem[1] = 3
  asm_instr(.op(OP_SLL),  .rd(4), .rs1(2), .rs2(3)),    // load-use as shift amount: x4 = x2 << x3 = 20 << 3
  asm_instr(.op(OP_LW),   .rd(6), .rs1(0), .imm(16)),   // x6 = dmem[4] = 0x0BADF00D
  asm_instr(.op(OP_LW),   .rd(7), .rs1(6), .imm(0)),    // load-use as lw base: reads whatever word x6 (a huge address) aliases to
  asm_instr(.op(OP_SW),   .rs1(0), .rs2(6), .imm(32)),  // load-use as sw data: dmem[8] = x6 = 0x0BADF00D
  asm_instr(.op(OP_LW),   .rd(9), .rs1(0), .imm(20)),   // x9 = dmem[5] = 0
  asm_instr(.op(OP_BEQ),  .rs1(9), .rs2(0), .imm(8)),   // load-use as branch operand: taken (0 == x0)
  asm_instr(.op(OP_ADDI), .rd(8), .rs1(0), .imm(99)),   // must be skipped
  asm_instr(.op(OP_ADDI), .rd(8), .rs1(0), .imm(0)),    // branch target: x8 = 0
  EBREAK_WORD
};
run_directed("load_use_hazards", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h0000000A` | Loaded value, this is used by the very next instruction |
| `x2` | `32'h00000014` | 10 + 10 = 20, load-use as ALU add data |
| `x3` | `32'h00000003` | Loaded value, immediately used by the very next instruction |
| `x4` | `32'h000000A0` | 20 << 3 = 160, load-use as shift amount |
| `x6` | `32'h0BADF00D` | Loaded value, immediately reused as a base address next |
| `x7` | `32'h00000000` | Load-use as `lw` base register: 0x0BADF00D has `addr[11:2]` = 3, so this reads word 3, which is 0. A stale base (x6 = 0) would read word 0 = 10 instead |
| `dmem[8]` | `32'h0BADF00D` | Load-use as `sw` data, overwriting the preloaded `0xFFFFFFFF` |
| `x9` | `32'h00000000` | Loaded value |
| `x8` | `32'h00000000` | Reached via the branch target, the load-use as `beq` operand caused the branch to be correctly taken |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory and store order match. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.24 — `store_operand_hazards`

**Functionality:** Unlike a load-use hazard, this is about an ALU write feeding directly into a store's address or data operand on the very next cycle. This is a separate forwarding path from the load-use case in 1.23.

**Initial state:**

- Registers: All 0.
- Data memory: None (words 5–7 start unwritten/randomized; only the specific stores below are checked).
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(20)),   // x1 = 20 (base, word 5)
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(99)),   // x2 = 99 = 0x63
  asm_instr(.op(OP_SW),   .rs1(1), .rs2(2), .imm(0)),   // dmem[word 5] = x2; both operands just written
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(2), .imm(1)),    // x2 = 100 = 0x64
  asm_instr(.op(OP_SW),   .rs1(1), .rs2(2), .imm(4)),   // dmem[word 6] = x2; data operand just written
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(8)),    // x1 = 28
  asm_instr(.op(OP_SW),   .rs1(1), .rs2(2), .imm(0)),   // dmem[word 7] = x2; base operand just written
  EBREAK_WORD
};
run_directed("store_operand_hazards", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h0000001C` | 28 |
| `x2` | `32'h00000064` | 100 |
| `dmem[5]` | `32'h00000063` | Stored with `rs1` and `rs2` both written the cycle before, testing if the sequential is correc |
| `dmem[6]` | `32'h00000064` | Stored with the data operand written the cycle before |
| `dmem[7]` | `32'h00000064` | Stored with the base operand written just the cycle before |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory and store order match. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.25 — `branch_operand_hazard`

**Functionality:** Both operands of the first `beq` are written the instruction directly before it; a `beq` right after that (with one operand rewritten again) checks the same hazard on the not-taken path.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(3)),    // pc 0:  x1 = 3
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(3)),    // pc 4:  x2 = 3
  asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(2), .imm(8)),   // pc 8:  taken (3==3), target = 8+8 = 16
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(1)),    // pc 12: must be skipped
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(4)),    // pc 16: x1 = 4, rewritten immediately before the next beq
  asm_instr(.op(OP_BEQ),  .rs1(1), .rs2(2), .imm(8)),   // pc 20: not taken (4 != 3)
  asm_instr(.op(OP_ADDI), .rd(4), .rs1(0), .imm(1)),    // pc 24: x4 = 1, proves fallthrough
  EBREAK_WORD
};
run_directed("branch_operand_hazard", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x3` | `32'h00000000` | Skipped by the taken branch, whose operands were both written the instruction before |
| `x4` | `32'h00000001` | Fallthrough of the not-taken branch, whose `rs1` was rewritten the instruction before |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.26 — `unsupported_encodings_nop`

**Functionality:** Injects five raw instruction words the CPU must not implement (`xor`, `sra`, an all-zero word, `slti`, `lui`) directly into the program. None may write any register and the CPU must resume normal fetch/decode immediately after. Thus we use a real `add` right after them.

**Initial state:**

- Registers: All 0.
- Data memory: None.
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(6)),   // x1 = 6
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(1)),   // x2 = 1
  32'h0020C1B3,  // xor x3, x1, x2   -- unsupported funct3/funct7, must be a no-op
  32'h4020D233,  // sra x4, x1, x2   -- unsupported funct7, must be a no-op
  32'h00000000,  // reserved/all-zero word -- must be a no-op
  32'h0070A293,  // slti x5, x1, 7   -- unsupported funct3, must be a no-op
  32'h12345337,  // lui x6, 0x12345  -- unsupported opcode, must be a no-op
  asm_instr(.op(OP_ADD), .rd(7), .rs1(1), .rs2(2)),    // x7 = x1 + x2, proves normal execution resumed
  EBREAK_WORD
};
run_directed("unsupported_encodings_nop", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x3` | `32'h00000000` | `xor`- word must not write a register |
| `x4` | `32'h00000000` | `sra`-shaped word must not write a register |
| `x5` | `32'h00000000` | `slti`-shaped word must not write a register |
| `x6` | `32'h00000000` | `lui`-instruction word must not write a register |
| `x7` | `32'h00000007` | 6 + 1 = 7; confirms the pc advanced correctly through all five no-ops and that the decode wasn't corrupted |

**Pass criteria:** Halts on `ebreak` before the timeout. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.27 — `ebreak_stops_execution`

**Functionality:** Places live instructions and a store after the `ebreak`. Since `run_directed` reads back data memory, an unchanged sentinel word directly proves the trailing `sw` never ran, not just that the register file looks right.

**Initial state:**

- Registers: All 0.
- Data memory: word 0 = `32'hA5A5A5A5` (preloaded sentinel).
- Other setup: `run_directed` defaults.

**Program:**

```systemverilog
data = '{32'hA5A5A5A5};
preload_dmem(data, 0);

prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(1)),   // x1 = 1
  EBREAK_WORD,                                          // halts here
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(2)),    // dead code, shouldn't execute
  asm_instr(.op(OP_SW),   .rs1(0), .rs2(2), .imm(0))    // dead code, must never execute
};
run_directed("ebreak_stops_execution", prog);
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000001` | Executed before the `ebreak` |
| `x2` | `32'h00000000` | Never written; the `addi` after `ebreak` never executed |
| `dmem[0]` | `32'hA5A5A5A5` | Unchanged sentinel, this will prove that the trailing `sw` never executed |

**Pass criteria:** Halts on `ebreak` before the timeout, after exactly 2 retired instructions. All 32 registers match, with `x0` reading 0. Data memory unchanged. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.28 — `restart_after_reset`

**Functionality:** Runs one program that writes `x1` and `x2`, then a second, unrelated program that only writes `x3`. Since `run_directed` resets before loading each program, `x1` and `x2` must read back 0 after the second run. This proves that the reset actually clears the register file rather than just the pc.

**Initial state:**

- Registers: All 0 (reset by each `run_directed` call).
- Data memory: None.
- Other setup: `run_directed` defaults, called twice.

**Program:**

```systemverilog
prog = '{
  asm_instr(.op(OP_ADDI), .rd(1), .rs1(0), .imm(11)),  // x1 = 11
  asm_instr(.op(OP_ADDI), .rd(2), .rs1(0), .imm(22)),  // x2 = 22
  EBREAK_WORD
};
run_directed("restart_after_reset_progA", prog);

prog = '{
  asm_instr(.op(OP_ADDI), .rd(3), .rs1(0), .imm(3)),   // x3 = 3
  EBREAK_WORD
};
run_directed("restart_after_reset_progB", prog);
```

**Expected result (after program B):**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| `x1` | `32'h00000000` | Reset before program B, despite being 11 after program A |
| `x2` | `32'h00000000` | Reset before program B, despite being 22 after program A |
| `x3` | `32'h00000003` | Written by program B |

**Pass criteria:** Both programs halt on `ebreak` before the timeout. After program B, all 32 registers match, with `x0` reading 0. No scoreboard, monitor, or assertion errors.

**Final result:** Pending.

### 1.29 — `external_port_windows`

**Functionality:** Exercises the testbench's external xbar port itself, independent of the CPU. It will write and read back the first and last words of ISRAM and DSRAM. This will confirm the read-only register window reads all zero right after reset (since the CPU never runs, this also confirms the register file's reset value without depending on CPU execution).

**Initial state:**

- Registers: All 0 (reset, CPU never started).
- Data memory / instruction memory: Written directly through the external port by this test.
- Other setup: No `run_directed` call; uses `seqr.send_write_trans` / `readback` directly, followed by `init_memories()` to restore known state for later tests.

**Program:**

```systemverilog
drv.reset_task();
seqr.send_write_trans(word_addr(ISRAM_BASE, 0),    32'hAAAA5555);
seqr.send_write_trans(word_addr(ISRAM_BASE, 1023), 32'h5555AAAA);
seqr.send_write_trans(word_addr(DSRAM_BASE, 0),    32'h11112222);
seqr.send_write_trans(word_addr(DSRAM_BASE, 1023), 32'h33334444);
seqr.wait_for_empty();

readback(0, 1, 0);      // ISRAM word 0
readback(0, 1, 1023);   // ISRAM word 1023
readback(1, 1, 0);      // DSRAM word 0
readback(1, 1, 1023);   // DSRAM word 1023
readback(2, 32);        // full register window

init_memories();        // restore known memory state before the next test
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| ISRAM word 0 | `32'hAAAA5555` | External write read back directly |
| ISRAM word 1023 | `32'h5555AAAA` | External write read back at the top of the ISRAM window |
| DSRAM word 0 | `32'h11112222` | External write read back directly |
| DSRAM word 1023 | `32'h33334444` | External write read back at the top of the DSRAM window |
| Register window, all 32 words | `32'h00000000` | Register file after reset, this should be observed without ever starting the CPU |

**Pass criteria:** All external reads return the values just written, with no CPU involvement. The register window reads all zero. No scoreboard, monitor, or assertion errors. (No `ebreak`/timeout check applies — the CPU never runs in this test.)

**Final result:** Pending.

### 1.30 — `external_halt_recovery`

**Functionality:** Starts a 32-instruction counting loop, lets it run for exactly 12 cycles, then halts it externally mid-execution and resets. Register state is not checked (halting at an arbitrary cycle makes the exact count non-deterministic to hand-verify); instead this checks that the instruction memory image, which which `halt_cpu_now` and the external port must not disturb. Therefore we can tell if this reads back intact.

**Initial state:**

- Registers: Not checked.
- Instruction memory: Loaded with 32 copies of `addi x1,x1,1` (`32'h00108093`) followed by `EBREAK_WORD`.
- Other setup: Manual `drv`/`seqr` control (not `run_directed`), mirroring `run_external_halt_smoke()` in cpu_tb_top.sv.

**Program:**

```systemverilog
logic [31:0] halt_prog [$];
for (int i = 0; i < 32; i++) begin
  halt_prog.push_back(asm_instr(.op(OP_ADDI), .rd(1), .rs1(1), .imm(1)));  // 0x00108093
end
halt_prog.push_back(EBREAK_WORD);

drv.reset_task();
seqr.load_program(halt_prog);
seqr.wait_for_empty();
repeat (2) @(cpu_if.cb);
drv.start_cpu();
repeat (12) @(cpu_if.cb);
drv.halt_cpu_now();
readback(0, 33);        // read back the full 33-word instruction image
drv.reset_task();
```

**Expected result:**

| Register or memory word | Expected value | Calculation or explanation |
| --- | --- | --- |
| ISRAM words 0–31 | `32'h00108093` | Unchanged `addi x1,x1,1` encoding; `halt_cpu_now` must not corrupt the instruction memory |
| ISRAM word 32 | `32'h00100073` | `EBREAK_WORD`, unchanged |

**Pass criteria:** The CPU is confirmed halted (not running) after `halt_cpu_now`. Instruction memory reads back byte-for-byte identical to what was loaded. The subsequent `reset_task()` completes without error. No scoreboard, monitor, or assertion errors. (Registers are intentionally not checked.)

**Final result:** Pending.


## 2. Constrained-random tests

The directed tests in section 1 each check one behavior. The random tests look for bugs that only show up when legal instructions interact: back-to-back hazards between random pairs of instructions, loads and stores to any data word, taken and not-taken branches in the middle of dependency chains, and uncommon data values. Expected results come from the supplied reference model (for CPU programs) and the scoreboard's shadow memories (for external-port traffic). No expected values are written by hand, so every random program is checked the same way the directed tests are.

### Instruction constraints

<!--
Explain the provided constraints, then record how the partial and open
constraints are completed. State what each constraint permits, excludes, or
biases and why the resulting programs remain useful and terminating.
-->

| Constraint | Provided, partial, or open | Behavior and purpose | Final implementation summary |
| --- | --- | --- | --- |
| `c_opcode` | Provided | Membership (`inside`) constraint limiting `op` to the 8 supported instructions. `OP_NOP` and `OP_EBREAK` are excluded, so a random program can't halt early (the sequencer appends the only `ebreak`) and never generates an unsupported encoding. Unsupported encodings are covered by directed test 1.26. | No member change |
| `c_reg_bias` | Provided | Weighted `dist` on `rd`/`rs1`/`rs2`. About 70% of picks fall in x1–x7, so therefore a random instruction usually reads a register written a few instructions earlier, which gives way more RAW/WAW hazards at distances 1–3. `x0` gets 5% as `rd` (write-discard) and 10% as a source (hardwired zero), and x8–x31 stay reachable so every register-file entry is still exercised. | No member change |
| `c_imm_range` | Partial | Currently gives only a lower bound (`imm >= -2048`), so the solver could pick immediates that don't fit the 12-bit I/S field and get truncated by `encode()`. The log would then show `addi x1, x0, 5000` while the CPU actually ran a different value. | We must add the upper bound `imm <= 2047`, and then also the bias `addi` toward the sign-extension corners: `(op == OP_ADDI) -> imm dist { -2048 :/ 5, -1 :/ 5, 0 :/ 5, 1 :/ 5, 2047 :/ 5, [-2047:2046] :/ 75 }`. |
| `c_mem_align` | Open | `lw`/`sw` offsets must be word-aligned. Because DSRAM is 1024 words and both the CPU and the reference model index it with `addr[11:2]`, any 32-bit `rs1 + imm` lands on a real word (it wraps), so random base registers can't leave data memory. The bias toward `rs1 = x0` makes the target address known at generation time and spreads accesses across all 1024 words. The rest use a live base register. This will exercise forwarding into address generation. | `(op inside {OP_LW, OP_SW}) -> (imm % 4 == 0)`, plus `(op inside {OP_LW, OP_SW}) -> rs1 dist { 0 :/ 50, [1:31] :/ 50 }`. |
| `c_imm_unused` | Provided | Implication constraint: R-type ops (`add`/`sub`/`sll`/`srl`) have no immediate field, so `imm` is forced to 0. That keeps the printed assembly consistent with the encoded word and stops the solver wasting randomness on a field that is ignored. | No member change |
| `c_branch_target` | Partial | Currently only requires a forward, word-aligned offset. Nothing stops a branch from jumping past the appended `ebreak` into leftover memory. This avoids stale instructions from earlier programs. This would make the result depend on history rather than on this program. | Also bound the target to at most the `ebreak` slot: `(op == OP_BEQ) -> (imm <= (prog_len - 1 - idx) * 4)`. Forward-only plus in-bounds guarantees termination in at most `prog_len` retired instructions. The last random slot is forced to `imm == 4` (branch to the `ebreak`). |
| `c_no_branch_at_end` | Provided | Implication on `idx`/`prog_len` meant to keep a branch out of the final slot, where there is no legal forward target. As written, `prog_len - idx < 2` is never true for a given slot (`idx` stops at `prog_len - 2`). Therefore the last random slot can still be a `beq`. The `c_branch_target` upper bound handles it by forcing `imm == 4` (branch straight to the `ebreak`). | No member change |
| `c_branch_taken_bias` | Open | With 32 registers, random `rs1`/`rs2` would almost never be equal at runtime, so nearly every `beq` would fall through and the taken path would barely be tested. | Add helper `rand bit force_taken;` with `force_taken dist {1 :/ 50, 0 :/ 50}` and `(op == OP_BEQ && force_taken) -> (rs1 == rs2)`. That gives about 50% guaranteed-taken branches, including `beq x0,x0`. The other 50% are still random pairs, which occasionally compare equal at runtime because the registers all start at 0. |

**Legal behavior these constraints make unreachable (covered elsewhere):**

- Backward branches and loops: excluded by `c_branch_target` so programs always terminate. Covered by the directed test 1.20.
- Misaligned immediate offsets on `lw`/`sw`: excluded by `c_mem_align`. A runtime `rs1` with nonzero low bits can still happen. Both the DUT and the reference model drop `addr[1:0]`, so this is checked but not ultimately targeted.
- Unsupported encodings and early `ebreak`: excluded by `c_opcode`. Covered by directed tests 1.26, 1.27, and 1.21.

### External-port constraints

| Constraint | Provided, partial, or open | Behavior and purpose | Final implementation summary |
| --- | --- | --- | --- |
| `c_align` | Provided | Bit constraint `addr[1:0] == 0`. The port only accepts word-aligned accesses. Therefore every request targets a whole word. | No member change |
| `c_valid_window` | Partial | Excludes the unmapped window (`2'b11`). ISRAM and DSRAM are 1024 words each, so `addr[11:2]` covers them exactly. The register window has only 32 words, and the current constraint still allows reads of word indices 32–1023 there, which don't exist at all | Add `(addr[13:12] == 2'b10) -> (addr[11:7] == 0)` so register-window reads stay within `x0`–`x31`.  |
| `c_reg_read_only` | Provided | Implication is that any access to the register window must be a read, because the register file isn't writable from the port. | No member change |
| `c_data_corners` | Open | Uniform 32-bit data almost never produces boundary patterns. Weighting a few special classes checks that every bit lane of the SRAM, the port data path, and the scoreboard compare can hold 0 and 1 without dropping ordinary values. | `data dist { 32'h00000000 :/ 5, 32'hFFFFFFFF :/ 5, 32'h80000000 :/ 5, 32'h7FFFFFFF :/ 5, 32'h00000001 :/ 5, 32'hAAAAAAAA :/ 5, 32'h55555555 :/ 5, [32'h0:32'hFFFFFFFF] :/ 65 }`. The classes are: all-zeros or all-ones, MSB-only and INT_MAX (sign-bit boundary), LSB-only (bit 0), and alternating patterns (adjacent-bit shorts and swapped bit lanes). |

### Random-program test

| Item | Plan |
| --- | --- |
| Number of programs per seed | 20 by default (`NUM_RANDOM_PROGRAMS`). Raised with `+NUM_RANDOM_PROGRAMS=200` for bug-hunt seeds. |
| Program-length range | 1–40 random instructions plus the appended `ebreak`, chosen per program with `$urandom_range(1, 40)` so it is reproducible from the seed. Short programs isolate failures while the long ones build deeper dependency chains. |
| External-port traffic | `NUM_RANDOM_XBAR` (300) random `cpu_xbar_item` reads/writes with the CPU idle, after the CPU programs, checked against the scoreboard memories. |
| Timeout | `run_directed` default of 2000 cycles. Forward-only branches cap retired instructions at `len + 1`, so reaching the timeout means a DUT hang, not a legally long program that just didn't fit within the 2,000 cycles |
| Expected results | Reference model predicts all 32 registers and the ordered store list. The full 1024-word DSRAM is read back, because `c_mem_align` lets stores land anywhere. |
| Information logged for reproduction | Numeric `SVSEED`, iteration and length in the test name (`random_prog_<i>_len<n>`), and the complete generated program (`gen_program` prints every instruction with its encoding). |

**Implementation outline:**

```systemverilog
// CONSTRAINED-RANDOM TESTS
drv.reset_task();
init_memories();   // ISRAM = all ebreak, DSRAM = $urandom data for loads to read

for (int i = 0; i < NUM_RANDOM_PROGRAMS; i++) begin
  int    len;
  string name;

  len  = $urandom_range(1, 40);
  name = $sformatf("random_prog_%0d_len%0d", i, len);
  $display("");
  $display(" TEST: %s", name);
  sb.set_test(name);

  drv.reset_task();              // clear registers between programs
  seqr.gen_program(len);         // randomize + print + stage ISRAM writes, then we append ebreak
  seqr.wait_for_empty();
  repeat (2) @(cpu_if.cb);
  drv.run_program(2000);

  if (drv.last_run_completed) begin
    readback(2, REG_COUNT);      // all 32 registers vs. reference model
    readback(1, DSRAM_WORDS);    // all of DSRAM, since random stores can hit any word
  end else begin
    $display($stime, " TB: Skipping %s readback after CPU timeout\n", name);
    drv.reset_task();
  end
end

// Random external-port traffic, CPU idle
sb.set_test("random_xbar");
drv.reset_task();
seqr.gen_xbar(NUM_RANDOM_XBAR, 1'b1);
seqr.wait_for_empty();
repeat (4) @(cpu_if.cb);
```

**Pass criteria:** Every random program halts before its timeout, all 32 registers and all DSRAM words match the reference model, and especially that the CPU stores match the predicted order. Every random external read matches the scoreboard shadow. No scoreboard, monitor, or assertion errors across all iterations.

**Failure handling:** For a failing iteration, record the `SVSEED` and iteration, copy the printed program into a `prog = '{...}` block, and reduce it by deleting instructions until the smallest sequence that still fails remains. That reduced program will become a new directed test in `testplan_final.md`.

**Final result:** Pending.

## 3. Assertions

<!--
Plan at least two assertions in addition to the supplied example. Write the
timing rule in English first. In the final plan, include the exact SVA and
evidence from a temporary violation proving that the assertion can fire.
-->

All assertions are placed next to the supplied `NO_SIMULTANEOUS_READ_WRITE` in `cpu_tb_top.sv`. They sample on `posedge clk`, are disabled during reset (`disable iff (rst)`), and report through `assertion_fail()`, so any failure is added to `assertion_errors` and fails the final result. Unlike the scoreboard, they check timing every cycle, no matter which test is running.

### Assertion summary

| Assertion ID/name | Behavior checked | When it is sampled/disabled | Activating test |
| --- | --- | --- | --- |
| 3.1 / `SRAM_READ_RESPONDS_NEXT_CYCLE` | A pending instruction or data-SRAM read gets `rready` exactly one cycle later | Every `posedge clk`; disabled in reset; only while the CPU is idle | Every `readback(0/1, ...)`, 1.29, random external-port traffic |
| 3.2 / `REG_READ_RESPONDS_SAME_CYCLE` | A register-window read gets `rready` in the same cycle | Every `posedge clk`; disabled in reset; only while the CPU is idle | Every `readback(2, 32)` after each program |
| 3.3 / `HALT_IS_SINGLE_PULSE` | `cpu_halted` is high for exactly one cycle per `ebreak` | Every `posedge clk`; disabled in reset | Every program that reaches `ebreak` |
| 3.4 / `NO_PORT_ACCESS_WHILE_CPU_ACTIVE` | The testbench never drives `w_en`/`r_en` while the CPU currently owns the memories | Every `posedge clk`; disabled in reset | Every test (checks the driver) |
| 3.5 / `CPU_STORE_NO_X` | Every CPU store to data SRAM has a known address and known data (no X/Z) | Every `posedge clk`; disabled in reset; only while the CPU is active | 1.14–1.16, 1.23, 1.24, every random program with an `sw` |

### 3.1 — `SRAM_READ_RESPONDS_NEXT_CYCLE`

**Timing requirement in words:** When the CPU is idle and `r_en` is high for an instruction- or data-SRAM address (`addr[13:12]` is `00` or `01`) and `rready` isn't high yet, `rready` must be high on the next clock edge. The `!rready` term means the check fires once per request, not again on the cycle where the response arrives while `r_en` is still held.

```systemverilog
SRAM_READ_RESPONDS_NEXT_CYCLE:
  assert property (@(posedge clk) disable iff (rst)
    (cpu_if.r_en && !cpu_if.rready && !cpu_if.cpu_active &&
     cpu_if.addr[13:12] inside {2'b00, 2'b01})
    |=> cpu_if.rready)
  else assertion_fail("SRAM read did not return rready on the following cycle");
```

**Evidence that it detects a violation:** Temporarily add `initial begin wait (cpu_if.r_en && !cpu_if.addr[13]); force cpu_if.rready = 1'b0; #50; release cpu_if.rready; end` to `cpu_tb_top.sv`. We expect the assertion message in `simulation.log` and a waveform showing `r_en` high with no `rready` on the next edge. We will then remove the force and confirm the log is clean.

### 3.2 — `REG_READ_RESPONDS_SAME_CYCLE`

**Timing requirement in words:** When the CPU is idle and `r_en` is high for a register-window address (`addr[13:12] == 2'b10`), `rready` must be high in that same cycle. The register window answers combinationally, unlike the SRAMs.

```systemverilog
REG_READ_RESPONDS_SAME_CYCLE:
  assert property (@(posedge clk) disable iff (rst)
    (cpu_if.r_en && !cpu_if.cpu_active && cpu_if.addr[13:12] == 2'b10)
    |-> cpu_if.rready)
  else assertion_fail("register-window read did not return rready in the request cycle");
```

**Evidence that it detects a violation:** Temporarily force `cpu_if.rready = 1'b0` during the first register-window `readback`. We expect that the assertion to fire on that request cycle. Then release it and confirm the log is clean.

### 3.3 — `HALT_IS_SINGLE_PULSE`

**Timing requirement in words:** `cpu_halted` is a one-cycle pulse when `ebreak` retires. If it is high on one clock edge, it must be low on the next. A CPU that keeps the halt signal high, or pulses it twice, would then make the monitor count extra halts, which is bad.

```systemverilog
HALT_IS_SINGLE_PULSE:
  assert property (@(posedge clk) disable iff (rst)
    cpu_if.cpu_halted |=> !cpu_if.cpu_halted)
  else assertion_fail("cpu_halted stayed high for more than one cycle");
```

**Evidence that it detects a violation:** Temporarily add `initial begin wait (cpu_if.cpu_halted); force cpu_if.cpu_halted = 1'b1; repeat (3) @(posedge clk); release cpu_if.cpu_halted; end`. We would expect the assertion to fire on the cycle after the real pulse. Remove it and confirm the log is clean.

### 3.4 — `NO_PORT_ACCESS_WHILE_CPU_ACTIVE`

**Timing requirement in words:** The external port only works while the CPU is disabled. While `cpu_active` is high, the testbench must not assert `w_en` or `r_en`. This checks the driver, where a request sent while the CPU runs would be ignored by the DUT, and therefore the scoreboard would then report a false mismatch.

```systemverilog
NO_PORT_ACCESS_WHILE_CPU_ACTIVE:
  assert property (@(posedge clk) disable iff (rst)
    cpu_if.cpu_active |-> !(cpu_if.w_en || cpu_if.r_en))
  else assertion_fail("external port was driven while the CPU owned the memories");
```

**Evidence that it detects a violation:** Temporarily call `seqr.send_read_trans(word_addr(REG_BASE, 1))` right after `drv.start_cpu()` in `run_external_halt_smoke()` (before `halt_cpu_now`). Expect the assertion to fire while `cpu_active` is high. Revert and confirm the log is clean.

### 3.5 — `CPU_STORE_NO_X`

**Timing requirement in words:** Whenever the CPU is active and writing data SRAM (`dsram_en && dsram_write_en`), the word address and write data must be fully known (no X or Z bits) in that cycle. A store of an uninitialized register, or a store whose operand comes from a broken forwarding path, can put X into memory. The scoreboard might not catch that clearly, because an X compared against an expected value can either pass silently or give a confusing mismatch much later, when the word is loaded. This assertion flags it in the cycle the store happens.

```systemverilog
CPU_STORE_NO_X:
  assert property (@(posedge clk) disable iff (rst)
    (cpu_if.cpu_active && cpu_if.dsram_en && cpu_if.dsram_write_en)
    |-> !$isunknown({cpu_if.dsram_addr, cpu_if.dsram_wdata}))
  else assertion_fail($sformatf("CPU store with unknown addr/data: addr=%0h data=%0h",
                                cpu_if.dsram_addr, cpu_if.dsram_wdata));
```

**Evidence that it detects a violation:** Temporarily add `initial begin wait (cpu_if.cpu_active && cpu_if.dsram_write_en); force dut.dsram_wdata = 'x; @(posedge clk); release dut.dsram_wdata; end` so the first CPU store (from 1.14) carries X data. Expect the assertion message with `data=x` in `simulation.log`. WE can then remove it and confirm the log is clean.


## 4. Encrypted CPU Bug Hunt

This will be filled out in the final report but it isn't in the initial test plan.

### Random discovery

| Field                    | Evidence                      |
| ------------------------ | ----------------------------- |
| Discovery command        | `make bug_hunt SEED=random`   |
| Numeric `SVSEED`         |                               |
| Failing iteration        |                               |
| First failure message    |                               |
| Reproduction command     | `make bug_hunt SEED=________` |
| Reproduces consistently? | Yes / No                      |

**Original failing program:**

```systemverilog
prog = '{
  // Paste original generated sequence
  EBREAK_WORD
};
```

### Expected vs. actual

| Instruction / event | Expected | Actual | Cycle/time |
| ------------------- | -------- | ------ | ---------- |
|                     |          |        |            |

**First architectural divergence:**

<!-- State the first register, memory, or control-flow result that becomes incorrect. -->

### Minimization

**Minimized reproducer:**

```systemverilog
prog = '{
  // Smallest sequence that still fails
  EBREAK_WORD
};
```

### Waveform evidence

Include a screenshot showing the offending instruction and the first incorrect architectural result.

### Conclusion

**Trigger:**

<!-- Smallest condition that causes the failure. -->

**Expected behavior:**

<!-- ISA-correct behavior. -->

**Observed behavior:**

<!-- What the encrypted CPU does instead. -->

**Behavioral characterization:**

<!-- One precise sentence. Do not speculate about hidden RTL. -->

