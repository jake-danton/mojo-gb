from src import *
from testing import *

fn test_to_byte_initial_column0() raises:
    var joypad = Joypad()
    assert_equal(joypad.to_byte(), 0b00101111)

fn test_to_byte_initial_column0_pressed_left() raises:
    var joypad = Joypad()
    joypad.left = True
    assert_equal(joypad.to_byte(), 0b00101101)

fn test_to_byte_initial_column1() raises:
    var joypad = Joypad()
    joypad.column = Column.One
    assert_equal(joypad.to_byte(), 0b00011111)

fn test_to_byte_initial_column1_pressed_a() raises:
    var joypad = Joypad()
    joypad.column = Column.One
    joypad.a = True
    assert_equal(joypad.to_byte(), 0b00011110)
