"""
Target code representation (assembly) module.
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
    opcode: str
    src: str = None
    dst: str = None

    def __str__(self) -> str:
        if self.src is None and self.dst is None:
            return self.opcode
        if self.dst is None:
            return f"{self.opcode} {self.src}"
        return f"{self.opcode} {self.src},{self.dst}"  # Return a properly formatted assembly instruction string.



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
