import io
from parser import readIntermediateCode


def test_liveness():
    program = """a = a + 1
t1 = a * 2
b = t1 / 3
live: a, b
"""
    code = readIntermediateCode(io.StringIO(program))
    code.compute_liveness_info()

    # Instruction 2: b = t1 / 3
    assert "t1" in code.live_before[2]
    assert "b" in code.live_after[2]

    # Instruction 1: t1 = a * 2
    assert "a" in code.live_before[1]

    # Instruction 0: a = a + 1
    assert "a" in code.live_before[0]