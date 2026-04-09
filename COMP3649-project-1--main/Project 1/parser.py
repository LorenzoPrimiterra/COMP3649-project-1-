"""
parser.py
=========
Reads an input file and turns each line into structured Python objects
that the rest of the program can work with.

Role in the Pipeline
--------------------
First stage after main.py opens the file:

    main.py          <- opens the file and passes it to the parser
          |
    parser.py        <- reads and validates each line, builds the instruction list
          |
    intermediate.py  <- receives the Operation list and live-out variables

Responsibilities
----------------
- Read and validate each instruction line from the input file.
- Break each line into tokens (handles spacing like a=b+c and a = b + c).
- Check that destinations are valid variables and operands are valid.
- Parse the final 'live:' line into a list of variable names.
- Raise ParseError on any invalid input.
- Return a populated IntermediateCode object.

Out of Scope
------------
- Opening or closing files (main.py).
- Performing liveness analysis (liveness.py).
- Building interference graphs or assigning registers (interference.py).
- Generating assembly instructions (target.py).

Key Abstractions
----------------
readIntermediateCode(f)
    Top-level function. Reads the file and returns a complete
    IntermediateCode object.

read3AddrInstruction(line)
    Parses a single instruction line into an Operation object.

tokenize_line(line)
    Breaks a raw line of text into a clean list of tokens.

parse_live_line(line, operations)
    Parses the final 'live:' line and validates the variable names.

Dependencies
------------
- errors.py       : ParseError raised on any malformed input.
- intermediate.py : Operation and IntermediateCode objects are constructed here.

Notes
-----
None.
"""

from typing import TextIO, List

import string
import re
from errors import ParseError
from intermediate import Operation, IntermediateCode


def readIntermediateCode(f: TextIO) -> IntermediateCode:
    """
    Parse an entire intermediate-code input file.

    File structure
    --------------
    - Zero or more three-address instruction lines.
    - One final non-empty line of the form: 'live: ...'

    Returns
    -------
    IntermediateCode
        Object containing the list of parsed Operations and the
        list of live-out variables.

    Raises
    ------
    ParseError
        If the file is empty, the final line is not a valid 'live:' line,
        or any instruction line is malformed.
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

    return IntermediateCode(operations, live_out)


def tokenize_line(line: str) -> List[str]:
    """
    Break a single line of intermediate code into tokens.

    Requirements
    ------------
    - Operators (+, -, *, /) and '=' must appear as separate tokens.
    - Tokenization must be whitespace-insensitive.
    - Works for lines with or without spaces (e.g., 'a=b+c' and 'a = b + c').

    Parameters
    ----------
    line : str
        A single raw line from the input file.

    Returns
    -------
    List[str]
        Clean list of tokens.

    Examples
    --------
        "a = a + 1"  ->  ["a", "=", "a", "+", "1"]
        "x = -y"     ->  ["x", "=", "-", "y"]
        "t1 = 10"    ->  ["t1", "=", "10"]

    Raises
    ------
    ParseError
        If the line contains an invalid character.

    Notes
    -----
    An earlier approach using re.split over whitespace/semicolons/commas
    broke on expressions like "a=a+1" because the whole expression became
    a single token. re.findall with an explicit token pattern extracts
    identifiers, integers, and single-character operators as distinct tokens.
    """
    line = line.strip()
    if not line:
        return []

    token_pattern = r"-?\d+|[A-Za-z][A-Za-z0-9_]*|[=+\-*/]"
    tokens = re.findall(token_pattern, line)

    # Validate that every character in every token is acceptable
    valid_chars = set(string.ascii_letters + string.digits + "+-/*=_")
    valid_tokens = []
    for t in tokens:
        for ch in t:
            if ch not in valid_chars:
                raise ParseError(f"Invalid character '{ch}' in token: {t}")
        valid_tokens.append(t)

    return valid_tokens


# ---------------------------------------------------------------------------
# Validation helpers
#
# The following functions validate individual parts of a parsed instruction:
#   (1) is_valid_variable    — destination must follow project naming rules
#   (2) is_valid_operand     — operands may be variables or integer literals
#   (3) validate_length_3    — dst = src
#   (4) validate_length_4    — dst = -src
#   (5) validate_length_5    — dst = src1 op src2
#   (6) dest_equals_source_check — dispatcher that calls the above validators
# ---------------------------------------------------------------------------


def is_valid_variable(var: str) -> bool:
    """
    Check whether a string is a valid project variable name.

    Rules
    -----
    - One lowercase letter excluding 't'  (a..z but not t).
    - OR 't' followed by one or more digits  (t1, t2, ...).

    Parameters
    ----------
    var : str
        String to validate.

    Returns
    -------
    bool
        True if var is a valid variable name.
    """
    return bool(re.fullmatch(r"(?:[a-su-z]|t\d+)", var))


def is_valid_operand(s: str) -> bool:
    """
    Check whether a string is a valid operand (variable or integer literal).

    Parameters
    ----------
    s : str
        String to validate.

    Returns
    -------
    bool
        True if s is either a valid variable name or an integer literal.
    """
    is_var = re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", s)
    is_int = re.fullmatch(r"-?\d+", s)

    if is_var:
        return True
    if is_int:
        return True
    return False


def validate_length_3(tokens):
    """
    Validate the 'dst = src' instruction form.

    Parameters
    ----------
    tokens : List[str]
        Token list of length 3.

    Raises
    ------
    ParseError
        If the source operand is not valid.
    """
    src = tokens[2]
    if not is_valid_operand(src):
        raise ParseError("Invalid source within [dst = src] format.")


def validate_length_4(tokens):
    """
    Validate the 'dst = -src' instruction form.

    Parameters
    ----------
    tokens : List[str]
        Token list of length 4.

    Raises
    ------
    ParseError
        If the unary minus is missing, or the source operand is not valid.
    """
    negative = tokens[2]
    src = tokens[3]

    if negative != "-":
        raise ParseError("Expected unary '-' in [dst = -src] format.")
    if not is_valid_operand(src):
        raise ParseError("Invalid source within [dst = -src] format.")


def validate_length_5(tokens):
    """
    Validate the 'dst = src1 op src2' instruction form.

    Parameters
    ----------
    tokens : List[str]
        Token list of length 5.

    Raises
    ------
    ParseError
        If the operator is not recognised, or either operand is not valid.
    """
    src1 = tokens[2]
    op   = tokens[3]
    src2 = tokens[4]

    if op not in {"+", "-", "*", "/"}:
        raise ParseError("Invalid operator in [dst = src1 op src2] format.")
    if not is_valid_operand(src1):
        raise ParseError("Invalid first operand in [dst = src1 op src2] format.")
    if not is_valid_operand(src2):
        raise ParseError("Invalid second operand in [dst = src1 op src2] format.")


def read3AddrInstruction(line: str) -> Operation:
    """
    Parse a single three-address instruction.

    Supported instruction forms
    ---------------------------
    - dst = src
    - dst = -src
    - dst = src1 op src2

    Parameters
    ----------
    line : str
        A single raw instruction line.

    Returns
    -------
    Operation or None
        The parsed Operation object, or None for blank lines.

    Raises
    ------
    ParseError
        If the instruction format is invalid.
    """
    tokens = tokenize_line(line)

    # Skip blank lines
    if not tokens:
        return None

    length = len(tokens)

    if length not in (3, 4, 5):
        raise ParseError("Invalid instruction size. Expected three-address instruction.")

    # Validate destination variable
    dest = tokens[0]
    if not is_valid_variable(dest):
        raise ParseError("Invalid destination type.")

    dest_equals_source_check(length, tokens)

    # Return the appropriate Operation based on instruction form
    if length == 3:
        # dst = src
        return Operation(dest, tokens[2])
    elif length == 4:
        # dst = -src  (unary minus)
        return Operation(dest, tokens[3], unary_neg=True)
    elif length == 5:
        # dst = src1 op src2
        return Operation(dest, tokens[2], tokens[3], tokens[4])


def dest_equals_source_check(length: int, tokens: List[str]) -> None:
    """
    Dispatch to the appropriate format validator based on token count.

    Parameters
    ----------
    length : int
        Number of tokens in the instruction.
    tokens : List[str]
        Token list produced by tokenize_line().
    """
    if length == 3:
        validate_length_3(tokens)
    elif length == 4:
        validate_length_4(tokens)
    elif length == 5:
        validate_length_5(tokens)


def parse_live_line(line: str, operations: List[Operation]) -> List[str]:
    """
    Parse the final 'live:' line of the input file.

    Input format
    ------------
        live: v1, v2, v3

    Parameters
    ----------
    line : str
        The last non-empty line of the file.
    operations : List[Operation]
        The list of already-parsed instructions, used to verify that
        each live variable actually appears in the code.

    Returns
    -------
    List[str]
        A list of variable names live on exit.

    Raises
    ------
    ParseError
        If the line does not start with 'live:', contains invalid variable
        names, or lists a variable that never appears in the instructions.
    """
    line = line.strip()

    if not line.startswith("live:"):
        raise ParseError("Final line must start with 'live:'")

    rest_of_line = line[5:].strip()

    # Handle empty live set (the spec allows zero variables after 'live:')
    if not rest_of_line:
        return []

    live_vars = rest_of_line.split(',')

    # Clean whitespace and validate each variable name
    for i in range(len(live_vars)):
        live_vars[i] = live_vars[i].strip()
        if not is_valid_variable(live_vars[i]):
            raise ParseError(f"Invalid variable name: '{live_vars[i]}'")

    # Verify that each live variable appeared somewhere in the code
    for var in live_vars:
        found = False
        for op in operations:
            if var == op.destination or var == op.operand1 or var == op.operand2:
                found = True
                break
        if not found:
            raise ParseError(f"Variable '{var}' not found in code")

    return live_vars
