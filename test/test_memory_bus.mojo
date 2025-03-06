from time import monotonic, perf_counter_ns, time_function
from memory import UnsafePointer, memset_zero, stack_allocation
from utils import StaticTuple

from src import *
from src.log import log, LogLevel
from testing import *

from collections import InlinedFixedVector, InlineArray

# TODO remove copy-paste
alias BOOT_ROM_BEGIN = 0x00
alias BOOT_ROM_END = 0xFF
alias BOOT_ROM_SIZE = BOOT_ROM_END - BOOT_ROM_BEGIN + 1

alias ROM_BANK_0_BEGIN = 0x0000
alias ROM_BANK_0_END = 0x3FFF
alias ROM_BANK_0_SIZE = ROM_BANK_0_END - ROM_BANK_0_BEGIN + 1

alias ROM_BANK_N_BEGIN = 0x4000
alias ROM_BANK_N_END = 0x7FFF
alias ROM_BANK_N_SIZE = ROM_BANK_N_END - ROM_BANK_N_BEGIN + 1

fn test_bus() raises:
    var start_time = perf_counter_ns()

    var boot_rom = UnsafePointer[Byte].alloc(BOOT_ROM_SIZE)
    memset_zero(boot_rom, BOOT_ROM_SIZE)
    var game_rom = UnsafePointer[Byte].alloc(ROM_BANK_0_SIZE + ROM_BANK_N_SIZE)
    memset_zero(game_rom, ROM_BANK_0_SIZE + ROM_BANK_N_SIZE)
    var bus = MemoryBus(boot_rom, game_rom)

    log[LogLevel.Debug]("Bus constructed")
    log[LogLevel.Debug](String(perf_counter_ns() - start_time))

    assert_equal(bus.interrupt_flag.timer, False)
    assert_equal(bus.interrupt_flag.vblank, False)
    assert_equal(bus.interrupt_flag.lcdstat, False)