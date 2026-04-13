import io
from parser import readIntermediateCode
from interference import build_interference_graph, allocate_registers


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

def test_colouring_success():
    program = """a = 1
b = 2
c = a + b
live: c
"""
    code = readIntermediateCode(io.StringIO(program))
    code.compute_liveness_info()

    graph = build_interference_graph(code)

    success = allocate_registers(graph, 2)

    assert success is True
    assert len(graph.assignments) == len(graph.nodes)

def test_colouring_fail():
    program = """a = 1
b = 2
c = a + b
live: c
"""
    code = readIntermediateCode(io.StringIO(program))
    code.compute_liveness_info()

    graph = build_interference_graph(code)

    success = allocate_registers(graph, 1)

    assert success is False