# Register Allocator — Haskell Implementation

A compiler backend that takes a basic block of three-address intermediate code,
performs liveness analysis and interference-graph register allocation, and emits
target assembly for a simple fictitious CPU.

This is a direct Haskell port of the Python implementation, with each `.hs`
module mapping one-to-one to its `.py` counterpart.

---

## What it does

Given an input file like:

```
t1 = a * 4
t2 = t1 + 1
b  = t2 - a
live: b
```

and a register count, the program:

1. Parses the instructions and the live-out set
2. Computes liveness at each program point (backwards pass using `foldr`)
3. Builds an interference graph — variables alive at the same time cannot share a register
4. Colours the graph via backtracking to assign registers
5. Translates the IR into assembly and writes a `.s` file

---

## Building

The project uses **Stack**.

```bash
stack build
```

To run directly with Stack:

```bash
stack run -- <num_regs> <input_file>
```

Or build and invoke the binary directly:

```bash
stack build
stack exec gen -- <num_regs> <input_file>
```

---

## Usage

```
gen <num_regs> <input_file>
```

**Examples:**

```bash
stack run -- 3 example.txt
stack run -- 2 example.txt
```

**Exit codes:**

| Code | Meaning |
|------|---------|
| 0    | Success — assembly written to `<input_file>.s` |
| 1    | Allocation failed — graph is not k-colourable |
| 2    | Bad arguments or malformed input file |

---

## Input format

```
dst = src
dst = -src
dst = src1 op src2
live: v1, v2, ...
```

- **Destinations** must be valid variable names (see naming rules below).
- **Operands** may be variable names or integer literals.
- **Operators** are `+`, `-`, `*`, `/`.
- The final line must be `live:` followed by a comma-separated list of live-out variables. An empty live set (`live:`) is valid.

**Variable naming rules:**
- A single lowercase letter other than `t` — e.g. `a`, `b`, `x`
- The letter `t` followed by one or more digits — e.g. `t1`, `t2`, `t10`

---

## Output

**Stdout** — printed in this order:

```
--- Variable Interference Table ---
a: b, t1
b: a
t1: a
R0: a
R1: b t1
SUCCESS: coloured with <= 2 registers
Variable -> Register assignment:
a: R0
b: R1
t1: R1
```

**`<input_file>.s`** — the generated assembly, e.g.:

```
MOV a,R0
MOV t1,R1
MUL #4,R1
...
MOV R1,b
```

---

## Pipeline

```
Parser.hs       reads and validates the input string
    ↓
Intermediate.hs stores the three-address instruction sequence
    ↓
Liveness.hs     computes live_before and live_after sets (foldr)
    ↓
Interference.hs builds the interference graph and assigns registers
    ↓
CodeGen.hs      translates IR into assembly language
    ↓
Target.hs       stores and formats the generated assembly
    ↓
<input>.s       written to disk
```

---

## Module overview

| File | Maps to | Responsibility |
|------|---------|---------------|
| `Main.hs` | `main.py` | Entry point — validates args, sequences all stages, handles exit codes |
| `Parser.hs` | `parser.py` | Tokenises and validates each instruction line; parses the `live:` line |
| `Intermediate.hs` | `intermediate.py` | `Operation` and `IntermediateCode` ADTs with smart constructors and accessors |
| `Liveness.hs` | `liveness.py` | Single backwards pass (`foldr`) to compute `live_before` / `live_after` |
| `Interference.hs` | `interference.py` | Builds the interference graph; backtracking graph colouring |
| `CodeGen.hs` | `codegen.py` | Translates each IR instruction into assembly; handles register conflicts |
| `Target.hs` | `target.py` | `AsmInstruction` and `TargetCode` ADTs; formats the `.s` output |
| `Lib.hs` | — | Stack boilerplate (unused) |

---

## Key design notes

**Pure functions throughout.** `Liveness`, `Interference`, `CodeGen`, and
`Target` are all pure — they take values in and return values out with no
`IO`. Only `Main` does I/O.

**Lazy evaluation and error handling.** Haskell's laziness means that
`readIR` can return a value before any of its fields are evaluated. `Main`
forces full evaluation via `evaluate (length (showIntermediateCode code))`
so that parse errors are caught by `try` at the right place, rather than
surfacing later as unhandled exceptions.

**ADTs with hidden constructors.** `Intermediate`, `Target`, and
`Interference` hide their data constructors and expose only smart
constructors and accessor functions. This keeps the interface stable if
the internal representation changes.

**`foldr` for liveness.** The backwards pass in `Liveness.computeLiveness`
uses `foldr`, which naturally processes the list from right to left. The
accumulator carries `(current_live, pairs)` and builds the result list in
forward order using `(:)`.

---

## Supported assembly instructions

```
MOV src,Ri      load into register
MOV Ri,dst      store from register
ADD src,Ri
SUB src,Ri
MUL src,Ri
DIV src,Ri
```

Operand modes: immediate (`#n`), absolute (variable name), register (`Ri`).

---

## Clobber handling in CodeGen

When translating `dst = src1 op src2`, the destination register may already
hold one of the source values. Three cases are handled:

- **src1 == dstR** — skip the `MOV`, emit `OP src2,dstR` directly.
- **src2 == dstR** — would be clobbered by the leading `MOV`:
  - `+`, `*` — commutative; swap operands.
  - `-` — negate `dstR` then add `src1`.
  - `/` — reload `src2` from memory/immediate after writing `src1` to `dstR`.
- **no conflict** — standard `MOV src1,dstR` then `OP src2,dstR`.

---

## GHCi testing

Individual modules can be loaded and tested in GHCi:

```bash
# Test Intermediate
ghci Intermediate.hs
showOperation (mkBinOp "t1" "a" "*" "4")
putStr (showIntermediateCode (mkIntermediateCode [mkBinOp "a" "a" "+" "1"] ["a"]))

# Test Target
ghci Target.hs
showAsmInstruction (mkAsmInstruction "ADD" (Just "#1") (Just "R0"))

# Test the full pipeline
stack run -- 3 example.txt
cat example.txt.s
```