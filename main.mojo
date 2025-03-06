from src import *
from src.log import LogLevel, log

from python import Python, PythonObject
from sys import argv
from time import sleep, perf_counter_ns

fn main() raises:
    var arguments = argv()
    var boot_rom_file = arguments[1]
    var game_rom_file = arguments[2]
    var scale = 1
    if len(arguments) > 3:
        try:
            scale = Int(String(arguments[3]))
        except e:
            log[LogLevel.Error]("Error parsing scale argument: ", e)
            scale = 1
    
    log[LogLevel.Info]("Boot ROM file: ", boot_rom_file)
    log[LogLevel.Info]("Game ROM file: ", game_rom_file)
    log[LogLevel.Info]("Scale: ", scale)
    with open(boot_rom_file, "r") as boot_rom:
        with open(game_rom_file, "r") as game_rom:
            try:
                var boot_rom_list = boot_rom.read_bytes()
                log[LogLevel.Info]("Boot ROM length: ", len(boot_rom_list))
                var boot_rom_buffer = UnsafePointer[Byte].alloc(len(boot_rom_list))

                for i in range(len(boot_rom_list)):
                    boot_rom_buffer[i] = boot_rom_list[i]

                var game_rom_list = game_rom.read_bytes()
                log[LogLevel.Info]("ROM length: ", len(game_rom_list))
                log[LogLevel.Info]("Cartridge type: ", game_rom_list[0x0147])
                var game_rom_buffer = UnsafePointer[Byte].alloc(len(game_rom_list))
                for i in range(len(game_rom_list)):
                    game_rom_buffer[i] = game_rom_list[i]
                var bus = MemoryBus(boot_rom_buffer, game_rom_buffer)
                var cpu = CPU[ROM_BANK_0_SIZE + ROM_BANK_N_SIZE](bus^)

                var runner = EmulatorRunner()
                runner.setup(scale)

                runner.run(cpu)
            except e:
                log[LogLevel.Error]("Error: ", e)
