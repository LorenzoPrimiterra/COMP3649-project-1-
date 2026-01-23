# intermediate.py
"""
Intermediate Representation (IR) module.

Defines:
- Operation (one three-address instruction)
- IntermediateCode (sequence of operations + live-out variables)

NO parsing logic belongs here.
"""

from dataclasses import dataclass
from typing import List

@dataclass(frozen=True) #immutable class 
class Operation:
    """
    One three-address instruction.

    Forms:
      dst = src
      dst = -src
      dst = src1 op src2
    """
    destination: str
    operand1: str
    operator: str = None
    operand2: str = None
    unary_neg: bool = False # the negative op

    def __str__(self) -> str:
        if self.operator is None and not self.unary_neg:
            return f"{self.destination} = {self.operand1}"
        if self.unary_neg:
            return f"{self.destination} = -{self.operand1}"
        return f"{self.destination} = {self.operand1} {self.operator} {self.operand2}"


class IntermediateCode: # TO DO
    """
    Represents a full basic block:
    - a list of Operations
    - the list of live-out variables (from the final 'live:' line)

    t1 = a * 4      ← one operation
    t2 = t1 + 1     ← one operation
    b  = t2 - a     ← one operation
    live: b
    """
