from typing import List, Set, Tuple
from intermediate import Operation

def is_var(tok: str) -> bool:
    """
    Return True if 'tok' matches a VARIABLE name in our IR.

    Why we need this:
      Operands can be variables OR constants.
      - variables (a, b, t1, ...) matter for liveness
      - constants (0, 10, 3, ...) do NOT (they don't need to be preserved)

    Assumed naming rules (based on project examples/spec):
      - temporaries: t<digits>  e.g., t1, t2, t10
      - named vars: single lowercase letter (except plain "t") e.g., a, b, x

    If the course spec allows multi-letter names, update this function.
    """
    if tok.startswith("t") and tok[1:].isdigit():
        return True
    if len(tok) == 1 and tok.islower() and tok != "t":
        return True
    return False

def defs(op: Operation) -> Set[str]:
    """
    Return the set of variables DEFINED (written) by this instruction.

    In 3-address code, every instruction has form:
        destination = ...
    So destination always gets a new value => it is a "def".

    Variables whose old values are overwritten here.
    Example: 
        x = a + b   -> defs = {x} (the old value of x is gone after this line)

    We return a set (even though it's one variable) because the liveness
    equation is written using set operations.
    """    
    # destination is always a variable by spec
    return {op.destination}

def uses(op: Operation) -> Set[str]:
    """
    Return the set of variables USED (read) by this instruction.

    Any variable appearing on the right-hand side is a "use" because the
    instruction needs its current value to compute the result.

    Examples:
      a = b + c   -> uses = {b, c}
      t1 = 10     -> uses = {}
      x = -y      -> uses should include y (depends on how parser stores unary minus)

    Important:
      We ignore constants, because constants don't have "live ranges".
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
    Returns (live_before, live_after) aligned with ops.

    live_before[i] = vars live right before ops[i]
    live_after[i]  = vars live right after  ops[i]
    """
    n = len(ops)
    live_before: List[Set[str]] = [set() for i in range(n)]
    live_after:  List[Set[str]] = [set() for i in range(n)]

    current_live = set(live_out)   # what's live after the end of the block

    # walk bottom -> top
    for i in range(n - 1, -1, -1):
        live_after[i] = set(current_live)

        d = defs(ops[i])
        u = uses(ops[i])

        live_before[i] = u | (live_after[i] - d)

        # move up
        current_live = live_before[i]

    return live_before, live_after

