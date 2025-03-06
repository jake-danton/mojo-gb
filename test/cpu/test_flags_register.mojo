from src import *
from testing import *

fn test_to_byte() raises:
    var flags_register = FlagsRegister()
    flags_register.zero = True
    flags_register.carry = True

    assert_equal(flags_register.to_byte(), 0b1001_0000)


fn test_from_byte() raises:
    var flags_register = FlagsRegister(0b1001_0000)
    assert_equal(flags_register.zero, True)
    assert_equal(flags_register.carry, True)
    assert_equal(flags_register.half_carry, False)
    assert_equal(flags_register.subtract, False)