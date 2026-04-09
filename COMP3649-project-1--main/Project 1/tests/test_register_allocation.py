import io
from parser import readIntermediateCode
from interference import build_interference_graph, allocate_registers


def test_allocation_success():
    program = """a = 1
b = 2
c = 3
live: a, b, c
"""
    code = readIntermediateCode(io.StringIO(program))
    code.compute_liveness_info()
    graph = build_interference_graph(code)

    success = allocate_registers(graph, 3)
    assert success


def test_allocation_fail():
    program = """a = 1
b = 2
c = 3
live: a, b, c
"""
    code = readIntermediateCode(io.StringIO(program))
    code.compute_liveness_info()
    graph = build_interference_graph(code)

    success = allocate_registers(graph, 2)
    assert not success