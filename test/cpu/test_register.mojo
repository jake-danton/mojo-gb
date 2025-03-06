from src import *
from testing import *

fn test_af() raises: 
    var registers = Registers()
    registers.set_af(0b1010_1111_1001_0000)

    assert_equal(registers.a, 0b1010_1111)
    assert_equal(registers.f.to_byte(), 0b1001_0000)

    assert_equal(registers.get_af(), 0b1010_1111_1001_0000)

fn test_bc() raises:
    var registers = Registers()
    registers.set_bc(0b1010_1111_1100_1100)
 
    assert_equal(registers.b, 0b1010_1111)
    assert_equal(registers.c, 0b1100_1100)

    assert_equal(registers.get_bc(), 0b1010_1111_1100_1100)

fn test_de() raises:
    var registers = Registers()
    registers.set_de(0b1010_1111_1100_1100)
 
    assert_equal(registers.d, 0b1010_1111)
    assert_equal(registers.e, 0b1100_1100)

    assert_equal(registers.get_de(), 0b1010_1111_1100_1100)

fn test_hl() raises:
    var registers = Registers()
    registers.set_hl(0b1010_1111_1100_1100)
 
    assert_equal(registers.h, 0b1010_1111)
    assert_equal(registers.l, 0b1100_1100)

    assert_equal(registers.get_hl(), 0b1010_1111_1100_1100)