"""
target.py
=========
Defines the data structures used to store and represent
assembly instructions after code generation.

Pipeline:
===============
(Sits at the end of the pipeline as the final output stage:)

  (1)  interference.py  <- provides register assignments.
          
  (2)  target.py        <- stores and formats the generated assembly instructions.
          
  (3)  output           <- assembly code ready to be written to a .s file.

Responsibilities:
===========================
- Define AsmInstruction, representing a single assembly instruction.
- Define TargetCode, representing a full sequence of assembly instructions.
- Provide string output that formats instructions in correct assembly syntax.

Associated Dependencies:
==========================
NA

Usage Example:
===================
NA

Misc Notes:
============
NA
"""

from typing import List


class AsmInstruction:
    """
    AsmInstruction: 

    Represents a single assembly language instruction.

    An instruction consists of:
        - an opcode (e.g., ADD, SUB, MUL, DIV, MOV)
        - an optional source operand
        - an optional destination operand

    Supported forms:
        opcode
        opcode src
        opcode src,dst

    Examples:
        ADD #1,R0
        MOV R1,a
        MUL R2,R3
    """
    def __init__(self, opcode: str, src: str = None, dst: str = None, UnaryNeg: bool = False):
        self.opcode = opcode
        self.src = src if not UnaryNeg else -src #might be an incorrect implementation. Double check.
        self.dst = dst

    def __str__(self) -> str:
        if self.src is None and self.dst is None:
            return self.opcode
        if self.dst is None:
            return f"{self.opcode} {self.src}"
        return f"{self.opcode} {self.src},{self.dst}"



class TargetCode:
    """
    TargetCode: 

    Represents a sequence of assembly instructions corresponding to a single basic block of generated target code.

    This class serves as a container for AsmInstruction objects and provides support routines for constructing and printing the
    target code sequence.
    """
    def __init__(self) -> None:
        self.instructions: List[AsmInstruction] = []

    def add(self, instr: AsmInstruction) -> None:
        self.instructions.append(instr)             # Append an assembly instruction to the target code sequence.

    def __str__(self) -> str:
        """
        Return the complete target code as a newline-separated string
        suitable for writing to an output .s file.
        """
        return "\n".join(str(i) for i in self.instructions)


        




