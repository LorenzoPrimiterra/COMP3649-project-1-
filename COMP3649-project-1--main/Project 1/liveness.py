"""
liveness.py
===========
Computes which variables are "alive" at each point in a block
of instructions — a variable is alive if its current value will
be needed by a future instruction.

Role in the Pipeline
--------------------
Called by intermediate.py after the block has been parsed:

    intermediate.py  <- triggers liveness via compute_liveness_info()
          |
    liveness.py      <- walks instructions backwards, fills live_before/live_after
          |
    intermediate.py  <- stores the results back onto the code object
          |
    interference.py  <- reads live_before/live_after to build the interference graph

Responsibilities
----------------
- Determine which variables are defined (written) by each instruction.
- Determine which variables are used (read) by each instruction.
- Walk backwards through the instruction list to compute liveness sets.
- Return live_before and live_after aligned with the instruction list.
- Distinguish variables from constants so constants are never tracked.

Out of Scope
------------
- Storing liveness results (intermediate.py).
- Parsing instructions (parser.py).
- Building interference graphs or assigning registers (interference.py).
- Generating assembly instructions (target.py).

Key Abstractions
----------------
is_var(tok)
    Returns True if a token is a variable name rather than a constant.

defs(op)
    Returns the set of variables written by an instruction.

uses(op)
    Returns the set of variables read by an instruction.

compute_liveness(ops, live_out)
    Walks backwards through the instruction list and returns
    live_before and live_after for each instruction.

Dependencies
------------
- intermediate.py : Operation objects are passed in and read here.

Notes
-----
- Liveness is computed in a single backwards pass since the input
  is a single basic block with no branches or loops.
- Constants are intentionally ignored — only variables have live ranges.
"""

from typing import List, Set, Tuple
from intermediate import Operation


def is_var(tok: str) -> bool:
    """
    Return True if 'tok' matches a variable name in our IR.

    Why this is needed
    ------------------
    Operands can be variables OR constants.
    - Variables (a, b, t1, ...) matter for liveness.
    - Constants (0, 10, 3, ...) do not — they don't need to be preserved.

    Variable naming rules (based on project spec)
    ---------------------------------------------
    - Temporaries : t<digits>  e.g., t1, t2, t10
    - Named vars  : single lowercase letter (except plain "t")  e.g., a, b, x

    Parameters
    ----------
    tok : str
        Token from the IR to classify.

    Returns
    -------
    bool
        True if tok is a variable name, False if it is a constant.
    """
    if tok.startswith("t") and tok[1:].isdigit():
        return True
    if len(tok) == 1 and tok.islower() and tok != "t":
        return True
    return False


def defs(op: Operation) -> Set[str]:
    """
    Return the set of variables DEFINED (written) by this instruction.

    In three-address code every instruction has the form:
        destination = ...
    so the destination always receives a new value and is therefore a def.

    Parameters
    ----------
    op : Operation
        The instruction to inspect.

    Returns
    -------
    Set[str]
        A singleton set containing the destination variable.

    Example
    -------
        x = a + b   ->  defs = {x}
    """
    return {op.destination}


def uses(op: Operation) -> Set[str]:
    """
    Return the set of variables USED (read) by this instruction.

    Any variable appearing on the right-hand side is a use because the
    instruction needs its current value to compute the result.
    Constants are excluded because they have no live range.

    Parameters
    ----------
    op : Operation
        The instruction to inspect.

    Returns
    -------
    Set[str]
        The set of variable names read by this instruction.

    Examples
    --------
        a = b + c   ->  uses = {b, c}
        t1 = 10     ->  uses = {}
        x = -y      ->  uses = {y}
    """
    u: Set[str] = set()
    if op.operand1 is not None and is_var(op.operand1):
        u.add(op.operand1)
    if op.operand2 is not None and is_var(op.operand2):
        u.add(op.operand2)
    return u


def compute_liveness(
    ops: List[Operation],
    live_out: Set[str],
) -> Tuple[List[Set[str]], List[Set[str]]]:
    """
    Return (live_before, live_after) aligned with ops.

    Performs a single backwards pass over the instruction list, computing
    liveness sets using the standard dataflow equations:

        live_after[i]  = live_before[i+1]   (or live_out for the last instruction)
        live_before[i] = uses(ops[i]) | (live_after[i] - defs(ops[i]))

    Parameters
    ----------
    ops : List[Operation]
        The instruction sequence in program order.
    live_out : Set[str]
        Variables live at the exit of the block.

    Returns
    -------
    live_before : List[Set[str]]
        live_before[i] = variables live immediately before ops[i].
    live_after : List[Set[str]]
        live_after[i]  = variables live immediately after ops[i].
    """
    n = len(ops)
    live_before: List[Set[str]] = [set() for _ in range(n)]
    live_after:  List[Set[str]] = [set() for _ in range(n)]

    current_live = set(live_out)   # what is live after the end of the block

    # Walk bottom to top
    for i in range(n - 1, -1, -1):
        live_after[i] = set(current_live)

        d = defs(ops[i])
        u = uses(ops[i])

        live_before[i] = u | (live_after[i] - d)

        # Move up one instruction
        current_live = live_before[i]

    return live_before, live_after
