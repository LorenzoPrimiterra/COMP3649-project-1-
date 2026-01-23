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

from errors import ParseError
from intermediate import Operation, IntermediateCode


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


def parse_live_line(line: str) -> List[str]:
    """
    Parse the final 'live:' line of the input file.

    Input format:
      live: v1, v2, v3

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


def readIntermediateCode(f: TextIO) -> IntermediateCode:
    """
    Parse an entire intermediate-code input file.

    File structure:
      - Zero or more three-address instruction lines
      - One final non-empty line of the form: 'live: ...'

    Responsibilities:
    - Read all non-empty lines
    - Parse each instruction line using read3AddrInstruction
    - Parse the final live-out line using parse_live_line
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
