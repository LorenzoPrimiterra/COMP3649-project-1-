"""
errors.py
=========
Defines custom exceptions raised when input is malformed or code
generation fails unexpectedly.

Role in the Pipeline
--------------------
Supporting helper module used by parser.py and codegen.py.

Responsibilities
----------------
- Provide ParseError for malformed input files.
- Provide CodegenError for unexpected IR shapes during assembly generation.
- Provide AssignmentError for missing or inconsistent register assignments.

Out of Scope
------------
- Parsing input files.
- Computing liveness.
- Building interference graphs or assigning registers.
- Generating assembly instructions.

Key Abstractions
----------------
ParseError
    Raised when the input file format is invalid.

CodegenError
    Raised when IR-to-assembly translation fails due to an unexpected
    IR shape or unsupported operator.

AssignmentError
    Raised when a variable is missing from the register assignment map,
    or when the assignment value is not a valid integer.

Dependencies
------------
None.

Notes
-----
None.
"""


class ParseError(Exception):
    """Raised when the input file format is invalid."""
    pass


class CodegenError(Exception):
    """
    Raised when IR-to-assembly generation fails due to an unexpected IR
    shape or inconsistent register assignments.

    Examples
    --------
    - operand2 is None for a binary op
    - unknown operator symbol
    - token is neither an integer literal nor a variable
    - variable missing from the assignments map
    """
    pass


class AssignmentError(Exception):
    """
    Raised when register assignments are missing or inconsistent.

    Examples
    --------
    - assignments[var] raises KeyError because graph colouring did not
      assign a register to this variable
    - assignment value is not an integer
    """
    pass
