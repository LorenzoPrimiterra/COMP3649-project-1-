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
    """This test tests whether or not the register allocator will allow an impossible scenario, e.g. 3 registers required
    but only 2 available"""
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