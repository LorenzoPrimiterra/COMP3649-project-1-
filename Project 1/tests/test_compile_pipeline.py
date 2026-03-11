import io
from parser import readIntermediateCode
from interference import build_interference_graph, allocate_registers


import io
from parser import readIntermediateCode
from interference import build_interference_graph, allocate_registers
from codegen import generate_target


def test_full_pipeline_success():
    program = """a = a + 1
t1 = a * 2
b = t1 / 3
live: a, b
"""

    code = readIntermediateCode(io.StringIO(program))
    code.compute_liveness_info()

    graph = build_interference_graph(code)

    assert allocate_registers(graph, 3)

    target = generate_target(code, graph.assignments)

    asm = str(target)
    #testing is done by checking if the correct asm symbols are built. Maybe there's a better way to do this.
    assert "ADD" in asm
    assert "MUL" in asm
    assert "DIV" in asm

def test_full_pipeline_failure():
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