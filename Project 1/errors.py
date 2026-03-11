"""
errors.py
================
Defines a custom exception that is raised whenever the input file is malformed. 

Role in the Pipeline
--------------------
Supporting helper files.

Responsibilities
----------------
NA 

Out of Scope
------------
NA

Key Abstractions
----------------
class ParseError(Exception):
    Raised when the input file format is invalid.

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

class ParseError(Exception):
    """Raised when the input file format is invalid."""
    pass

class CodegenError(Exception):
    """
    Raised when IR-to-assembly generation fails due to an unexpected IR shape
    or inconsistent register assignments.
    Examples:
      - operand2 is None for a binary op
      - unknown operator
      - token is neither int literal nor variable
      - variable missing from assignments map
    """
    pass


class AssignmentError(Exception):
    """
    Raised when register assignments are missing or inconsistent.
    Examples:
      - assignments[var] KeyError because graph didn't assign a register
      - assignment value is not an int
    """
    pass