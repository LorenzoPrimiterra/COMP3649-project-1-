#define below. Gives us list class to define things being of type list:
from typing import List

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


#Purpose: This class is used as the structure to hold our Three-address intermediate 
#         Representation, as well as our assembly. Operands default to null, but error 
#         handling should prevent the code operation class from being an empty insert into
#         a destination address or register.
#         Class initializer is in prefix notation.
class Operation:
    def __init__(self, destination, operator, operand1=None, operand2=None):
        self.destination = destination
        self.operator = operator
        self.operand1 = operand1
        self.operand2 = operand2

        
def TokenOperizer(tokens: List[str])->Operation:
    op = Operation(tokens[0], tokens[2], tokens[1])
    if(len(tokens)>3):
        op.operand2 = tokens[3]
    return op

#Purpose: This Simply takes a list of all the operators and operations and prints them out.
def OperatorPrinter(operators: List[str]) -> None:
    for operation in operators:
        if(operation.operator == "="):
            print(f"{operation.destination} = {operation.operand1}") #if(operation.operand2 != None):
        else:
            print(f"{operation.destination} = {operation.operand1} {operation.operator} {operation.operand2}")
    
#Purpose: This stub is intended to print out all of the live vars once the vars are printed 
#         out.
def LivenessPrinter(livevars: List[str]) -> None:
    print("Active: ".join(livevars))
