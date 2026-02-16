class GraphColouring:
    def __init__(self, graph, num_registers):
        self.graph = graph
        self.num_registers = num_registers
        self.colouring = {}  # based on num_registers


    def colour(self):
        return self._backtrack()

    # ---------- Helper Methods ----------

    def _backtrack(self):
        if self._all_coloured():
            return True

        var = self._select_next_variable()

        for reg in range(self.num_registers):
            if self._can_use_colour(var, reg):
                self.colouring[var] = reg

                if self._backtrack():
                    return True

                del self.colouring[var]  # this does the backtracking that we needed to do

        return False

    def _all_coloured(self):
        return len(self.colouring) == self.graph.number_of_nodes()

    def _can_use_colour(self, var, reg):
        for neighbour in self.graph.neighbors(var):
            if self.colouring.get(neighbour) == reg:
                return False
        return True

    def _select_next_variable(self):
        uncoloured = [
            v for v in self.graph.nodes()
            if v not in self.colouring
        ]

        best_var = None
        best_score = (-1, -1) 

        for v in uncoloured:
            used_colours = set()
            for n in self.graph.neighbors(v):
                if n in self.colouring:
                    used_colours.add(self.colouring[n])

            saturation = len(used_colours)
            degree = self.graph.degree(v)

            score = (saturation, degree)

            if score > best_score:
                best_score = score
                best_var = v

        return best_var
