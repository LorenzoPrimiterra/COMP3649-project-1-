"""
codegen.py
==========
Generates target assembly code from the intermediate three-address code
representation after register allocation has been completed.

Role in the Pipeline
--------------------
This module is the final translation stage of the imperative compiler backend.
It takes:
  - an IntermediateCode object containing the parsed three-address instructions
  - liveness information already computed for the block
  - register assignments already produced by graph colouring

It then generates a TargetCode object containing assembly instructions for
the target architecture.

Pipeline overview::

    parser.py        <- reads and validates the input file
          |
    intermediate.py  <- stores the three-address instruction sequence
          |
    liveness.py      <- computes live_before and live_after sets
          |
    interference.py  <- builds the interference graph and assigns registers
          |
    codegen.py       <- translates intermediate code into assembly language
          |
    target.py        <- stores and formats the generated assembly sequence
          |
    output file      <- written as <filename>.s

Responsibilities
----------------
- Translate each three-address instruction into equivalent assembly code.
- Use register assignments to map program variables to machine registers.
- Convert integer literals into immediate operands.
- Load variables that are live on entry into their assigned registers.
- Generate one or more target instructions for each intermediate instruction.
- Store modified variables that are live on exit back to memory.

Supported Intermediate-Code Forms
----------------------------------
This module handles the three instruction forms required by the project:

1. Simple assignment::

      dst = src

2. Unary negation::

      dst = -src

3. Binary arithmetic::

      dst = src1 op src2

   where op is one of: +, -, *, /

Target Architecture Assumptions
---------------------------------
The generated instructions follow the fictitious target CPU architecture
described in the project specification. Supported assembly operations::

    MOV src,Ri
    MOV Ri,dst
    ADD src,Ri
    SUB src,Ri
    MUL src,Ri
    DIV src,Ri

Operands may appear in:
  - immediate mode   (#n)
  - absolute mode    (variable name)
  - register mode    (Ri)

High-Level Algorithm
---------------------
For a given basic block, code generation proceeds in three steps:

1. Load live-on-entry variables from memory into their assigned registers.
2. Traverse the intermediate instruction sequence in program order and
   translate each instruction into one or more assembly instructions.
3. Store back any variables that are both live on exit and modified within
   the block.

Out of Scope
------------
- Parsing input files.
- Computing liveness information.
- Building the interference graph.
- Assigning registers.
- Performing register spilling.
- Performing assembly optimization.

Dependencies
------------
- intermediate.py : provides IntermediateCode and Operation.
- target.py       : provides TargetCode and AsmInstruction.
- liveness.py     : provides is_var() for distinguishing variables.
- errors.py       : provides code-generation-related exceptions.

Notes
-----
- This module assumes register allocation has already succeeded.
- The generated code is intended to be correct, not necessarily optimized.
- Redundant instructions such as MOV R0,R0 may still appear; these do not
  affect correctness and can be treated as a later optimization opportunity.
"""

from typing import Dict, Set, List
from intermediate import IntermediateCode, Operation
from target import TargetCode, AsmInstruction
from liveness import is_var
from errors import CodegenError, AssignmentError


def _reg(var: str, assignments: Dict[str, int]) -> str:
    """
    Return the register name assigned to an IR variable.

    Assumes register allocation has already succeeded. Enforces that every
    variable used during code generation has a valid register assignment.

    Parameters
    ----------
    var : str
        Variable name from the IR.
    assignments : Dict[str, int]
        Mapping from variable names to register numbers produced by
        graph colouring.

    Returns
    -------
    str
        The target register name (e.g., "R0", "R3").

    Raises
    ------
    AssignmentError
        If var is not in assignments, or the assigned value is not a
        non-negative integer.
    """
    if var not in assignments:
        raise AssignmentError(f"No register assignment for variable: {var!r}")

    regnum = assignments[var]
    if not isinstance(regnum, int) or regnum < 0:
        raise AssignmentError(f"Invalid register assignment for {var!r}: {regnum!r}")
    return f"R{regnum}"


def _is_int_literal(tok: str) -> bool:
    """
    Check whether a token represents an integer literal.

    Parameters
    ----------
    tok : str
        Token string from the IR.

    Returns
    -------
    bool
        True if the token can be parsed as an integer, False otherwise.
    """
    try:
        int(tok)
        return True
    except ValueError:
        return False


def _asm_operand(tok: str, assignments: Dict[str, int]) -> str:
    """
    Convert an IR operand into a target-assembly operand.

    Mapping::

        IR operand token -> assembly operand
        integer literal  -> '#n'
        variable         -> 'Rk'

    Parameters
    ----------
    tok : str
        Operand token from the IR.
    assignments : Dict[str, int]
        Variable-to-register assignment mapping.

    Returns
    -------
    str
        Assembly operand string (e.g., "#5", "R1").

    Raises
    ------
    CodegenError
        If tok is None or is neither an integer literal nor a variable.
    """
    if tok is None:
        raise CodegenError("Operand is None")
    if _is_int_literal(tok):
        return f"#{int(tok)}"
    if not is_var(tok):
        raise CodegenError(f"Unexpected operand token (not var or int): {tok!r}")
    return _reg(tok, assignments)


def _asm_operand_raw(tok: str) -> str:
    """
    Convert an IR operand into a non-register assembly operand.

    Always returns the memory/immediate form — never a register name.
    Used when reloading a value that was clobbered by a prior instruction.

    Parameters
    ----------
    tok : str
        Operand token from the IR.

    Returns
    -------
    str
        Immediate operand ("#n") for integer literals, or the variable
        name for variables (memory reference).

    Raises
    ------
    CodegenError
        If tok is None.
    """
    if tok is None:
        raise CodegenError("Operand is None")
    if _is_int_literal(tok):
        return f"#{int(tok)}"
    return tok


def op_to_asm(op: Operation, assignments: Dict[str, int]) -> List[AsmInstruction]:
    """
    Translate a single three-address IR instruction into target assembly.

    Supported IR forms
    ------------------
    - dst = src
    - dst = -src
    - dst = src1 op src2   (op in {+, -, *, /})

    Parameters
    ----------
    op : Operation
        The IR instruction to translate.
    assignments : Dict[str, int]
        Variable-to-register assignment mapping.

    Returns
    -------
    List[AsmInstruction]
        A list of one or more assembly instructions implementing the IR op.

    Raises
    ------
    CodegenError
        If the operator is unsupported or operand2 is missing for a binary op.
    """
    dst_r = _reg(op.destination, assignments)

    # dst = src  (simple assignment)
    if op.operator is None and not op.unary_neg:
        src = _asm_operand(op.operand1, assignments)
        if src == dst_r:
            return []
        return [AsmInstruction("MOV", src, dst_r)]

    # dst = -src  (unary negation)
    if op.unary_neg:
        src = _asm_operand(op.operand1, assignments)
        instrs = []
        if src != dst_r:
            instrs.append(AsmInstruction("MOV", src, dst_r))
        instrs.append(AsmInstruction("MUL", "#-1", dst_r))
        return instrs

    # dst = src1 op src2  (binary arithmetic)
    opcode_map = {"+": "ADD", "-": "SUB", "*": "MUL", "/": "DIV"}
    if op.operator not in opcode_map:
        raise CodegenError(f"Unsupported operator: {op.operator!r}")

    if op.operand2 is None:
        raise CodegenError("Binary operation missing operand2")

    src1 = _asm_operand(op.operand1, assignments)
    src2 = _asm_operand(op.operand2, assignments)
    asm_op = opcode_map[op.operator]

    # Case 1: src1 already in dst register — skip the MOV
    if src1 == dst_r:
        return [AsmInstruction(asm_op, src2, dst_r)]

    # Case 2: src2 is in dst register — MOV would clobber it
    if src2 == dst_r:
        # Commutative ops: swap operands
        if op.operator in {"+", "*"}:
            return [AsmInstruction(asm_op, src1, dst_r)]
        # SUB: negate then add  (dst holds src2; we want src1 - src2)
        if op.operator == "-":
            return [
                AsmInstruction("MUL", "#-1", dst_r),
                AsmInstruction("ADD", src1, dst_r),
            ]
        # DIV: reload src2 from memory/immediate after overwriting
        if op.operator == "/":
            src2_reload = _asm_operand_raw(op.operand2)
            return [
                AsmInstruction("MOV", src1, dst_r),
                AsmInstruction("DIV", src2_reload, dst_r),
            ]

    # Case 3: no conflict — standard two-instruction sequence
    return [
        AsmInstruction("MOV", src1, dst_r),
        AsmInstruction(asm_op, src2, dst_r),
    ]


def generate_target(code: IntermediateCode, assignments: Dict[str, int]) -> TargetCode:
    """
    Generate target assembly code for a single basic block.

    Algorithm
    ---------
    1. Load variables live on entry from memory into their assigned registers.
    2. Translate each IR operation into one or more assembly instructions.
    3. Store variables that are both live on exit and modified in the block
       back to memory.

    Parameters
    ----------
    code : IntermediateCode
        The IR basic block, including liveness information.
    assignments : Dict[str, int]
        Variable-to-register assignment mapping.

    Returns
    -------
    TargetCode
        Complete target assembly for the basic block.

    Raises
    ------
    CodegenError
        If liveness has not been computed before this function is called.
    """
    target = TargetCode()

    # --- 1) Live-on-entry loads ---
    if code.oplist:
        if code.live_before is None:
            raise CodegenError("Liveness not computed: call code.compute_liveness_info() first.")

        live_in = code.live_before[0]
        for v in sorted(live_in):
            if is_var(v):
                # MOV v,Rk  — load from memory into assigned register
                target.add(AsmInstruction("MOV", v, _reg(v, assignments)))

    # --- 2) Translate each instruction ---
    dirty: Set[str] = set()   # variables written within this block
    for op in code.oplist:
        dirty.add(op.destination)
        for instr in op_to_asm(op, assignments):
            target.add(instr)

    # --- 3) Live-on-exit stores ---
    live_out = set(code.live_out)
    # Store only variables that are both live on exit and modified in this block
    for v in sorted(live_out.intersection(dirty)):
        if is_var(v):
            # MOV Rk,v  — store register back to memory
            target.add(AsmInstruction("MOV", _reg(v, assignments), v))

    return target
