# Register Allocator (Haskell (v2))

A rework of the python compiler that takes a basic block of three-address intermediate code,
performs liveness analysis and interference-graph register allocation, and emits
target assembly for a simple fictitious CPU.

## What it does:

Given an input file like:

    t1 = a * 4
    t2 = t1 + 1
    b  = t2 - a
    live: b

### It performs the following actions:

1. Parses the instructions and the live-out set.

2. Computes liveness at each program point (backwards pass).

3. Builds an interference graph — variables alive at the same time cannot share a register.

4. Colors the graph via backtracking to assign registers.

5. Translates the IR into assembly and writes a .s file.


## Input Usage:

`./gen <num_regs> <input_file>`

### Examples:

    ./gen 3 example.txt
    ./gen 2 example.txt

## Output codes:
|    Code |        Meaning|
|---------|-------------|
|0|          Success — assembly written to <input_file>.s|
|1|          Allocation failed — graph is not k-colourable|
|2|          Bad arguments or malformed input file|

## Operation Input format:
    dst = src
    dst = -src
    dst = src1 op src2
    live: v1, v2, ... etc.

- Destinations  must be valid variable names (see naming rules below).
- Operands      may be variable names or integer literals.
- Operators     are +, -, *, /.
- NOTE:         The final line must be 'live:' followed by a comma-separated
                list of live-out variables. An empty live set ('live:') is valid.

## Variable naming rules:

- A single lowercase letter other than 't' — e.g. a, b, x
- The letter 't' followed by one or more digits — e.g. t1, t2, t10

## Output:

Printed to stdout in this order:

    --- Variable Interference Table ---
    a: b, t1
    b: a
    t1: a
    R0: a
    R1: b, t1
    SUCCESS: coloured with <= 2 registers
    Variable -> Register assignment:
    a: R0
    b: R1
    t1: R1

On success assembly is also written to <input_file>.s

## Pipeline:
|File (in order)|Job|
|------|----|
| Parser.hs|          reads and validates the input file.|
| Intermediate.hs|    stores the three-address instruction sequence.|
| Liveness.hs |        computes live_before and live_after sets.|
| Interference.hs  |  builds the interference graph and assigns registers.|
| CodeGen.hs|         translates IR into assembly language.|
| Target.hs|          stores and formats the generated assembly.|
| <input_file>.s |         output assembly file.|


## Differences from the Python version:

- Error handling uses Control.Exception.try instead of custom exception classes —
  there is no separate errors module; parse errors are raised via 'error' in Parser.hs
  and caught in Main.hs
- readFile is lazy, so Main.hs forces full evaluation via evaluate and
  showIntermediateCode to ensure parse errors surface at the right stage
- ADT constructors for Operation, IntermediateCode, AsmInstruction, and
  TargetCode are hidden; all creation goes through exported smart constructors


## Supported assembly instructions:

    MOV src,Ri      load into register
    MOV Ri,dst      store from register
    ADD src,Ri
    SUB src,Ri
    MUL src,Ri
    DIV src,Ri


## Building and running:

    ghc -o gen Main.hs
    ./gen 3 test.txt
