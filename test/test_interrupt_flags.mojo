from src import *
from testing import *

#[test]
fn test_to_bytes_initial() raises:
    var interrupt_flags = InterruptFlags()

    assert_equal(interrupt_flags.to_byte(), 0b11100000)


#[test]
fn test_to_bytes_initial_vblank() raises:
    var interrupt_flags = InterruptFlags()
    interrupt_flags.vblank = True

    assert_equal(interrupt_flags.to_byte(), 0b11100001)


#[test]
fn test_to_bytes_initial_lcdstat() raises:
    var interrupt_flags = InterruptFlags()
    interrupt_flags.lcdstat = True

    assert_equal(interrupt_flags.to_byte(), 0b11100010)


#[test]
fn test_to_bytes_initial_timer() raises:
    var interrupt_flags = InterruptFlags()
    interrupt_flags.timer = True

    assert_equal(interrupt_flags.to_byte(), 0b11100100)


#[test]
fn test_to_bytes_initial_serial() raises:
    var interrupt_flags = InterruptFlags()
    interrupt_flags.serial = True

    assert_equal(interrupt_flags.to_byte(), 0b11101000)


#[test]
fn test_to_bytes_initial_joypad() raises:
    var interrupt_flags = InterruptFlags()
    interrupt_flags.joypad = True

    assert_equal(interrupt_flags.to_byte(), 0b11110000)
