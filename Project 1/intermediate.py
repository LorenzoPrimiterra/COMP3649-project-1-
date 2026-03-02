"""
intermediate.py
===============
Defines the data structures used to store a program's instructions
and variables after they have been parsed from the input file.

Role in the Pipeline
--------------------
Receives parsed data from parser.py and acts as the shared data structure
passed through the rest of the pipeline:

    parser.py        ← constructs Operation and IntermediateCode objects
          ↓
    intermediate.py  ← stores instructions and live-out vars, triggers liveness
          ↓
    liveness.py      ← reads oplist to compute live_before / live_after
          ↓
    interference.py  ← reads oplist, live_out, live_before, live_after

Responsibilities
----------------
- Define Operation, representing one three-address instruction (dst = src1 op src2)
- Define IntermediateCode, representing a full block of Operations
- Store the parsed instruction list and live-out variables
- Trigger liveness analysis via compute_liveness_info()
- Provide string output that mirrors the original input file format

Out of Scope
------------
- Reading or parsing input files (parser.py)
- Computing which variables are alive at each line (liveness.py)
- Building interference graphs or assigning registers (interference.py)
- Generating assembly instructions (target.py)

Key Abstractions
----------------
Operation
    Stores one instruction — its destination, operands, operator,
    and whether it uses a unary minus.

IntermediateCode
    Holds the full list of instructions, the live-out variables,
    and the liveness results once they have been computed.

Dependencies
------------
NA

Usage Example
-------------
NA

Notes
-----
NA
"""

from dataclasses import dataclass
from typing import List

class Operation:
    """
    One three-address instruction.

    Forms:
      dst = src
      dst = -src
      dst = src1 op src2
    """

    def __init__(
        self,
        destination: str,
        operand1: str,
        operator: str = None,
        operand2: str = None,
        unary_neg: bool = False
    ):
        self.destination = destination
        self.operand1 = operand1
        self.operator = operator
        self.operand2 = operand2
        self.unary_neg = unary_neg

    def __str__(self) -> str:
        if self.operator is None and not self.unary_neg:
            return f"{self.destination} = {self.operand1}"
        if self.unary_neg:
            return f"{self.destination} = -{self.operand1}"
        return f"{self.destination} = {self.operand1} {self.operator} {self.operand2}"


class IntermediateCode: 
    """
    Represents a full basic block of intermediate code.

    The block consists of:
      - a list of three-address instructions (Operation objects)
      - a list of variables that are live on exit from the block

    Example:
        t1 = a * 4
        t2 = t1 + 1
        b  = t2 - a
        live: b

    This class acts as a container for the IR and provides simple support
    routines so that other modules (parser, liveness analysis, code
    generation) can safely access and display the block.
    """

    def __init__(self, oplist: List[Operation] = None, live_out: List[str] = None):
        """
        Initialize an IntermediateCode object.

        Parameters:
          oplist   : list of Operation objects in program order
          live_out : list of variable names live at block exit

        Both parameters are optional; empty lists are used if none are provided.
        """
        self.oplist = list(oplist) if oplist is not None else []
        self.live_out = list(live_out) if live_out is not None else []
        
        self.live_before = None
        self.live_after = None

    def compute_liveness_info(self) -> None:
        """
        Compute and store liveness sets on this IntermediateCode object.
        """
        from liveness import compute_liveness # local import, otherwise causes circular imports 
        self.live_before, self.live_after = compute_liveness(self.oplist, set(self.live_out))


    def insert(self, op:Operation)-> None:
        """
        Append a single Operation to the end of the instruction sequence.
        """
        self.oplist.append(op)
    
    def __str__(self) -> str:
        """
        Return the entire basic block as a formatted string.
        The output mirrors the original input format.
        """
        lines = [str(op) for op in self.oplist]
        lines.append("live: " + ", ".join(self.live_out))
        return "\n".join(lines)

        
