from src import *
from testing import *

fn test_wrapping_add_nowrap() raises:
    assert_equal(wrapping_add(Byte(250), 5), 255)

fn test_wrapping_add_wrap() raises:
    assert_equal(wrapping_add(Byte(250), 6), 0)

fn test_overflowing_add_nowrap() raises:
    var actual: Tuple[Byte, Bool] = overflowing_add(Byte(250), 5)
    assert_equal(actual[0], 255)
    assert_equal(actual[1], False)

fn test_overflowing_add_wrap() raises:
    var actual: Tuple[Byte, Bool] = overflowing_add(Byte(250), 6)
    assert_equal(actual[0], 0)
    assert_equal(actual[1], True)

fn test_rotate_left() raises:
    assert_equal(rotate_left(Byte(0b1101_1010), 1), 0b1011_0101)

fn test_rotate_right() raises:
    assert_equal(rotate_right(Byte(0b1011_0101), 1), 0b1101_1010)
    