import io
from parser import readIntermediateCode
from interference import build_interference_graph, allocate_registers


def test_full_pipeline_success():
    '''TODO: Update this when the full ASM pipeline works.'''
    program = """a = a + 1
t1 = a * 2
b = t1 / 3
live: a, b
"""
    code = readIntermediateCode(io.StringIO(program))
    code.compute_liveness_info()

    graph = build_interference_graph(code)
    success = allocate_registers(graph, 3)

    assert success
    assert len(graph.assignments) == len(graph.nodes)


def test_full_pipeline_failure():
    """TODO: Update this when the final ASM pipeline works."""
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