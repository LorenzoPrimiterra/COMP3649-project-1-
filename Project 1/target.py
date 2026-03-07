"""
target.py
=========
Defines the data structures used to store and represent
assembly instructions after code generation.

Role in the Pipeline
--------------------
Sits at the end of the pipeline as the final output stage:

    interference.py  ← provides register assignments
          ↓
    target.py        ← stores and formats the generated assembly instructions
          ↓
    output           ← assembly code ready to be written to a .s file

Responsibilities
----------------
- Define AsmInstruction, representing a single assembly instruction
- Define TargetCode, representing a full sequence of assembly instructions
- Provide string output that formats instructions in correct assembly syntax

Out of Scope
------------
- Parsing input files (parser.py)
- Computing liveness (liveness.py)
- Building interference graphs or assigning registers (interference.py)
- Storing or processing three-address instructions (intermediate.py)

Key Abstractions
----------------
AsmInstruction
    Stores one assembly instruction — its opcode and optional
    source and destination operands.

TargetCode
    Holds the full list of assembly instructions for a basic block
    and formats them as a complete output string.

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

instruction = {
    "=":"MOV",
    "+":"ADD",
    "-":"SUB",
    "*":"MUL",
    "/":"DIV"
}
def OpParser(op:Operator):
    target = instruction.get(op):
    if target != None:
        return target
    raise InvalidOpError(f"The given operator {op} is not a valid instruction in our architecture.")

#Might not be a useful function, still working on this rn, flipped the logic because this is supposed to tell us if our op is immediate, but if it isnt we have more work to do
def isImmediateOp(operand1:Operand, operand2:Operand = None)->bool:
    if(isinstance(operand1,int) and (isinstance(operand2,int) or operand2 == None)){
        return true
    }
    return false

def TargetCodeOpParser(code){
    currentOp = OpParser(code.operator)
    if(isImmediateOp(code.operand1, code.operand2)): #this means we have 1 step instructions.
        if(code.)
        #Do multi-step instructions that might require movs or sign flips
}    
def IntermediateToAsm(intermediate:IntermediateCode) -> None:
    prev = None
    for code in intermediate:
        if(isinstance(code.operand1,str) or isinstance(code.operand2,str)){ #basically, are 1 and 2 immediate values

        }
        TargetCodeopParser(code.operator) #Very basic, not built rn but the logic 
        




