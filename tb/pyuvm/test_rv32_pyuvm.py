"""pyuvm testbench for my RV32I onboarding core (UVM in Python, run by cocotb).

Talks to chip_top only through its external ports, the same contract the
SystemVerilog onboarding testbench uses:

    addr_i[13:12] = 00 instruction SRAM | 01 data SRAM | 10 register file (read only)
    writes: addr/wdata/w_en captured on the next rising edge
    reads:  hold addr/r_en until rready (SRAM: next cycle, regfile: same cycle)
    en_cpu_i pulse starts the program at PC 0, cpu_halted_o pulses on ebreak
    the external port is only serviced while the CPU is disabled

Structure (standard UVM roles):

  ProgramSeq -> Sequencer -> Driver --pins--> chip_top
                               |                  |
                   "expected"  |                  | pins (passive)
                               v                  v
                          Scoreboard <-- "actual" -- Monitor
                               |
                               +-- RV32Model (rv32_golden.py) predicts every
                                   register and data word for the program

The driver owns every DUT input (load program, start, read state back).
The monitor only watches pins and rebuilds what actually happened, so a
broken driver can't make a broken DUT look correct.

Run on the SJ server:  make SIM=xcelium   (see Makefile in this folder)
"""

from __future__ import annotations

import os
import random

import cocotb
import pyuvm
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Event, FallingEdge, ReadOnly, RisingEdge
from pyuvm import (uvm_analysis_port, uvm_component, uvm_driver, uvm_env, uvm_sequence,
                   uvm_sequence_item, uvm_sequencer, uvm_test, uvm_tlm_analysis_fifo)

from rv32_golden import EBREAK, OP_I, OP_LOAD, RV32Model, assemble, enc_b, enc_i, enc_r, enc_s

ISRAM, DSRAM, REGS = 0x0000, 0x1000, 0x2000
DMEM_CHECK_WORDS = 64              # data words read back and checked after each program
HALT_TIMEOUT_CYCLES = 5000


# ---------------------------------------------------------------------------
# Transactions
# ---------------------------------------------------------------------------
class ProgramItem(uvm_sequence_item):
    """One complete program: instruction words, initial data memory, a name."""

    def __init__(self, name="program", words=None, data=None):
        super().__init__(name)
        self.words: list[int] = list(words or [])
        self.data: dict[int, int] = dict(data or {})

    def __str__(self):
        return f"{self.get_name()}: {len(self.words)} words, {len(self.data)} data words"


class ResultItem(uvm_sequence_item):
    """What the monitor saw on the pins for one program."""

    def __init__(self, name="result"):
        super().__init__(name)
        self.halted = False
        self.regs: dict[int, int] = {}
        self.dmem: dict[int, int] = {}


# ---------------------------------------------------------------------------
# Sequences
# ---------------------------------------------------------------------------
DIRECTED = {
    "add_sub_wrap": """
        addi x1, x0, -1
        addi x2, x0, 1
        add  x3, x1, x2          # 0xFFFFFFFF + 1 wraps to 0
        sub  x4, x0, x2          # 0 - 1 = 0xFFFFFFFF
        ebreak""",
    "shift_low5": """
        addi x1, x0, 1
        addi x2, x0, 33          # shift amount is rs2[4:0] -> 1
        sll  x3, x1, x2
        addi x4, x0, -1
        srl  x5, x4, x2          # logical shift: 0x7FFFFFFF
        ebreak""",
    "load_use_beq": """
        addi x1, x0, 7
        sw   x1, 16(x0)
        lw   x2, 16(x0)
        beq  x2, x1, ok          # beq right after lw must see the loaded value
        addi x9, x0, 1
    ok: addi x10, x0, 2
        ebreak""",
    "x0_hardwired": """
        addi x0, x0, 5
        add  x1, x0, x0
        ebreak""",
}


class DirectedSeq(uvm_sequence):
    async def body(self):
        for name, src in DIRECTED.items():
            item = ProgramItem(name, assemble(src))
            await self.start_item(item)
            await self.finish_item(item)


class RandomProgramSeq(uvm_sequence):
    """Constrained-random programs: legal ops only, hazard-heavy register picks,
    word-aligned memory offsets, forward in-bounds branches, always ends in ebreak."""

    def __init__(self, name="random_seq", count=50, length=20, seed=None):
        super().__init__(name)
        self.count, self.length = count, length
        self.rng = random.Random(seed)

    def _reg(self):
        r = self.rng.random()
        if r < 0.70:
            return self.rng.randint(1, 7)       # recently written regs -> more RAW hazards
        if r < 0.80:
            return 0
        return self.rng.randint(8, 31)

    def _instr(self, idx):
        rng = self.rng
        op = rng.choice(["add", "sub", "sll", "srl", "addi", "lw", "sw", "beq"])
        if op in ("add", "sub", "sll", "srl"):
            return enc_r(op, self._reg(), self._reg(), self._reg())
        if op == "addi":
            imm = rng.choice([-2048, -1, 0, 1, 2047, rng.randint(-2048, 2047)])
            return enc_i(OP_I, 0, self._reg(), self._reg(), imm)
        off = rng.randint(-512, 511) * 4                   # word aligned
        base = 0 if rng.random() < 0.5 else self._reg()
        if op == "lw":
            return enc_i(OP_LOAD, 0b010, self._reg(), base, off)
        if op == "sw":
            return enc_s(base, self._reg(), off)
        # beq: forward only, never past the final ebreak, so every program terminates
        target = rng.randrange(4, (self.length - idx) * 4 + 1, 4)
        rs1 = self._reg()
        rs2 = rs1 if rng.random() < 0.5 else self._reg()   # about half are guaranteed taken
        return enc_b(rs1, rs2, target)

    async def body(self):
        for p in range(self.count):
            words = [self._instr(i) for i in range(self.length)] + [EBREAK]
            data = {self.rng.randrange(DMEM_CHECK_WORDS): self.rng.getrandbits(32) for _ in range(16)}
            item = ProgramItem(f"random_{p}", words, data)
            await self.start_item(item)
            await self.finish_item(item)


# ---------------------------------------------------------------------------
# Driver: the only component that drives DUT inputs
# ---------------------------------------------------------------------------
class Driver(uvm_driver):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)          # "expected" path -> scoreboard

    def start_of_simulation_phase(self):
        self.dut = cocotb.top

    def idle(self):
        d = self.dut
        for sig in (d.en_cpu_i, d.halt_cpu_i, d.w_en_i, d.r_en_i, d.addr_i, d.wdata_i):
            sig.value = 0

    async def reset(self):
        self.idle()
        self.dut.rst_i.value = 1
        await ClockCycles(self.dut.clk_i, 5)
        await FallingEdge(self.dut.clk_i)
        self.dut.rst_i.value = 0

    async def write(self, addr, data):
        d = self.dut
        await FallingEdge(d.clk_i)
        d.addr_i.value, d.wdata_i.value, d.w_en_i.value = addr, data & 0xFFFF_FFFF, 1
        await FallingEdge(d.clk_i)
        d.w_en_i.value = 0

    async def read(self, addr):
        """Hold addr/r_en until rready. The value itself is captured by the monitor."""
        d = self.dut
        await FallingEdge(d.clk_i)
        d.addr_i.value, d.r_en_i.value = addr, 1
        for _ in range(4):
            await ReadOnly()
            if int(d.rready_o.value):
                break
            await RisingEdge(d.clk_i)
        else:
            raise AssertionError(f"no rready for read of 0x{addr:04x}")
        await FallingEdge(d.clk_i)
        d.r_en_i.value = 0

    async def wait_for_halt(self):
        d = self.dut
        for _ in range(HALT_TIMEOUT_CYCLES):
            await RisingEdge(d.clk_i)
            await ReadOnly()
            if int(d.cpu_halted_o.value):
                break
        # chip_top holds memory ownership one more cycle after the halt pulse,
        # so wait before touching the external port (avoids the driver race)
        await ClockCycles(d.clk_i, 2)

    async def run_phase(self):
        first = True
        while True:
            item = await self.seq_item_port.get_next_item()
            await self.reset()
            if first:
                # reset does not clear the SRAMs, so start the run from a known
                # all-zero data memory (the scoreboard's shadow starts at zero too)
                for w in range(1024):
                    await self.write(DSRAM + 4 * w, 0)
                first = False
            for i, w in enumerate(item.words):
                await self.write(ISRAM + 4 * i, w)
            for idx, w in item.data.items():
                await self.write(DSRAM + 4 * idx, w)
            self.ap.write(item)
            await FallingEdge(self.dut.clk_i)
            self.dut.en_cpu_i.value = 1                    # one-cycle start pulse
            await FallingEdge(self.dut.clk_i)
            self.dut.en_cpu_i.value = 0
            await self.wait_for_halt()
            for r in range(32):
                await self.read(REGS + 4 * r)
            for w in range(DMEM_CHECK_WORDS):
                await self.read(DSRAM + 4 * w)
            self.seq_item_port.item_done()


# ---------------------------------------------------------------------------
# Monitor: passive, rebuilds what actually happened from the pins
# ---------------------------------------------------------------------------
class Monitor(uvm_component):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)          # "actual" path -> scoreboard

    def start_of_simulation_phase(self):
        self.dut = cocotb.top

    async def run_phase(self):
        d = self.dut
        res = None
        while True:
            await RisingEdge(d.clk_i)
            await ReadOnly()
            if int(d.rst_i.value):
                continue
            if int(d.en_cpu_i.value):                    # a new program just started
                res = ResultItem()
            if res is None:
                continue
            if int(d.cpu_halted_o.value):
                res.halted = True
            if int(d.r_en_i.value) and int(d.rready_o.value):
                addr = int(d.addr_i.value)
                window, index = addr >> 12, (addr >> 2) & 0x3FF
                if window == 0b10:
                    res.regs[index & 0x1F] = int(d.rdata_o.value)
                elif window == 0b01:
                    res.dmem[index] = int(d.rdata_o.value)
                if len(res.regs) == 32 and len(res.dmem) == DMEM_CHECK_WORDS:
                    self.ap.write(res)
                    res = None


# ---------------------------------------------------------------------------
# Scoreboard: golden-model prediction vs. what the DUT reported
# ---------------------------------------------------------------------------
class Scoreboard(uvm_component):
    def build_phase(self):
        self.expected_fifo = uvm_tlm_analysis_fifo("expected_fifo", self)
        self.actual_fifo = uvm_tlm_analysis_fifo("actual_fifo", self)
        self.expected_export = self.expected_fifo.analysis_export
        self.actual_export = self.actual_fifo.analysis_export
        self.passed = self.failed = 0
        # Data SRAM keeps its contents across resets, so the scoreboard keeps a
        # shadow copy of what the DUT's data memory should hold between programs.
        self.shadow_dmem = [0] * 1024

    async def run_phase(self):
        while True:
            prog: ProgramItem = await self.expected_fifo.get()
            res: ResultItem = await self.actual_fifo.get()
            self.check(prog, res)

    def check(self, prog: ProgramItem, res: ResultItem):
        model = RV32Model()
        model.dmem = list(self.shadow_dmem)
        model.load(prog.words, prog.data)
        model.run()
        self.shadow_dmem = list(model.dmem)

        errors = []
        if not res.halted:
            errors.append("CPU never pulsed cpu_halted (timeout)")
        for r in range(32):
            if res.regs.get(r) != model.regs[r]:
                errors.append(f"x{r}: DUT {res.regs.get(r, 0):#010x} != model {model.regs[r]:#010x}")
        for w in range(DMEM_CHECK_WORDS):
            if res.dmem.get(w) != model.dmem[w]:
                errors.append(f"dmem[{w}]: DUT {res.dmem.get(w, 0):#010x} != model {model.dmem[w]:#010x}")

        if errors:
            self.failed += 1
            self.logger.error(f"{prog.get_name()} FAILED ({len(errors)} mismatches)")
            for e in errors[:10]:
                self.logger.error("    " + e)
        else:
            self.passed += 1
            self.logger.info(f"{prog.get_name()} passed ({model.retired} instructions retired)")

    def report_phase(self):
        self.logger.info(f"SCOREBOARD: {self.passed} passed, {self.failed} failed")
        assert self.failed == 0, f"{self.failed} program(s) mismatched the golden model"


# ---------------------------------------------------------------------------
# Environment and tests
# ---------------------------------------------------------------------------
class Env(uvm_env):
    def build_phase(self):
        self.seqr = uvm_sequencer("seqr", self)
        self.driver = Driver("driver", self)
        self.monitor = Monitor("monitor", self)
        self.scoreboard = Scoreboard("scoreboard", self)

    def connect_phase(self):
        self.driver.seq_item_port.connect(self.seqr.seq_item_export)
        self.driver.ap.connect(self.scoreboard.expected_export)
        self.monitor.ap.connect(self.scoreboard.actual_export)


class BaseTest(uvm_test):
    def build_phase(self):
        self.env = Env("env", self)

    async def run_sequences(self):
        raise NotImplementedError

    async def run_phase(self):
        self.raise_objection()
        cocotb.start_soon(Clock(cocotb.top.clk_i, 10, "ns").start())
        await self.run_sequences()
        await ClockCycles(cocotb.top.clk_i, 20)    # let the scoreboard drain
        self.drop_objection()


@pyuvm.test()
class DirectedTest(BaseTest):
    """Hand-written corner cases: wraparound, shift masking, load-use beq, x0."""

    async def run_sequences(self):
        await DirectedSeq("directed").start(self.env.seqr)


@pyuvm.test()
class RandomTest(BaseTest):
    """Constrained-random programs. Set SEED / NUM_PROGRAMS to reproduce or scale."""

    async def run_sequences(self):
        seed = int(os.environ.get("SEED", random.randrange(2**31)))
        count = int(os.environ.get("NUM_PROGRAMS", "50"))
        self.logger.info(f"RandomTest seed={seed} programs={count}")
        await RandomProgramSeq("random", count=count, seed=seed).start(self.env.seqr)
