from time import monotonic, perf_counter_ns

from .gpu import BackgroundAndWindowDataSelect, InterruptRequest, ObjectSize, TileMap, GPU
from .interrupt_flags import InterruptFlags
from .log import LogLevel, log
from .memory import *
import .joypad
from .serial import Serial 
from .timer import Frequency, Timer
from .utils import bit

from memory import UnsafePointer, memset_zero, memcpy

alias BOOT_ROM_BEGIN = 0x00
alias BOOT_ROM_END = 0xFF
alias BOOT_ROM_SIZE = BOOT_ROM_END - BOOT_ROM_BEGIN + 1

alias ROM_BANK_0_BEGIN = 0x0000
alias ROM_BANK_0_END = 0x3FFF
alias ROM_BANK_0_SIZE = ROM_BANK_0_END - ROM_BANK_0_BEGIN + 1

alias ROM_BANK_N_BEGIN = 0x4000
alias ROM_BANK_N_END = 0x7FFF
alias ROM_BANK_N_SIZE = ROM_BANK_N_END - ROM_BANK_N_BEGIN + 1

alias VRAM_BEGIN = 0x8000
alias VRAM_END = 0x9FFF
alias VRAM_SIZE = VRAM_END - VRAM_BEGIN + 1

alias EXTERNAL_RAM_BEGIN = 0xA000
alias EXTERNAL_RAM_END = 0xBFFF
alias EXTERNAL_RAM_SIZE = EXTERNAL_RAM_END - EXTERNAL_RAM_BEGIN + 1

alias WORKING_RAM_BEGIN = 0xC000
alias WORKING_RAM_END = 0xDFFF
alias WORKING_RAM_SIZE = WORKING_RAM_END - WORKING_RAM_BEGIN + 1

alias ECHO_RAM_BEGIN = 0xE000
alias ECHO_RAM_END = 0xFDFF

alias OAM_BEGIN = 0xFE00
alias OAM_END = 0xFE9F
alias OAM_SIZE = OAM_END - OAM_BEGIN + 1

alias UNUSED_BEGIN = 0xFEA0
alias UNUSED_END = 0xFEFF

alias IO_REGISTERS_BEGIN = 0xFF00
alias IO_REGISTERS_END = 0xFF7F

alias ZERO_PAGE_BEGIN = 0xFF80
alias ZERO_PAGE_END = 0xFFFE
alias ZERO_PAGE_SIZE = ZERO_PAGE_END - ZERO_PAGE_BEGIN + 1

alias INTERRUPT_ENABLE_REGISTER = 0xFFFF

alias VBLANK_VECTOR: UInt16 = 0x40
alias LCDSTAT_VECTOR: UInt16 = 0x48
alias TIMER_VECTOR: UInt16 = 0x50

struct MemoryBus:
    # var data: UnsafePointer[Byte]
    var boot_rom: UnsafePointer[Byte]
    var boot_rom_disabled: Bool
    var rom_bank_0: UnsafePointer[Byte]
    var rom_bank_n: UnsafePointer[Byte]
    var external_ram: UnsafePointer[Byte]
    var working_ram: UnsafePointer[Byte]
    var zero_page: UnsafePointer[Byte]
    var gpu: GPU[VRAM_BEGIN, VRAM_SIZE, OAM_SIZE]
    var interrupt_enable: InterruptFlags
    var interrupt_flag: InterruptFlags
    var timer: Timer
    var divider: Timer
    var joypad: Joypad
    var serial: Serial

    var cart_type: Byte # TODO: Enum?

    # MBC1 support
    var ram_enabled: Bool
    var current_ram_bank: UInt8
    var current_rom_bank: UInt8
    var banking_mode: Byte


    fn __init__(out self, owned boot_rom: UnsafePointer[Byte], owned game_rom: UnsafePointer[Byte]):
        # Note: instead of modeling memory as one array of length 0xFFFF, we'll
        # break memory up into it's logical parts.
        self.boot_rom = boot_rom
        self.boot_rom_disabled = False
        self.rom_bank_0 = game_rom
        self.rom_bank_n = game_rom + ROM_BANK_N_BEGIN
        self.external_ram = UnsafePointer[Byte].alloc(EXTERNAL_RAM_SIZE)
        self.working_ram = UnsafePointer[Byte].alloc(WORKING_RAM_SIZE)
        self.zero_page = UnsafePointer[Byte].alloc(ZERO_PAGE_SIZE)
        self.gpu = GPU[VRAM_BEGIN, VRAM_SIZE, OAM_SIZE]()
        self.interrupt_enable = InterruptFlags()
        self.interrupt_flag = InterruptFlags()
        self.timer = Timer(Frequency.F4096)
        self.divider = Timer(Frequency.F16384)
        self.divider.on = True
        self.joypad = Joypad()
        self.serial = Serial()

        # MBC1 support
        self.cart_type = game_rom[CART_TYPE] 
        self.ram_enabled = False
        self.current_ram_bank = 0
        self.current_rom_bank = 1
        self.banking_mode = 0

    fn __del__(owned self):
        self.boot_rom.free()
        self.rom_bank_0.free()
        self.external_ram.free()
        self.working_ram.free()
        self.zero_page.free()

    fn __moveinit__(out self, owned existing: Self):
        self.boot_rom = existing.boot_rom
        self.boot_rom_disabled = existing.boot_rom_disabled
        self.rom_bank_0 = existing.rom_bank_0
        self.rom_bank_n = existing.rom_bank_n
        self.external_ram = existing.external_ram
        self.working_ram = existing.working_ram
        self.zero_page = existing.zero_page
        self.gpu = existing.gpu^
        self.interrupt_enable = existing.interrupt_enable
        self.interrupt_flag = existing.interrupt_flag
        self.timer = existing.timer^
        self.divider = existing.divider^
        self.joypad = existing.joypad
        self.serial = existing.serial
        self.cart_type = existing.cart_type
        self.ram_enabled = existing.ram_enabled
        self.current_ram_bank = existing.current_ram_bank
        self.current_rom_bank = existing.current_rom_bank
        self.banking_mode = existing.banking_mode

    fn step(mut self, cycles: Byte) raises:
        log[LogLevel.Debug]("MemoryBus stepping ", cycles, " cycles")
        if self.timer.step(cycles):
            self.interrupt_flag.timer = True

        # TODO handle false return
        if not self.divider.step(cycles):
            pass

        var interrupt_request = self.gpu.step(cycles)

        if interrupt_request == InterruptRequest.Both or interrupt_request == InterruptRequest.VBlank:
            self.interrupt_flag.vblank = True
        else:
            self.interrupt_flag.vblank = False

        if interrupt_request == InterruptRequest.Both or interrupt_request == InterruptRequest.LCDStat:
            self.interrupt_flag.lcdstat = True
        else:
            self.interrupt_flag.lcdstat = False

    fn has_interrupt(self) -> Bool:
        return (self.interrupt_enable.vblank and self.interrupt_flag.vblank)
            or (self.interrupt_enable.lcdstat and self.interrupt_flag.lcdstat)
            or (self.interrupt_enable.timer and self.interrupt_flag.timer)
            or (self.interrupt_enable.serial and self.interrupt_flag.serial)
            or (self.interrupt_enable.joypad and self.interrupt_flag.joypad)

    fn read_byte(self, address: UInt16) raises -> Byte:
        log[LogLevel.Debug]("Reading from address ", address)
        if not self.boot_rom_disabled and address >= BOOT_ROM_BEGIN and address <= BOOT_ROM_END:
            return self.boot_rom[address]
        if address >= ROM_BANK_0_BEGIN and address <= ROM_BANK_N_END:
            if self.cart_type == 0:
                return self.read_byte_mbc0(address)
            else:
                return self.read_byte_mbc1(address)
        elif address >= VRAM_BEGIN and address <= VRAM_END:
            return self.gpu.vram[address - VRAM_BEGIN]
        elif address >= EXTERNAL_RAM_BEGIN and address <= EXTERNAL_RAM_END:
            return self.external_ram[address - EXTERNAL_RAM_BEGIN]
        elif address >= WORKING_RAM_BEGIN and address <= WORKING_RAM_END:
            return self.working_ram[address - WORKING_RAM_BEGIN]
        elif address >= ECHO_RAM_BEGIN and address <= ECHO_RAM_END:
            return self.working_ram[address - ECHO_RAM_BEGIN]
        elif address >= OAM_BEGIN and address <= OAM_END:
            return self.gpu.oam[address - OAM_BEGIN]
        elif address >= IO_REGISTERS_BEGIN and address <= IO_REGISTERS_END:
            return self.read_io_register(address)
        elif address >= UNUSED_BEGIN and address <= UNUSED_END:
            log[LogLevel.Warning]("Reading from unused memory at address", hex(address))
            return 0xFF
        elif address >= ZERO_PAGE_BEGIN and address <= ZERO_PAGE_END:
            return self.zero_page[address - ZERO_PAGE_BEGIN]
        elif address == INTERRUPT_ENABLE_REGISTER:
            return self.interrupt_enable.to_byte()
        else:
            log[LogLevel.Error]("Reading from an unknown part of memory at address", hex(address))
            return 0xFF        

    fn write_byte(mut self, address: UInt16, value: Byte) raises:
        if address >= ROM_BANK_0_BEGIN and address <= ROM_BANK_N_END:
            if self.cart_type == 0:
                self.write_byte_mbc0(address, value)
            else:
                self.write_byte_mbc1(address, value)
        elif address >= VRAM_BEGIN and address <= VRAM_END:
            self.gpu.write_vram(address - VRAM_BEGIN, value)
        elif address >= EXTERNAL_RAM_BEGIN and address <= EXTERNAL_RAM_END:
            self.external_ram[address - EXTERNAL_RAM_BEGIN] = value
        elif address >= WORKING_RAM_BEGIN and address <= WORKING_RAM_END:
            self.working_ram[address - WORKING_RAM_BEGIN] = value
        elif address >= OAM_BEGIN and address <= OAM_END:
            self.gpu.write_oam(address - OAM_BEGIN, value)
        elif address >= IO_REGISTERS_BEGIN and address <= IO_REGISTERS_END:
            self.write_io_register(address, value)
        elif address >= UNUSED_BEGIN and address <= UNUSED_END:
            log[LogLevel.Warning]("Writing to unused memory at address", hex(address))
            pass
        elif address >= ZERO_PAGE_BEGIN and address <= ZERO_PAGE_END:
            self.zero_page[address - ZERO_PAGE_BEGIN] = value
        elif address == INTERRUPT_ENABLE_REGISTER:
            self.interrupt_enable = value
        else:
            log[LogLevel.Error]("Writing to an unkown part of memory at address", hex(address))

    fn read_byte_mbc0(self, address: UInt16) raises -> Byte:
        """MBC0 cartridge type"""
        if address >= ROM_BANK_0_BEGIN and address <= ROM_BANK_0_END:
            return self.rom_bank_0[address]
        elif address >= ROM_BANK_N_BEGIN and address <= ROM_BANK_N_END:
            return self.rom_bank_n[address - ROM_BANK_N_BEGIN]
        elif address >= EXTERNAL_RAM_BEGIN and address <= EXTERNAL_RAM_END:
            return self.external_ram[address - EXTERNAL_RAM_BEGIN]
        else:
            log[LogLevel.Error]("Reading from an unknown part of memory at address", hex(address))
            return 0xFF

    fn write_byte_mbc0(mut self, address: UInt16, value: Byte) raises:
        """MBC0 cartridge type"""
        if address >= ROM_BANK_0_BEGIN and address <= ROM_BANK_0_END:
            # ROM bank 0
            self.rom_bank_0[address] = value
        elif address >= ROM_BANK_N_BEGIN and address <= ROM_BANK_N_END:
            # ROM bank N
            self.rom_bank_n[address - ROM_BANK_N_BEGIN] = value


    fn read_byte_mbc1(self, address: UInt16) raises -> Byte:
        """MBC1 cartridge type"""
        if address >= ROM_BANK_0_BEGIN and address <= ROM_BANK_0_END:
            # ROM bank 0
            return self.rom_bank_0[address]
        elif address >= ROM_BANK_N_BEGIN and address <= ROM_BANK_N_END:
            # ROM bank N
            var rom_offset = UInt16(self.current_rom_bank) * 0x4000
            return self.rom_bank_n[address - 0x4000 + rom_offset]
        elif address >= EXTERNAL_RAM_BEGIN and address <= EXTERNAL_RAM_END:
            # Reading from external RAM if enabled
            if self.ram_enabled:
                var ram_offset = UInt16(self.current_ram_bank) * 0x2000
                return self.external_ram[address - 0xA000 + ram_offset]
            else:
                return 0xFF
        else:
            log[LogLevel.Error]("Reading from an unknown part of memory at address", hex(address))
            return 0xFF

    fn write_byte_mbc1(mut self, address: UInt16, value: Byte) raises:
        """MBC1 cartridge type"""
        if address >= ROM_BANK_0_BEGIN and address <= 0x1FFF:
            # RAM enable/disable
            self.ram_enabled = (value & 0x0F) == 0x0A
        elif address >= 0x2000 and address <= ROM_BANK_0_END:
            # ROM bank number (lower 5 bits)
            var rom_bank = value & 0x1F
            if rom_bank == 0:
                rom_bank = 1 # ROM bank 0 is not selectable
            self.current_rom_bank = (self.current_rom_bank & 0x60) | rom_bank
        elif address >= ROM_BANK_N_BEGIN and address <= 0x5FFF:
            # RAM bank number or upper bits of ROM bank number
            if self.banking_mode == 0:
                # ROM banking mode - set upper bits of ROM bank number
                self.current_rom_bank = (self.current_rom_bank & 0x1F) | ((value & 0x03) << 5)
            else:
                # RAM banking mode - set RAM bank number
                self.current_ram_bank = value & 0x03
        elif address >= 0x6000 and address <= ROM_BANK_N_END:
            # Banking mode select
            self.banking_mode = value & 0x01
        elif address >= EXTERNAL_RAM_BEGIN and address <= EXTERNAL_RAM_END:
            # Writing to external RAM if enabled
            if self.ram_enabled:
                var ram_offset = UInt16(self.current_ram_bank) * 0x2000
                self.external_ram[address - 0xA000 + ram_offset] = value

    fn read_io_register(self, address: UInt16) raises -> Byte:
        if address == JOYPAD_REGISTER:
            return self.joypad.to_byte()
        elif address == SB_REGISTER:
            return self.serial.sb_register
        elif address == SC_REGISTER:
            return self.serial.sc_register
        elif address == DIVIDER_LO_REGISTER:
            log[LogLevel.Debug]("Reading from divider lo register, returning ", 0xFF)
            return 0xFF  # TODO divider lo
        elif address == DIVIDER_REGISTER:
            return self.divider.value
        elif address == TIMER_COUNTER_REGISTER:
            return self.timer.value
        elif address == TIMER_MODULO_REGISTER:
            return self.timer.modulo
        elif address == TIMER_CONTROLLER_REGISTER:
            return self.timer.frequency.to_byte()
        elif address == INTERRUPT_FLAG:
            return self.interrupt_flag.to_byte()
        elif address >= 0xFF08 and address <= 0xFF0F:
            return 0xFF  # undefined
        elif address >= NR10_REGISTER and address <= NR52_REGISTER:
            return 0xFF  # TODO sound registers
        elif address >= 0xFF27 and address <= 0xFF2F:
            return 0xFF  # undefined
        elif address >= WAVE_PATTERN_RAM_START and address <= WAVE_PATTERN_RAM_END:
            return 0xFF  # TODO wave pattern ram
        elif address == LCDC_REGISTER:
            # TODO move logic into GPU
            return bit(self.gpu.lcd_display_enabled) << 7
                | bit(self.gpu.window_tile_map == TileMap.X9C00) << 6
                | bit(self.gpu.window_display_enabled) << 5
                | bit(self.gpu.background_and_window_data_select == BackgroundAndWindowDataSelect.X8000) << 4
                | bit(self.gpu.background_tile_map == TileMap.X9C00) << 3
                | bit(self.gpu.object_size == ObjectSize.OS8X16) << 2
                | bit(self.gpu.object_display_enabled) << 1
                | bit(self.gpu.background_display_enabled)
        elif address == LCD_STAT_REGISTER:
            # TODO move logic into GPU
            var mode: Byte = self.gpu.mode.to_byte()
            return 0b10000000
                | bit(self.gpu.line_equals_line_check_interrupt_enabled) << 6
                | bit(self.gpu.oam_interrupt_enabled) << 5
                | bit(self.gpu.vblank_interrupt_enabled) << 4
                | bit(self.gpu.hblank_interrupt_enabled) << 3
                | bit(self.gpu.line_equals_line_check) << 2
                | mode
        elif address == SCY_REGISTER:
            return self.gpu.viewport_y_offset
        elif address == SCX_REGISTER:
            return self.gpu.viewport_x_offset
        elif address == LY_REGISTER:
            return self.gpu.line
        elif address == LYC_REGISTER:
            return self.gpu.line_check
        elif address == DMA_REGISTER:
            return 0xFF  # TODO DMA
        elif address == BGP_REGISTER:
            return self.gpu.background_colors.to_byte()
        elif address == OBP0_REGISTER:
            return self.gpu.obj_0_color_3.to_byte() << 6
                | self.gpu.obj_0_color_2.to_byte() << 4
                | self.gpu.obj_0_color_1.to_byte() << 2
        elif address == OBP1_REGISTER:
            return self.gpu.obj_1_color_3.to_byte() << 6
                | self.gpu.obj_1_color_2.to_byte() << 4
                | self.gpu.obj_1_color_1.to_byte() << 2
        elif address == WY_REGISTER:
            return self.gpu.window.y
        elif address == WX_REGISTER:
            return self.gpu.window.x
        elif address >= 0xFF4C and address <= 0xFF7E:
            return 0xFF  # undefined
        elif address == 0xFF50:
            return 0xFF  # TODO: boot rom
        elif address == 0xFF7F:
            return 0xFF  # undefined
             
        raise Error("Reading from an unknown I/O register {}".format(hex(address)))

    fn write_io_register(mut self, address: UInt16, value: Byte) raises:
        if address == JOYPAD_REGISTER:
            self.joypad.column = Column.One if (value & 0x20) == 0 else Column.Zero
        elif address == SB_REGISTER:
            self.serial.sb_register = value
        elif address == SC_REGISTER:
            self.serial.sc_register = value
        elif address == DIVIDER_LO_REGISTER:
            log[LogLevel.Debug]("Writing to divider lo register", value)
            pass  # Unused Div Lo Register
        elif address == DIVIDER_REGISTER:
            self.divider.value = 0
        elif address == TIMER_COUNTER_REGISTER:
            self.timer.value = value
        elif address == TIMER_MODULO_REGISTER:
            self.timer.modulo = value
        elif address == TIMER_CONTROLLER_REGISTER:
            self.timer.frequency = Frequency.from_byte(value)
            self.timer.on = (value & 0b100) == 0b100
        elif address == INTERRUPT_FLAG:
            self.interrupt_flag = value
        elif address >= NR10_REGISTER and address <= NR52_REGISTER:
            pass  # TODO sound registers
        elif address >= WAVE_PATTERN_RAM_START and address <= WAVE_PATTERN_RAM_END:
            # TODO: handle wave pattern ram
            pass
        elif address == LCDC_REGISTER:
            # TODO move logic into GPU
            log[LogLevel.Debug]("Writing to LCDC register", value)
            self.gpu.lcd_display_enabled = (value >> 7) == 1
            self.gpu.window_tile_map = TileMap.X9C00 if ((value >> 6) & 0b1) == 1 else TileMap.X9800
            self.gpu.window_display_enabled = ((value >> 5) & 0b1) == 1
            self.gpu.background_and_window_data_select = BackgroundAndWindowDataSelect.X8000 if ((value >> 4) & 0b1) == 1 else BackgroundAndWindowDataSelect.X8800
            self.gpu.background_tile_map = TileMap.X9C00 if ((value >> 3) & 0b1) == 1 else TileMap.X9800
            self.gpu.object_size = ObjectSize.OS8X16 if ((value >> 2) & 0b1) == 1 else ObjectSize.OS8X8
            self.gpu.object_display_enabled = ((value >> 1) & 0b1) == 1
            self.gpu.background_display_enabled = (value & 0b1) == 1

            # print("self.gpu.background_and_window_data_select", String(self.gpu.background_and_window_data_select), " from ", hex((value >> 4) & 0b1), " from ", hex(value))
        elif address == LCD_STAT_REGISTER:
            # TODO move logic into GPU
            self.gpu.line_equals_line_check_interrupt_enabled = (value & 0b1000000) == 0b1000000
            self.gpu.oam_interrupt_enabled = (value & 0b100000) == 0b100000
            self.gpu.vblank_interrupt_enabled = (value & 0b10000) == 0b10000
            self.gpu.hblank_interrupt_enabled = (value & 0b1000) == 0b1000
        elif address == SCY_REGISTER:
            self.gpu.viewport_y_offset = value
        elif address == SCX_REGISTER:
            self.gpu.viewport_x_offset = value
        elif address == LYC_REGISTER:
            self.gpu.line_check = value
        elif address == DMA_REGISTER:
            # TODO: account for the fact this takes ~640 CPU cycles (160 M-cycles)
            var dma_source = UInt16(value) << 8
            var dma_destination = OAM_START
            # TODO: should this be 160 or 150?
            for offset in range(OAM_SIZE):
                self.write_byte(dma_destination + offset, self.read_byte(dma_source + offset))
        elif address == BGP_REGISTER:
            self.gpu.background_colors = value
        elif address == OBP0_REGISTER:
            self.gpu.obj_0_color_3 = Color.from_byte(value >> 6)
            self.gpu.obj_0_color_2 = Color.from_byte((value >> 4) & 0b11)
            self.gpu.obj_0_color_1 = Color.from_byte((value >> 2) & 0b11)
        elif address == OBP1_REGISTER:
            self.gpu.obj_1_color_3 = Color.from_byte(value >> 6)
            self.gpu.obj_1_color_2 = Color.from_byte((value >> 4) & 0b11)
            self.gpu.obj_1_color_1 = Color.from_byte((value >> 2) & 0b11)
        elif address == WY_REGISTER:
            self.gpu.window.y = value
        elif address == WX_REGISTER:
            self.gpu.window.x = value
        elif address == 0xFF50:
            log[LogLevel.Info]("Disabling boot rom")
            self.boot_rom_disabled = True
        elif address == 0xFF7F:
            # Writing to here does nothing
            pass
        else:
            log[LogLevel.Error]("Writting '", hex(value), "' to an unknown I/O register ", hex(address))
            # raise Error("Writting '{}' to an unknown I/O register {}".format(hex(value), hex(address)))

    # TODO Make UnsafePointer?
    fn slice[start: UInt16, capacity: Int](self) raises -> InlineArray[Byte, capacity]:
        var result = InlineArray[Byte, capacity](unsafe_uninitialized = True)
        for i in range(capacity):
            result[i] = self.read_byte(start + i)

        return result^