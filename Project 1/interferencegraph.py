import networkx as nx

#TODO: Cleanup and fix the code to work with our liveness analysis. Some assumptions taken here are that liveness is a set.
class InterferenceGraph:
    def __init__(self, live_sets):
        """
        live_sets: list of sets
                   Each set contains variables live at a program point.
                   for example:
                       [
                           {"a", "b"},
                           {"a", "t1"},
                           {"t1"},
                           {"b"},
                       ]
        """
        self.graph = nx.Graph()
        self.live_sets = live_sets

        self._add_nodes()
        self._add_edges()

    def _add_nodes(self):
        """Intenral method that adds all variables appearing in any liveness set as nodes."""
        all_vars = set()
        for live in self.live_sets:
            for var in live:
                all_vars.add(var)

        self.graph.add_nodes_from(all_vars)

    def _add_edges(self):
        """
        Internal method that adds an undirected edge between every 
        pair of variables that appear together in at least one live set.
        """
        for live in self.live_sets:
            live_list = list(live)

            for i in range(len(live_list)):
                for j in range(i + 1, len(live_list)):
                    v = live_list[i]
                    w = live_list[j]
                    self.graph.add_edge(v, w)

    def print_live_sets(self):
        '''Basic print debugger for our liveness set. This exists mostly for test cases and can be removed/ignored later.'''
        print("Live variable sets by program point:")
        for i, live in enumerate(self.live_sets):
            print(f"  Point {i}: {', '.join(sorted(live))}")
        print()


    def print_interference_graph(self):
        '''Interference graph printer for our interference graph. This prints out the nodes with all the edges, if they exist.'''
        print("Variable Interference Graph:")
        for var in sorted(self.graph.nodes()):
            neighbours = sorted(self.graph.neighbors(var))
            if neighbours:
                print(f"  {var}: {', '.join(neighbours)}")
            else:
                print(f"  {var}: (no interference)")
        print()