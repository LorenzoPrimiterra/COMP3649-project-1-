# Register Allocator — Python Implementation

A compiler backend that takes a basic block of three-address intermediate code,
performs liveness analysis and interference-graph register allocation, and emits
target assembly for a simple fictitious CPU.

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
2. Computes liveness at each program point (backwards pass)
3. Builds an interference graph — variables alive at the same time cannot share a register
4. Colours the graph via backtracking to assign registers
5. Translates the IR into assembly and writes a `.s` file

---

## Usage

```
python main.py <num_regs> <input_file>
```

**Examples:**

```bash
python main.py 3 example.txt
python main.py 2 example.txt
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
R1: b, t1
SUCCESS: coloured with <= 2 registers
Variable -> Register assignment:
a: R0
b: R1
t1: R1
```

**`<input_file>.s`** — the generated assembly, e.g.:

```
MOV a,R0
MOV b,R1
MOV R0,t1
MUL #4,t1
...
MOV t1,b
```

---

## Pipeline

```
parser.py       reads and validates the input file
    ↓
intermediate.py stores the three-address instruction sequence
    ↓
liveness.py     computes live_before and live_after sets
    ↓
interference.py builds the interference graph and assigns registers
    ↓
codegen.py      translates IR into assembly language
    ↓
target.py       stores and formats the generated assembly
    ↓
<input>.s       written to disk
```

---

## Module overview

| File | Responsibility |
|------|---------------|
| `main.py` | Entry point — validates args, sequences all stages, handles exit codes |
| `parser.py` | Tokenises and validates each instruction line; parses the `live:` line |
| `intermediate.py` | `Operation` and `IntermediateCode` data classes |
| `liveness.py` | Single backwards pass to compute `live_before` / `live_after` |
| `interference.py` | Builds the interference graph; backtracking graph colouring |
| `codegen.py` | Translates each IR instruction into assembly; handles register conflicts |
| `target.py` | `AsmInstruction` and `TargetCode` data classes; formats the `.s` output |
| `errors.py` | `ParseError`, `CodegenError`, `AssignmentError` exception classes |

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

## Clobber handling in codegen

When translating `dst = src1 op src2`, the destination register may already
hold one of the source values. Three cases are handled:

- **src1 == dstR** — skip the `MOV`, emit `OP src2,dstR` directly.
- **src2 == dstR** — would be clobbered by the leading `MOV`:
  - `+`, `*` — commutative; swap operands.
  - `-` — negate `dstR` then add `src1`.
  - `/` — reload `src2` from memory/immediate after writing `src1` to `dstR`.
- **no conflict** — standard `MOV src1,dstR` then `OP src2,dstR`.

---

## Running the tests

There is no dedicated test runner included. A quick sanity check:

```bash
echo "t1 = a * 4
t2 = t1 + 1
b = t2 - a
live: b" > test.txt

python main.py 3 test.txt
cat test.txt.s
```
