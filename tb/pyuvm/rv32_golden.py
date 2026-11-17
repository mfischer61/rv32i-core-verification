"""Python golden model for my RV32I onboarding core.

Executes the 9-instruction subset the core supports (add, sub, sll, srl,
addi, lw, sw, beq, ebreak) at the architectural level: no cycles, no
pipeline, just "what should the registers and data memory hold when the
program halts". The pyuvm scoreboard runs every program through this model
and compares the result against what the DUT reports through the external
port.

Also includes a tiny two-pass assembler for the same subset so directed
tests can be written as readable assembly.

Memory model matches chip_top: 1024-word instruction SRAM, 1024-word data
SRAM indexed by byte_address[11:2] (so every rs1+imm lands on a real word),
and the PC wraps inside the 4 KB instruction window.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

MASK32 = 0xFFFF_FFFF
WORDS = 1024
EBREAK = 0x0010_0073

# opcodes
OP_R, OP_I, OP_LOAD, OP_STORE, OP_BRANCH, OP_SYSTEM = (
    0b0110011, 0b0010011, 0b0000011, 0b0100011, 0b1100011, 0b1110011)


def sext(value: int, bits: int) -> int:
    """Sign-extend `bits`-wide value to a Python int."""
    sign = 1 << (bits - 1)
    value &= (1 << bits) - 1
    return (value ^ sign) - sign


# ---------------------------------------------------------------------------
# Decode
# ---------------------------------------------------------------------------
@dataclass
class Decoded:
    name: str          # "add", "addi", ..., or "nop" for unsupported encodings
    rd: int = 0
    rs1: int = 0
    rs2: int = 0
    imm: int = 0


def decode(word: int) -> Decoded:
    opcode = word & 0x7F
    rd = (word >> 7) & 0x1F
    funct3 = (word >> 12) & 0x7
    rs1 = (word >> 15) & 0x1F
    rs2 = (word >> 20) & 0x1F
    funct7 = (word >> 25) & 0x7F

    imm_i = sext(word >> 20, 12)
    imm_s = sext(((word >> 25) << 5) | ((word >> 7) & 0x1F), 12)
    imm_b = sext((((word >> 31) & 1) << 12) | (((word >> 7) & 1) << 11)
                 | (((word >> 25) & 0x3F) << 5) | (((word >> 8) & 0xF) << 1), 13)

    if opcode == OP_R and funct3 == 0b000 and funct7 == 0b0000000:
        return Decoded("add", rd, rs1, rs2)
    if opcode == OP_R and funct3 == 0b000 and funct7 == 0b0100000:
        return Decoded("sub", rd, rs1, rs2)
    if opcode == OP_R and funct3 == 0b001 and funct7 == 0b0000000:
        return Decoded("sll", rd, rs1, rs2)
    if opcode == OP_R and funct3 == 0b101 and funct7 == 0b0000000:
        return Decoded("srl", rd, rs1, rs2)
    if opcode == OP_I and funct3 == 0b000:
        return Decoded("addi", rd, rs1, imm=imm_i)
    if opcode == OP_LOAD and funct3 == 0b010:
        return Decoded("lw", rd, rs1, imm=imm_i)
    if opcode == OP_STORE and funct3 == 0b010:
        return Decoded("sw", 0, rs1, rs2, imm=imm_s)
    if opcode == OP_BRANCH and funct3 == 0b000:
        return Decoded("beq", 0, rs1, rs2, imm=imm_b)
    if word == EBREAK:
        return Decoded("ebreak")
    return Decoded("nop")  # unsupported encodings retire as no-ops


# ---------------------------------------------------------------------------
# Architectural model
# ---------------------------------------------------------------------------
@dataclass
class StoreEvent:
    word_index: int
    data: int


@dataclass
class RV32Model:
    imem: list[int] = field(default_factory=lambda: [0] * WORDS)
    dmem: list[int] = field(default_factory=lambda: [0] * WORDS)
    regs: list[int] = field(default_factory=lambda: [0] * 32)
    pc: int = 0
    halted: bool = False
    retired: int = 0
    stores: list[StoreEvent] = field(default_factory=list)

    def load(self, program: list[int], data: dict[int, int] | None = None) -> None:
        for i, w in enumerate(program):
            self.imem[i] = w & MASK32
        for idx, w in (data or {}).items():
            self.dmem[idx % WORDS] = w & MASK32

    def _write(self, rd: int, value: int) -> None:
        if rd != 0:                       # x0 is hardwired to zero
            self.regs[rd] = value & MASK32

    def step(self) -> Decoded:
        ins = decode(self.imem[(self.pc >> 2) % WORDS])
        r = self.regs
        next_pc = (self.pc + 4) & 0xFFF   # PC wraps inside the 4 KB window

        if ins.name == "add":
            self._write(ins.rd, r[ins.rs1] + r[ins.rs2])
        elif ins.name == "sub":
            self._write(ins.rd, r[ins.rs1] - r[ins.rs2])
        elif ins.name == "sll":
            self._write(ins.rd, r[ins.rs1] << (r[ins.rs2] & 0x1F))   # only rs2[4:0]
        elif ins.name == "srl":
            self._write(ins.rd, r[ins.rs1] >> (r[ins.rs2] & 0x1F))   # logical, zero-fill
        elif ins.name == "addi":
            self._write(ins.rd, r[ins.rs1] + ins.imm)
        elif ins.name == "lw":
            addr = (r[ins.rs1] + ins.imm) & MASK32
            self._write(ins.rd, self.dmem[(addr >> 2) & 0x3FF])
        elif ins.name == "sw":
            addr = (r[ins.rs1] + ins.imm) & MASK32
            idx = (addr >> 2) & 0x3FF
            self.dmem[idx] = r[ins.rs2]
            self.stores.append(StoreEvent(idx, r[ins.rs2]))
        elif ins.name == "beq":
            if r[ins.rs1] == r[ins.rs2]:
                next_pc = (self.pc + ins.imm) & 0xFFF
        elif ins.name == "ebreak":
            self.halted = True
            next_pc = self.pc

        self.pc = next_pc
        self.retired += 1
        return ins

    def run(self, max_steps: int = 10_000) -> "RV32Model":
        while not self.halted and self.retired < max_steps:
            self.step()
        return self


# ---------------------------------------------------------------------------
# Mini assembler (same 9 instructions, labels, comments)
# ---------------------------------------------------------------------------
_R = {"add": (0b000, 0b0000000), "sub": (0b000, 0b0100000),
      "sll": (0b001, 0b0000000), "srl": (0b101, 0b0000000)}


def _reg(tok: str) -> int:
    tok = tok.strip().lower()
    if tok == "zero":
        return 0
    if not re.fullmatch(r"x([0-9]|[12][0-9]|3[01])", tok):
        raise ValueError(f"bad register {tok!r}")
    return int(tok[1:])


def _imm(tok: str) -> int:
    return int(tok.strip(), 0)


def enc_r(name, rd, rs1, rs2):
    f3, f7 = _R[name]
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | OP_R


def enc_i(opcode, f3, rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opcode


def enc_s(rs1, rs2, imm):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (0b010 << 12) | ((imm & 0x1F) << 7) | OP_STORE


def enc_b(rs1, rs2, imm):
    imm &= 0x1FFF
    return ((((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15)
            | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | OP_BRANCH)


def assemble(src: str) -> list[int]:
    """Assemble the 9-instruction subset. Two passes so branches can use labels."""
    lines = []
    for raw in src.splitlines():
        line = raw.split("#", 1)[0].split("//", 1)[0].strip()
        while ":" in line:                      # one or more labels on the line
            label, line = line.split(":", 1)
            lines.append(("label", label.strip()))
            line = line.strip()
        if line and not line.startswith("."):
            lines.append(("ins", line))

    labels, pc = {}, 0
    for kind, text in lines:
        if kind == "label":
            labels[text] = pc
        else:
            pc += 4

    words, pc = [], 0
    for kind, text in lines:
        if kind != "ins":
            continue
        op, _, rest = text.partition(" ")
        op = op.lower()
        args = [a.strip() for a in rest.split(",")] if rest.strip() else []
        if op in _R:
            words.append(enc_r(op, _reg(args[0]), _reg(args[1]), _reg(args[2])))
        elif op == "addi":
            words.append(enc_i(OP_I, 0b000, _reg(args[0]), _reg(args[1]), _imm(args[2])))
        elif op in ("lw", "sw"):
            m = re.fullmatch(r"(-?\w+)\((\w+)\)", args[1].replace(" ", ""))
            if not m:
                raise ValueError(f"bad memory operand in {text!r}")
            off, base = _imm(m.group(1)), _reg(m.group(2))
            if op == "lw":
                words.append(enc_i(OP_LOAD, 0b010, _reg(args[0]), base, off))
            else:
                words.append(enc_s(base, _reg(args[0]), off))
        elif op == "beq":
            target = args[2]
            off = labels[target] - pc if target in labels else _imm(target)
            words.append(enc_b(_reg(args[0]), _reg(args[1]), off))
        elif op == "ebreak":
            words.append(EBREAK)
        elif op == "nop":
            words.append(enc_i(OP_I, 0, 0, 0, 0))
        else:
            raise ValueError(f"unsupported instruction {op!r}")
        pc += 4
    return words


if __name__ == "__main__":
    demo = """
        addi x1, x0, 5
        addi x2, x0, -3
        add  x3, x1, x2
        sw   x3, 8(x0)
        lw   x4, 8(x0)
        beq  x3, x4, done
        addi x5, x0, 1      # skipped
    done:
        ebreak
    """
    m = RV32Model()
    m.load(assemble(demo))
    m.run()
    print("halted:", m.halted, "retired:", m.retired)
    print("x1..x5:", [hex(m.regs[i]) for i in range(1, 6)])
