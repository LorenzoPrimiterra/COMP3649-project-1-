from typing import Set, Dict, List
from liveness import is_var

class InterferenceGraph:
    """
    Represents an undirected graph where nodes are variables.

    Core idea:
    - Each variable is a node.
    - An edge (u -- v) means u and v are "interfering":
      they are live at the same time, so they cannot share the same register.

    How we store the graph:
    - self.nodes is an adjacency set:
        {
          "a": {"b", "t1"},
          "b": {"a"},
          ...
        }
      This is efficient because:
      - adding an edge is fast
      - checking neighbors is fast
      - duplicates are automatically avoided by sets
    """

    def __init__(self, variables: List[str]):
        """
        Build an empty interference graph with a known set of variables.

        Parameters
        ----------
        variables : List[str]
            The variable names that should appear as nodes in the graph.

        What this initializes
        ---------------------
        self.nodes:
            A dictionary mapping each variable -> set of neighboring variables.
            We start with no edges, so each neighbor set begins empty.

        self.assignments:
            A dictionary mapping variable -> assigned register/color.
            Example: {"a": 0, "b": 1}
            Meaning: a gets register 0, b gets register 1.
        """
        # Use an adjacency set representation for the undirected graph
        self.nodes: Dict[str, Set[str]] = {var: set() for var in variables}
        # Track assigned registers: { "var_name": register_index }
        self.assignments: Dict[str, int] = {}

    def add_edge(self, u: str, v: str):
        """
        Add an undirected edge between u and v.

        Meaning:
        - If u and v interfere, they must not share the same register,
          so we connect them in the graph.

        Why we check u != v:
        - A variable does not interfere with itself, so we ignore self-edges.

        Important:
        - This assumes u and v are already nodes in self.nodes.
          (They should be, since we build the graph from a full variable list.)
        """
        if u != v:
            self.nodes[u].add(v)
            self.nodes[v].add(u)
    
    def assign(self, var: str, color: int):
        """
        Assign a 'color' (register number) to a variable.

        Parameters
        ----------
        var : str
            Variable to color.
        color : int
            Register index / color number.

        Example:
        - assign("a", 2) means variable "a" gets register #2.

        This doesn't check safety by itself.
        - Typically, you call is_safe(var, color) first.
        """
        self.assignments[var] = color

    def unassign(self, var: str):
        """
        Remove the current color assignment for a variable.

        Why this exists:
        - Graph coloring is often solved using backtracking.
        - During backtracking, if an assignment fails later,
          we need to undo the assignment and try a different color.

        Example flow:
        - assign("a", 0)
        - later we realize it causes a conflict
        - unassign("a") to remove that choice
        """
        if var in self.assignments:
            del self.assignments[var]
    
    def get_unassigned_variable(self) -> str:
        """
        Find a variable that has not been assigned a color yet.

        Returns
        -------
        str or None
            - Returns the first variable name that is not in self.assignments.
            - Returns None if all variables have been assigned.

        Note:
        - "First" here depends on dictionary iteration order.
          Since Python preserves insertion order, it will follow the order
          variables were inserted into self.nodes.
        """
        for var in self.nodes:
            if var not in self.assignments:
                return var
        return None

    def is_safe(self, var: str, color: int) -> bool:
        """
        Check whether assigning 'color' to 'var' would violate interference rules.

        Rule:
        - If any neighbor of var already has the same color, it's NOT safe.

        Parameters
        ----------
        var : str
            Variable we want to color.
        color : int
            The color/register we want to try.

        Returns
        -------
        bool
            True  -> no neighbor currently uses this color, so it's safe.
            False -> at least one neighbor has this color, so conflict.

        Example:
        - If neighbors(var) = {"b", "c"} and assignments = {"b": 1}
          then is_safe(var, 1) returns False (because b already has 1).
        """
        for neighbor in self.get_neighbors(var):
            if self.assignments.get(neighbor) == color:
                return False
        return True

    def get_neighbors(self, var: str) -> Set[str]:
        """
        Get the set of neighbors for a variable.

        Parameters
        ----------
        var : str
            Variable name.

        Returns
        -------
        Set[str]
            The set of variables that interfere with 'var'.

        Why use .get(var, set()):
        - If var isn't found (shouldn't happen if graph built correctly),
          return an empty set instead of crashing.
        """
        return self.nodes.get(var, set())

    def print_table(self):
        """
        Print the interference table in the required format.

        Required output format:
            name: var1, var2, ...

        Example:
            a: b, c
            b: a
            c: a

        Notes:
        - We sort variables and neighbors so the output is stable and readable.
        - This helps debugging, because you get the same ordering each run.
        """
        print("--- Variable Interference Table ---")
        for var in sorted(self.nodes.keys()):
            neighbors = sorted(list(self.nodes[var]))
            print(f"{var}: {', '.join(neighbors)}")

def build_interference_graph(code) -> InterferenceGraph:
    """
    Construct an InterferenceGraph using liveness analysis results.

    What we assume 'code' contains
    ------------------------------
    code.oplist:
        List of operations (three-address code instructions).
        Each op has:
          - op.destination
          - op.operand1
          - op.operand2

    code.live_out:
        Variables live at the end of the block.

    code.live_before:
        A list where live_before[i] is the set of vars live BEFORE instruction i.

    code.live_after:
        A list where live_after[i] is the set of vars live AFTER instruction i.

    High-level plan
    ---------------
    1) Collect all variables that might appear in the block (dest + operands + live_out)
    2) Filter out non-variables (constants) using is_var(...)
    3) Create a graph with those variables as nodes
    4) Add interference edges:
       - among variables live at entry (live_before[0]) if present
       - among variables simultaneously live in each live_after set
    """
    # 1. Identify all unique variables in the block
    all_vars = set(code.live_out)
    for op in code.oplist:
        all_vars.add(op.destination)
        if op.operand1: all_vars.add(op.operand1)
        if op.operand2: all_vars.add(op.operand2)
    
    # Filter to ensure only valid variables are nodes (no constants)
    # Using a list comprehension to maintain consistent ordering
    valid_vars = sorted([v for v in all_vars if is_var(v)])
    
    graph = InterferenceGraph(valid_vars)

    if code.live_before:
        entry_vars = list(code.live_before[0])
        for i in range(len(entry_vars)):
            for j in range(i + 1, len(entry_vars)):
                graph.add_edge(entry_vars[i], entry_vars[j])

    # 2. Add edges based on overlapping liveness 
    # A variable interferes with everything else live at the same point.
    for live_set in code.live_after:
        live_list = list(live_set)
        for i in range(len(live_list)):
            for j in range(i + 1, len(live_list)):
                graph.add_edge(live_list[i], live_list[j])
                
    return graph

def allocate_registers(graph, num_regs):
    """
    A recursive function to solve the register allocation puzzle.
    Closely follows the Eight Queens 'placeQueensSafely' logic.
    """

    var = graph.get_unassigned_variable()         
    if var is None:
        return True                                    # A solution has been found
    
    for colour in range(num_regs):                     # checking all possible combinations of registers over the graph

        if graph.is_safe(var, colour):                 # If valid, an assignment is made
            graph.assign(var, colour)

            if  allocate_registers(graph, num_regs):   #Recursive call -- if it was valid return true 
                return True
            graph.unassign(var)                        # if not, we unassign and try again 

    return False                                       # false if all fails 

def print_register_colouring(assignments: dict, num_regs: int) -> None:
    """
    Prints the register colouring table in the required format:
      R0: v1, v2
      R1: v3
      ...
    """
    regs = {r: [] for r in range(num_regs)}
    for var, r in assignments.items():
        regs[r].append(var)

    for r in range(num_regs):
        regs[r].sort()
        print(f"R{r}: {', '.join(regs[r])}")