"""
interference.py
===============
Builds a graph of variables that are alive at the same time and
therefore cannot share a register, then assigns registers to all
variables by colouring the graph.

Role in the Pipeline
--------------------
Receives the liveness-annotated code object from intermediate.py
and produces the final register assignments:

    intermediate.py  <- provides oplist, live_out, live_before, live_after
          |
    interference.py  <- builds interference graph from liveness sets
          |
    interference.py  <- colours the graph to assign registers
          |
    main.py          <- prints the final register assignments

Responsibilities
----------------
- Collect all variables that appear in the block.
- Build an undirected graph where an edge means two variables are alive
  at the same time and cannot share a register.
- Assign registers to variables by colouring the graph using backtracking.
- Provide safety checks to ensure no two connected variables share a register.

Out of Scope
------------
- Computing liveness (liveness.py).
- Parsing instructions (parser.py).
- Storing instructions or liveness results (intermediate.py).
- Generating assembly instructions (target.py).

Key Abstractions
----------------
InterferenceGraph
    Undirected graph where nodes are variables and edges represent
    interference — two variables that cannot share a register.

build_interference_graph(code)
    Constructs and returns an InterferenceGraph from a liveness-annotated
    IntermediateCode object.

allocate_registers(graph, num_regs)
    Attempts to colour the graph using at most num_regs colours via
    backtracking. Returns True if successful, False otherwise.

Dependencies
------------
- liveness.py : is_var() used to filter constants from variable lists.

Notes
-----
None.
"""

from typing import Set, Dict, List
from liveness import is_var


class InterferenceGraph:
    """
    Represents an undirected graph where nodes are variables.

    Core idea
    ---------
    - Each variable is a node.
    - An edge (u -- v) means u and v are interfering: they are live at the
      same time and therefore cannot share the same register.

    Internal representation
    -----------------------
    self.nodes stores an adjacency set::

        {
          "a": {"b", "t1"},
          "b": {"a"},
          ...
        }

    This is efficient because adding an edge is fast, checking neighbors
    is fast, and duplicates are automatically avoided by using sets.
    """

    def __init__(self, variables: List[str]):
        """
        Build an empty interference graph with a known set of variables.

        Parameters
        ----------
        variables : List[str]
            The variable names that should appear as nodes in the graph.

        Attributes
        ----------
        nodes : Dict[str, Set[str]]
            Adjacency set mapping each variable to its set of neighbors.
            Starts with no edges.
        assignments : Dict[str, int]
            Maps each variable to its assigned register number once
            colouring has been performed.
            Example: {"a": 0, "b": 1} means a -> R0, b -> R1.
        """
        self.nodes: Dict[str, Set[str]] = {var: set() for var in variables}
        self.assignments: Dict[str, int] = {}

    def add_edge(self, u: str, v: str):
        """
        Add an undirected edge between u and v.

        If u and v interfere they must not share the same register,
        so we connect them in the graph. Self-edges are ignored because
        a variable does not interfere with itself.

        Parameters
        ----------
        u : str
            First variable.
        v : str
            Second variable.

        Notes
        -----
        Assumes u and v are already nodes in self.nodes.
        """
        if u != v:
            self.nodes[u].add(v)
            self.nodes[v].add(u)

    def assign(self, var: str, color: int):
        """
        Assign a colour (register number) to a variable.

        Parameters
        ----------
        var : str
            Variable to colour.
        color : int
            Register index / colour number.

        Notes
        -----
        Does not validate safety. Call is_safe(var, color) first.
        """
        self.assignments[var] = color

    def unassign(self, var: str):
        """
        Remove the current colour assignment for a variable.

        Used during backtracking: if a partial assignment leads to a
        dead end, we undo the most recent choice and try a different colour.

        Parameters
        ----------
        var : str
            Variable whose assignment should be removed.
        """
        if var in self.assignments:
            del self.assignments[var]

    def get_unassigned_variable(self) -> str:
        """
        Find a variable that has not yet been assigned a colour.

        Returns
        -------
        str or None
            The first unassigned variable name, or None if all variables
            have been assigned. Order follows dictionary insertion order.
        """
        for var in self.nodes:
            if var not in self.assignments:
                return var
        return None

    def is_safe(self, var: str, color: int) -> bool:
        """
        Check whether assigning 'color' to 'var' would cause a conflict.

        A colour is safe if no neighbor of var currently holds that colour.

        Parameters
        ----------
        var : str
            Variable we want to colour.
        color : int
            The colour / register number to try.

        Returns
        -------
        bool
            True  -> no neighbor uses this colour; safe to assign.
            False -> at least one neighbor already has this colour.

        Example
        -------
        If neighbors(var) = {"b", "c"} and assignments = {"b": 1},
        then is_safe(var, 1) returns False because b already has colour 1.
        """
        for neighbor in self.get_neighbors(var):
            if self.assignments.get(neighbor) == color:
                return False
        return True

    def get_neighbors(self, var: str) -> Set[str]:
        """
        Return the set of neighbors for a variable.

        Parameters
        ----------
        var : str
            Variable name.

        Returns
        -------
        Set[str]
            The set of variables that interfere with 'var'.
            Returns an empty set if var is not found.
        """
        return self.nodes.get(var, set())

    def print_table(self):
        """
        Print the interference table in the required format.

        Output format::

            --- Variable Interference Table ---
            a: b, c
            b: a
            c: a

        Variables and neighbors are sorted for stable, readable output.
        """
        print("--- Variable Interference Table ---")
        for var in sorted(self.nodes.keys()):
            neighbors = sorted(list(self.nodes[var]))
            print(f"{var}: {', '.join(neighbors)}")


def build_interference_graph(code) -> InterferenceGraph:
    """
    Construct an InterferenceGraph using liveness analysis results.

    Parameters
    ----------
    code : IntermediateCode
        A liveness-annotated block. Must have:
        - code.oplist       : list of Operations
        - code.live_out     : variables live at block exit
        - code.live_before  : live_before[i] = vars live before instruction i
        - code.live_after   : live_after[i]  = vars live after instruction i

    Returns
    -------
    InterferenceGraph
        Graph with edges between all pairs of simultaneously-live variables.

    Algorithm
    ---------
    1. Collect all variables from destinations, operands, and live_out.
    2. Filter out non-variables (constants) using is_var().
    3. Create a graph with those variables as nodes.
    4. Add interference edges among variables live at the same point,
       using live_before[0] (entry) plus all live_after sets.
    """
    # 1. Identify all unique variables in the block
    all_vars = set(code.live_out)
    for op in code.oplist:
        all_vars.add(op.destination)
        if op.operand1:
            all_vars.add(op.operand1)
        if op.operand2:
            all_vars.add(op.operand2)

    # Filter to valid variables only (no constants); sort for consistent ordering
    valid_vars = sorted([v for v in all_vars if is_var(v)])

    graph = InterferenceGraph(valid_vars)

    # Add edges between all variables simultaneously live at each program point.
    # Include live_before[0] so variables live on entry also interfere.
    all_live_sets = [code.live_before[0]] + code.live_after if code.oplist else []
    for live_set in all_live_sets:
        live_list = list(live_set)
        for i in range(len(live_list)):
            for j in range(i + 1, len(live_list)):
                graph.add_edge(live_list[i], live_list[j])

    return graph


def allocate_registers(graph, num_regs):
    """
    Attempt register allocation via recursive backtracking graph colouring.

    Follows the same structure as the Eight Queens backtracking algorithm:
    pick an unassigned variable, try each colour in turn, recurse, and
    backtrack on failure.

    Parameters
    ----------
    graph : InterferenceGraph
        The interference graph to colour. Assignments are stored in-place.
    num_regs : int
        Number of registers (colours) available.

    Returns
    -------
    bool
        True if a valid colouring was found, False if the graph is not
        num_regs-colourable.
    """
    var = graph.get_unassigned_variable()
    if var is None:
        return True                                     # all variables assigned — success

    for colour in range(num_regs):
        if graph.is_safe(var, colour):
            graph.assign(var, colour)

            if allocate_registers(graph, num_regs):    # recurse
                return True

            graph.unassign(var)                        # backtrack

    return False                                        # no valid colour found


def print_register_colouring(assignments: dict, num_regs: int) -> None:
    """
    Print the register colouring table in the required format.

    Output format::

        R0: v1, v2
        R1: v3
        ...

    Parameters
    ----------
    assignments : dict
        Mapping from variable names to register numbers.
    num_regs : int
        Total number of registers (determines how many rows to print).
    """
    regs = {r: [] for r in range(num_regs)}
    for var, r in assignments.items():
        regs[r].append(var)

    for r in range(num_regs):
        regs[r].sort()
        print(f"R{r}: {', '.join(regs[r])}")
