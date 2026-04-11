"""
Name: errors.py
================
Defines a custom exception that is raised whenever the input file is malformed. 

Pipeline:
=======================
Supporting helper files.

Associated Responsibilities:
========================
NA 

Dependencies:
==================
NA

Usage Example:
================
NA 

Misc Notes:
=============
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
