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