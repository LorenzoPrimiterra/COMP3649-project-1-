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

#Purpose: This takes a line and converts it into tokens, which are returned in an operator 
#         class. Supports assignment inputs (e.g. x = a). 
# 
#Assumptions:
#   Assumes tokens are stored in infix notation e.g. x x + 1
#   Assumes that quick operators are decomposed and broken into their subparts
#   (e.g. x += 1 is changed to x = x + 1)
#   Assumes that tokens have superfluous operators removed, e.g. no equality if not an assignment operator
#
#Input: A tokenized string, given as a list. List expected to have the format below:
#       [destination, operand1, operator, optional:operand2]
#
#Output: A member of the Operation class, with a destination, operation, and operator(s)
def TokenOperizer(tokens: List[str])->Operation:
    op = Operation(tokens[0], tokens[2], tokens[1])
    if(len(tokens)>3):
        op.operand2 = tokens[3]
    return op



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
    def __init__(self, op:Operation = None, oplist: List[Operation] = []):
        if op is not None:
            self.oplist.append(op)
    #This method is just a lazy and simple abstraction to insert an operation.
    def insert(self, op:Operation)-> None:
        self.oplist.append(op)
    #Purpose: This Simply takes a list of all the operators and operations and prints them out.
    def OperatorPrinter(self)-> None:
        if self.oplist == []:
            for operation in self.oplist:
                if(operation.operator == "="):
                    print(f"{operation.destination} = {operation.operand1}")
                else:
                    print(f"{operation.destination} = {operation.operand1} {operation.operator} {operation.operand2}")
    

        
