# parser.py
"""
Parser module for COMP 3649 register-allocation project (Week 3).

Responsibilities of this module:
- Read and validate the intermediate-code input file
- Parse each three-address instruction into an IR object
- Parse the final 'live:' line
- Raise ParseError on any invalid input

This module MUST NOT:
- Open files (file I/O handled in main.py)
- Perform register allocation
- Perform liveness analysis
- Generate target/assembly code
"""

from typing import TextIO, List

import string
import re
from errors import ParseError
from intermediate import Operation, IntermediateCode




def readIntermediateCode(f: TextIO) -> IntermediateCode:
    """
    Parse an entire intermediate-code input file.

    File structure:
      - Zero or more three-address instruction lines
      - One final non-empty line of the form: 'live: ...'

    Responsibilities:
    - Read all non-empty lines
    - Parse each instruction line using read3AddrInstruction
    - Parse the final live-out line using parse_live_lineA

    - Populate and return an IntermediateCode object

    Returns:
      An IntermediateCode object containing:
        - the list of parsed Operation objects
        - the list of live-out variables

    Raises:
      ParseError if:
        - the file is empty
        - the final line is not a valid 'live:' line
        - any instruction line is malformed

    """


    operations = []
    prev = None

    for line in f:
        if prev is not None:
            op = read3AddrInstruction(prev)
            if op is not None:
              operations.append(op)
        prev = line

    if prev is None:
        raise ParseError("Empty file")

    live_out = parse_live_line(prev, operations)

    #return IntermediateCode(operations, live_out)

      
      



def tokenize_line(line: str) -> List[str]:
    """
    Break a single line of intermediate code into tokens.

    Requirements:
    - Operators (+, -, *, /) and '=' must appear as separate tokens
    - Tokenization must be whitespace-insensitive
    - Works for lines with or without spaces (e.g., 'a=a+1')

    Examples:
      "a = a + 1" -> ["a", "=", "a", "+", "1"]
      "x = -y"    -> ["x", "=", "-", "y"]
      "t1 = 10"   -> ["t1", "=", "10"]

    Raises:
      ParseError if tokenization fails or results in an invalid token sequence.
    """
def tokenize_line(line: str) -> List[str]:
 
    # Remove surrounding whitespace
    line = line.strip()
    if not line:
        return[] 

    # Removes delimiters/spaces and if they are next to eachother.
    delimiters = r"[,\s;\n]+"
    tokens = re.split(delimiters, line.strip()) 

    # Validate tokens
    valid_chars = set(string.ascii_letters + string.digits + "+-/*=_")
    valid_tokens = []
    for t in tokens:
      for ch in t:
        if ch not in valid_chars:
          raise ParseError(f"Invalid character '{ch}' in token: {t}")
        
    # output valid tokens to a list
         
      valid_tokens.append(t)
   
    return valid_tokens
        





def read3AddrInstruction(line: str) -> Operation:
    """
    Parse a single three-address instruction.

    Supported instruction forms:
      dst = src
      dst = -src
      dst = src1 op src2

    Requirements:
    - dst must be a valid variable
    - src operands must be valid variables or integer literals
    - op must be one of +, -, *, /

    Returns:
      An Operation (three-address instruction) object.

    Raises:
      ParseError if the instruction format is invalid.
    """
  # tokenzied line with valid op check already done
    tokens = tokenize_line(line)
  
  # skip blank lines
    if not tokens:
      return None

    length = len(tokens)

    if length not in (3, 4, 5):
      raise ParseError("Invalid instruction size. Expected three-address instruction.")

    
  # Validate destination variable
    dest = tokens[0]
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", dest):
      raise ParseError("Invalid destination type.")

       
 # dst = src
    if length == 3:
       src = tokens[2]

       is_var = re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", src)
       is_int = re.fullmatch(r"-?\d+", src)

       if not (is_var or is_int):
        raise ParseError("Invalid source within [dst = src] format.")
      

  # checks if dst = -src
    elif length == 4:
       negative = tokens[2]
       src = tokens[3]

       if negative != "-":
          raise ParseError("Expected unary '-' in [dst = -src] format.")

       is_var = re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", src)
       is_int = re.fullmatch(r"-?\d+", src)

       if not (is_var or is_int):
          raise ParseError("Invalid source within [dst = -src] format.")

  
   # dst = src1 op src2
    elif length == 5:
      src1 = tokens[2]
      op   = tokens[3]
      src2 = tokens[4]

      # Validate operator
      if op not in {"+", "-", "*", "/"}:
          raise ParseError("Invalid operator in [dst = src1 op src2] format.")

      # Validate src1
      is_var1 = re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", src1)
      is_int1 = re.fullmatch(r"-?\d+", src1)

      if not (is_var1 or is_int1):
        raise ParseError("Invalid first operand in [dst = src1 op src2] format.")

      # Validate src2
      is_var2 = re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", src2)
      is_int2 = re.fullmatch(r"-?\d+", src2)

      if not (is_var2 or is_int2):
        raise ParseError("Invalid second operand in [dst = src1 op src2] format.")

  # Return the appropriate Operation based on instruction type
    if length == 3:
    # dst = src
      return Operation(dest, tokens[2])
    elif length == 4:
    # dst = -src (unary minus)
      return Operation(dest, tokens[3], unary_neg=True)
    elif length == 5:
    # dst = src1 op src2
      return Operation(dest, tokens[2], tokens[3], tokens[4])


def parse_live_line(line: str, operations: List[Operation]) -> List[str]:
    
    """
    Parse the final 'live:' line of the input file.

    Input format:
      live: v1, v2, v3
      Operations: valid operations determined via read3AddrInstructions

    Requirements:
    - Must start with 'live:'
    - Variables must be comma-separated
    - Variables must follow the project naming rules
    - Variables listed must have appeared earlier in the code

    Returns:
      A list of variable names live on exit.

    Raises:
      ParseError if the line is invalid.
    """

    line = line.strip()
    
   
    # Check if the first element is 'live:'
    if not line.startswith("live:"):
        raise ParseError("Final line must start with 'live:'")

    # Removes live section
    rest_of_line = line[5:].strip()
    
    # Handle empty live set
    if not rest_of_line:
        raise ParseError("No live variables found.")

    # splits the rest of the string on comma's to get each variable
    live_vars = rest_of_line.split(',')
    
    
     # Clean up whitespace and validate each variable
    for i in range(len(live_vars)):
        live_vars[i] = live_vars[i].strip()
        
        # Check if valid variable name
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", live_vars[i]):
            raise ParseError(f"Invalid variable name: '{live_vars[i]}'")
    
    # Check that each live variable appeared in the code
    for var in live_vars:
        found = False
        
        for op in operations:
            if var == op.destination or var == op.operand1 or var == op.operand2:
                found = True
                break
        
        if not found:
            raise ParseError(f"Variable '{var}' not found in code")
    
    return live_vars



   