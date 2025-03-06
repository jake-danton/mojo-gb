from src import *
from testing import *

fn test_bit_false() raises:
    assert_equal(bit(False), 0)

fn test_bit_true() raises:
    assert_equal(bit(True), 1)