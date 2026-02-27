"""
main.py
================
Entry point and top-level orchestrator for the register allocator.

Role in the Pipeline
--------------------
main.py drives the entire pipeline by invoking each stage in order:

    Command-line args    (input)
          ↓
      main.py          ← validates args, opens file, sequences all stages
          ↓
      parser.py        ← parses input into an IntermediateCode object
          ↓
      liveness.py      ← annotates each instruction with live_before/live_after
          ↓
      interference.py  ← builds interference graph, performs register allocation
          ↓
      stdout           ← prints interference table and register assignments

Responsibilities
----------------
- Validate command-line arguments (num_regs must be a positive integer)
- Open and pass the input file to the parserr
- Trigger liveness analysis on the parsed code
- Build the interference graph and attempt register allocation
- Print the interference table and final register assignments
- Return appropriate exit codes (0 = success, 1 = allocation failed, 2 = bad input)

Out of Scope
------------
- Parsing or validating instruction syntax (parser.py)
- Liveness computation logic (liveness.py)
- Interference graph construction or graph coloring (interference.py)
- Defining data structures (intermediate.py)

Key Abstractions
----------------
main()
    The sole function in this module. Sequences all pipeline stages and
    controls program output and exit codes.

Dependencies
------------
- sys          : for reading command-line args and writing to stderr
- errors.py    : ParseError caught here to report malformed input files
- parser.py    : readIntermediateCode() to turn the file into an object
- interference.py : build_interference_graph(), allocate_registers()

Usage Example
-------------
    $ python main.py 3 my_program.txt

Notes
-----
- Exit code 0: allocation succeeded, assignments printed
- Exit code 1: allocation failed (not enough registers)
- Exit code 2: bad arguments or malformed input file

"""

import sys
from errors import ParseError
from parser import readIntermediateCode
from interference import build_interference_graph, allocate_registers

def main() -> int:
    
    if len(sys.argv) != 3:
        print("Usage: python main.py <input_filename>", file=sys.stderr)
        return 2
    
    try:                                                    # Requirement: Argument one must be an integer > 0
        num_regs = int(sys.argv[1])
        if num_regs <= 0:
            raise ValueError
    except ValueError:
        print("Error: <num_regs> must be a positive integer", file=sys.stderr)
        return 2

    filename = sys.argv[2]

    try:
        with open(filename, "r") as f:
            code = readIntermediateCode(f)
    except FileNotFoundError:
        print(f"Error: file not found: {filename}", file=sys.stderr)
        return 2
    except ParseError as e:
        print(f"Parse error: {e}", file=sys.stderr)
        return 2
   
    print(code)
    code.compute_liveness_info()

    for i, op in enumerate(code.oplist):                    # code section is to see output clearly 
        print(f"{i}: {op}")
        print("  before:", sorted(code.live_before[i]))
        print("  after :", sorted(code.live_after[i]))      # REMOVE BEFORE SUBMISSION

    graph = build_interference_graph(code)
    graph.print_table()
 
    success =  allocate_registers(graph, num_regs)     

    if success:
        for var in sorted(graph.assignments):  
            print(f"{var}: R{graph.assignments[var]}") 
        return 0
    else:
        print("Failed.")
        return 1
    

if __name__ == "__main__":
    main()

