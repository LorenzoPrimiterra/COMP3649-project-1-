import io
from parser import readIntermediateCode
from interference import build_interference_graph


def test_no_interference():
    program = """a = 1
b = 2
live:
"""
    code = readIntermediateCode(io.StringIO(program))
    code.compute_liveness_info()

    graph = build_interference_graph(code)

    assert len(graph.get_neighbors("a")) == 0
    assert len(graph.get_neighbors("b")) == 0


def test_interference():
    program = """a = a + 1
t1 = a * 2
b = t1 / 3
live: a, b
"""
    code = readIntermediateCode(io.StringIO(program))
    code.compute_liveness_info()

    graph = build_interference_graph(code)

    # a interferes with t1
    assert "t1" in graph.get_neighbors("a")
    assert "a" in graph.get_neighbors("t1")