import io
import pytest
from parser import readIntermediateCode
from errors import ParseError


def test_empty_file():
    f = io.StringIO("")
    with pytest.raises(ParseError):
        readIntermediateCode(f)


def test_single_assignment():
    program = """a = 5
live: a
"""
    f = io.StringIO(program)
    code = readIntermediateCode(f)

    assert len(code.oplist) == 1
    assert code.oplist[0].destination == "a"
    assert code.live_out == ["a"]


def test_full_example():
    program = """a = a + 1
t1 = a * 2
b = t1 / 3
live: a, b
"""
    f = io.StringIO(program)
    code = readIntermediateCode(f)

    assert len(code.oplist) == 3
    assert code.live_out == ["a", "b"]


def test_invalid_live_variable():
    program = """a = 5
live: x
"""
    f = io.StringIO(program)

    with pytest.raises(ParseError):
        readIntermediateCode(f)