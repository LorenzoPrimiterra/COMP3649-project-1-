import sys
from errors import ParseError
from parser import readIntermediateCode

def main() -> int:
    
    if len(sys.argv) != 2:
        print("Usage: python main.py <input_filename>", file=sys.stderr)
        return 2

    filename = sys.argv[1]

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

    return 0


if __name__ == "__main__":
    main()

