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

