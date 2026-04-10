"""
Name: main.py
===============

Pipeline:
===========
The main.py drives the entire project and calls each associated stage:

    (1)  main.py          <- validates args, opens file, sequences all stages, etc.
          
    (2)  parser.py        <-  parses input into an IntermediateCode object.
          
    (3)  liveness.py      <-  annotates each instruction with live_before/live_after.
    
     (4) interference.py  <-  builds interference graph, performs register allocation.
          
    (5)  stdout           <- prints interference table and register assignments.

Responsibilities:
=====================
- Validates command-line arguments (num_regs must be a positive integer).
- Opens and passes the input file to the parserr.
- Triggers liveness analysis on the parsed code.
- Builds the interference graph and attempt register allocation
- Prints the interference table and final register assignments
- Returns appropriate exit codes (0 = success, 1 = allocation failed, 2 = bad input)



Associated Dependencies:
======================
(1) sys           <- for reading command-line args and writing to stderr
(2) errors.py    <- ParseError caught here to report malformed input files
(3) parser.py     <- readIntermediateCode() to turn the file into an object
(4) interference.py         <- build_interference_graph(), allocate_registers()

Usage Example:
================
    $ python main.py 3 my_program.txt

 Misc Notes:
================
- Exit code 0: allocation succeeded, assignments printed
- Exit code 1: allocation failed (not enough registers)
- Exit code 2: bad arguments or malformed input file


"""
import sys
from errors import ParseError
from parser import readIntermediateCode
from interference import build_interference_graph, allocate_registers, print_register_colouring
from codegen import generate_target

def main() -> int:
    
    if len(sys.argv) != 3:
        print("Usage: python main.py <num_regs> <input_filename>", file=sys.stderr)
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
   
    code.compute_liveness_info()

    graph = build_interference_graph(code)
    graph.print_table()
 
    success =  allocate_registers(graph, num_regs)     

    print_register_colouring(graph.assignments, num_regs)

    if success:
        print(f"SUCCESS: coloured with <= {num_regs} registers")
        target = generate_target(code, graph.assignments)

        out_file = filename + ".s"
        with open(out_file, "w") as f:
            f.write(str(target))
            
        print("Variable -> Register assignment:")

        for var in sorted(graph.assignments):  
            print(f"{var}: R{graph.assignments[var]}") 
        return 0
    else:
        print(f"FAILED: graph is not {num_regs}-colourable (not enough registers).")
        return 1
    

if __name__ == "__main__":
    sys.exit(main())

