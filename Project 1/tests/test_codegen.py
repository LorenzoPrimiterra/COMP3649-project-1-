import pytest

from intermediate import Operation, IntermediateCode
from target import AsmInstruction
from codegen import _reg, _is_int_literal, _asm_operand, op_to_asm, generate_target

def test_reg_valid():
    assignments = {"a": 0, "b": 2}
    assert _reg("a", assignments) == "R0"
    assert _reg("b", assignments) == "R2"

def test_reg_missing_variable():
    assignments = {"a": 0}
    with pytest.raises(Exception):
        _reg("b", assignments)

def test_is_int_literal_true():
    assert _is_int_literal("5")
    assert _is_int_literal("-10")

def test_is_int_literal_false():
    assert not _is_int_literal("a")
    assert not _is_int_literal("t1")

def test_asm_operand_integer():
    assignments = {}
    assert _asm_operand("5", assignments) == "#5"

def test_asm_operand_variable():
    assignments = {"a": 1}
    assert _asm_operand("a", assignments) == "R1"

def test_asm_operand_invalid():
    assignments = {}
    with pytest.raises(Exception):
        _asm_operand("???", assignments)

def test_op_to_asm_assignment():
    '''this tests assigning a to b'''
    op = Operation(destination="a", operand1="b", operator=None)

    assignments = {"a": 0, "b": 1}

    result = op_to_asm(op, assignments)

    assert len(result) == 1
    assert result[0].opcode == "MOV"
    assert result[0].src == "R1"
    assert result[0].dst == "R0"

def test_op_to_asm_binary():
    '''This tests a = b + c'''
    op = Operation(destination="a", operand1="b", operand2="c", operator="+")

    assignments = {"a": 0, "b": 1, "c": 2}

    result = op_to_asm(op, assignments)

    assert len(result) == 2

    assert result[0].opcode == "MOV"
    assert result[0].src == "R1"
    assert result[0].dst == "R0"

    assert result[1].opcode == "ADD"
    assert result[1].src == "R2"
    assert result[1].dst == "R0"

def test_op_to_asm_unary_neg():
    '''this tests unary negation, aka a = -b'''
    op = Operation(destination="a", operand1="b", unary_neg=True)

    assignments = {"a": 0, "b": 1}

    result = op_to_asm(op, assignments)

    assert len(result) == 2
    assert result[0].opcode == "MOV"
    assert result[1].opcode == "MUL"

def test_generate_target_basic():
    '''this test a list of operations, e.g. a '''
    code = IntermediateCode()

    op1 = Operation(destination="a", operand1="1")
    op2 = Operation(destination="b", operand1="a", operand2="2", operator="*")

    code.oplist = [op1, op2]

    code.live_before = [set(), set()]
    code.live_after = [set(), {"b"}]
    code.live_out = {"b"}

    assignments = {"a": 0, "b": 1}

    target = generate_target(code, assignments)

    asm = str(target)

    assert "MOV #1,R0" in asm
    assert "MUL #2,R1" in asm