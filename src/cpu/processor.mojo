from .flags_register import *
from .instructions import *
from src.log import log, LogLevel
from .registers import *
from src.memory_bus import *

struct CPU[ROM_SIZE: Int]:
    var registers: Registers
    var pc: UInt16
    var sp: UInt16
    var bus: MemoryBus
    var is_halted: Bool
    var interrupts_enabled: Bool

    fn __init__(out self, owned memory_bus: MemoryBus):
        self.registers = Registers()
        self.pc = 0x0
        self.sp = 0x00
        self.bus = memory_bus^
        self.is_halted = False
        self.interrupts_enabled = True

    fn __moveinit__(mut self, owned other: Self):
        self.registers = other.registers
        self.pc = other.pc
        self.sp = other.sp
        self.bus = other.bus^
        self.is_halted = other.is_halted
        self.interrupts_enabled = other.interrupts_enabled

    fn execute_instruction_byte(mut self, instruction_byte: Byte, is_prefixed: Bool) raises -> Tuple[UInt16, Byte]:
        try:
            if is_prefixed:
                return self.execute_prefixed_instruction_byte(instruction_byte)
            else:
                return self.execute_unprefixed_instruction_byte(instruction_byte)
        except e:
            log[LogLevel.Debug]("Error executing instruction", instruction_byte, e)
            # return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)
            raise e

    fn step(mut self) raises -> Byte:
        var instruction_byte = self.bus.read_byte(self.pc)

        var prefixed = instruction_byte == 0xCB

        if prefixed:
            instruction_byte = self.read_next_byte()

        var result = self.execute_instruction_byte(instruction_byte, prefixed)
        var next_pc = result[0]
        var cycles = result[1]

        self.bus.step(cycles)

        if self.bus.has_interrupt():
            self.is_halted = False

        if not self.is_halted:
            self.pc = next_pc

        var interrupted = False
        if self.interrupts_enabled:
            if self.bus.interrupt_enable.vblank and self.bus.interrupt_flag.vblank:
                interrupted = True
                self.bus.interrupt_flag.vblank = False
                self.interrupt(VBLANK_VECTOR)
            if self.bus.interrupt_enable.lcdstat and self.bus.interrupt_flag.lcdstat:
                interrupted = True
                self.bus.interrupt_flag.lcdstat = False
                self.interrupt(LCDSTAT_VECTOR)
            if self.bus.interrupt_enable.timer and self.bus.interrupt_flag.timer:
                interrupted = True
                self.bus.interrupt_flag.timer = False
                self.interrupt(TIMER_VECTOR)

        if interrupted:
            cycles += 12

        return cycles
    
    fn interrupt(mut self, location: UInt16) raises:
        self.interrupts_enabled = False
        self.push(self.pc)
        self.pc = location
        self.bus.step(12)

    
# ===-----------------------------------------------------------------------===#
# Processor Instructions
# ===-----------------------------------------------------------------------===#


    @always_inline
    fn push(mut self, value: UInt16) raises:
        self.sp = wrapping_sub(self.sp, 1)
        self.bus.write_byte(self.sp, Byte((value & 0xFF00) >> 8))

        self.sp = wrapping_sub(self.sp, 1)
        self.bus.write_byte(self.sp, Byte(value & 0xFF))

    @always_inline
    fn pop(mut self) raises -> UInt16:
        var lsb = UInt16(self.bus.read_byte(self.sp))
        self.sp = wrapping_add(self.sp, 1)

        var msb = UInt16(self.bus.read_byte(self.sp))
        self.sp = wrapping_add(self.sp, 1)

        return (msb << 8) | lsb

    @always_inline
    fn read_next_byte(self) raises -> Byte:
        try:
            return self.bus.read_byte(self.pc + 1)
        except e:
            log[LogLevel.Debug]("Error reading next vyte", e)
            log[LogLevel.Debug]("PC: ", self.pc)
            raise e

    @always_inline
    fn read_next_word(self) raises -> UInt16:
        try:
            # Gameboy is little endian so read pc + 2 as most significant bit
            # and pc + 1 as least significant bit
            return (UInt16(self.bus.read_byte(self.pc + 2)) << 8) | UInt16(self.bus.read_byte(self.pc + 1))
        except e:
            log[LogLevel.Debug]("Error reading next word", e)
            log[LogLevel.Debug]("PC: ", self.pc)
            raise e

    @always_inline
    fn inc_byte(mut self, value: Byte) -> Byte:
        var new_value = wrapping_add(value, 1)
        self.registers.f.zero = new_value == 0
        self.registers.f.subtract = False

        # Half Carry is set if the lower nibble of the value is equal to 0xF.
        # If the nibble is equal to 0xF (0b1111) that means incrementing the value
        # by 1 would cause a carry from the lower nibble to the upper nibble.
        self.registers.f.half_carry = value & 0xF == 0xF

        return new_value

    @always_inline
    fn inc_word(mut self, value: UInt16) -> UInt16:
        return wrapping_add(value, 1)

    @always_inline
    fn dec_byte(mut self, value: Byte) -> Byte:
        var new_value = wrapping_sub(value, 1)
        self.registers.f.zero = new_value == 0
        self.registers.f.subtract = True
        # Half Carry is set if the lower nibble of the value is equal to 0x0.
        # If the nibble is equal to 0x0 (0b0000) that means decrementing the value
        # by 1 would cause a carry from the upper nibble to the lower nibble.
        self.registers.f.half_carry = value & 0xF == 0x0
        return new_value

    @always_inline
    fn dec_word(mut self, value: UInt16) -> UInt16:
        return wrapping_sub(value, 1)

    @always_inline
    fn add_without_carry(mut self, value: Byte) -> Byte:
        return self.add(value, False)

    @always_inline
    fn add_with_carry(mut self, value: Byte) -> Byte:
        return self.add(value, True)

    @always_inline
    fn add(mut self, value: Byte, add_carry: Bool) -> Byte:
        var additional_carry = 1 if add_carry and self.registers.f.carry else 0

        var result1 = overflowing_add(self.registers.a, value)
        var result2 = overflowing_add(result1[0], additional_carry)

        self.registers.f.zero = result2[0] == 0
        self.registers.f.subtract = False
        self.registers.f.carry = result1[1] or result2[1]

        # Half Carry is set if adding the lower nibbles of the value and register A
        # together (plus the optional carry bit) result in a value bigger the 0xF.
        # If the result is larger than 0xF than the addition caused a carry from
        # the lower nibble to the upper nibble.
        self.registers.f.half_carry = ((self.registers.a & 0xF) + (value & 0xF) + additional_carry) > 0xF

        return result2[0]

    @always_inline
    fn add_hl(mut self, value: UInt16) -> UInt16:
        var hl = self.registers.get_hl()
        var result = overflowing_add(hl, value)
        self.registers.f.carry = result[1]
        self.registers.f.subtract = False

        # Half carry tests if we flow over the 11th bit i.e. does adding the two
        # numbers together cause the 11th bit to flip
        alias mask = 0b111_1111_1111; # mask out bits 11-15
        self.registers.f.half_carry = (value & mask) + (hl & mask) > mask

        return result[0]

    @always_inline
    fn sub_without_carry(mut self, value: Byte) -> Byte:
        return self.sub(value, False)

    @always_inline
    fn sub_with_carry(mut self, value: Byte) -> Byte:
        return self.sub(value, True)

    @always_inline
    fn sub(mut self, value: Byte, sub_carry: Bool) -> Byte:
        var additional_carry = 1 if sub_carry and self.registers.f.carry else 0
        var result1 = overflowing_sub(self.registers.a, value)
        var result2 = overflowing_sub(result1[0], additional_carry)
        self.registers.f.zero = result2[0] == 0
        self.registers.f.subtract = True
        self.registers.f.carry = result1[1] or result2[1]

        # Half Carry is set if subtracting the lower nibbles of the value (and the
        # optional carry bit) with register a will result in a value lower than 0x0.
        # To avoid underflowing in this test, we can check if the lower nibble of a
        # is less than the lower nibble of the value (with the additional carry)
        self.registers.f.half_carry = (self.registers.a & 0xF) < (value & 0xF) + additional_carry

        return result2[0]

    @always_inline
    fn _and(mut self, value: Byte) -> Byte:
        var new_value = self.registers.a & value
        self.registers.f.zero = new_value == 0
        self.registers.f.subtract = False
        self.registers.f.half_carry = True
        self.registers.f.carry = False
        return new_value

    @always_inline
    fn _or(mut self, value: Byte) -> Byte:
        var new_value = self.registers.a | value
        self.registers.f.zero = new_value == 0
        self.registers.f.subtract = False
        self.registers.f.half_carry = False
        self.registers.f.carry = False
        return new_value

    @always_inline
    fn _xor(mut self, value: Byte) -> Byte:
        var new_value = self.registers.a ^ value
        self.registers.f.zero = new_value == 0
        self.registers.f.subtract = False
        self.registers.f.half_carry = False
        self.registers.f.carry = False
        return new_value

    @always_inline
    fn compare(mut self, value: Byte):
        self.registers.f.zero = self.registers.a == value
        self.registers.f.subtract = True
        # Half Carry is set if subtracting the lower nibbles of the value with register
        # a will result in a value lower than 0x0.  To avoid underflowing in this test,
        # we can check if the lower nibble of a is less than the lower nibble of the value
        self.registers.f.half_carry = (self.registers.a & 0xF) < (value & 0xF)
        self.registers.f.carry = self.registers.a < value

    @always_inline
    fn decimal_adjust(mut self, value: Byte) -> Byte:
        # huge help from: https://github.com/Gekkio/mooneye-gb/blob/754403792d60821e12835ba454d7e8b66553ed22/core/src/cpu/mod.rs#L812-L846

        var flags = self.registers.f
        var carry = False

        var result = value

        if not flags.subtract:
            if flags.carry or value > 0x99:
                carry = True
                result = wrapping_add(result, 0x60)
            if flags.half_carry or value & 0x0F > 0x09:
                result = wrapping_add(result, 0x06)
        elif flags.carry:
            carry = True
            var add = 0x9a if flags.half_carry else 0xa0
            result = wrapping_add(value, add)
        elif flags.half_carry:
            result = wrapping_add(value, 0xfa)

        self.registers.f.zero = result == 0
        self.registers.f.half_carry = False
        self.registers.f.carry = carry

        return result

    @always_inline
    fn rotate_right_through_carry_retain_zero(mut self, value: Byte) -> Byte:
        return self.rotate_right_through_carry(value, False)

    @always_inline
    fn rotate_right_through_carry_set_zero(mut self, value: Byte) -> Byte:
        return self.rotate_right_through_carry(value, True)

    @always_inline
    fn rotate_right_through_carry(mut self, value: Byte, set_zero: Bool) -> Byte:
        var carry_bit = 1 << 7 if self.registers.f.carry else 0
        var new_value = carry_bit | (value >> 1)
        self.registers.f.zero = set_zero and new_value == 0
        self.registers.f.subtract = False
        self.registers.f.half_carry = False
        self.registers.f.carry = value & 0b1 == 0b1
        return new_value

    @always_inline
    fn rotate_left_through_carry_retain_zero(mut self, value: Byte) -> Byte:
        return self.rotate_left_through_carry(value, False)

    @always_inline
    fn rotate_left_through_carry_set_zero(mut self, value: Byte) -> Byte:
        return self.rotate_left_through_carry(value, True)

    @always_inline
    fn rotate_left_through_carry(mut self, value: Byte, set_zero: Bool) -> Byte:
        var carry_bit = 1 if self.registers.f.carry else 0
        var new_value = (value << 1) | carry_bit
        self.registers.f.zero = set_zero and new_value == 0
        self.registers.f.subtract = False
        self.registers.f.half_carry = False
        self.registers.f.carry = (value & 0x80) == 0x80
        return new_value

    @always_inline
    fn rotate_right_set_zero(mut self, value: Byte) -> Byte:
        return self.rotate_right(value, True)

    @always_inline
    fn rotate_right_retain_zero(mut self, value: Byte) -> Byte:
        return self.rotate_right(value, False)

    @always_inline
    fn rotate_left_set_zero(mut self, value: Byte) -> Byte:
        return self.rotate_left(value, True)

    @always_inline
    fn rotate_left_retain_zero(mut self, value: Byte) -> Byte:
        return self.rotate_left(value, False)

    @always_inline
    fn rotate_left(mut self, value: Byte, set_zero: Bool) -> Byte:
        var carry = (value & 0x80) >> 7
        var new_value = rotate_left(value, 1) | carry
        self.registers.f.zero = set_zero and new_value == 0
        self.registers.f.subtract = False
        self.registers.f.half_carry = False
        self.registers.f.carry = carry == 0x01
        return new_value

    @always_inline
    fn rotate_right(mut self, value: Byte, set_zero: Bool) -> Byte:
        var new_value = rotate_right(value, 1)
        self.registers.f.zero = set_zero and new_value == 0
        self.registers.f.subtract = False
        self.registers.f.half_carry = False
        self.registers.f.carry = value & 0b1 == 0b1
        return new_value

    @always_inline
    fn complement(mut self, value: Byte) -> Byte:
        var new_value = ~value
        self.registers.f.subtract = True
        self.registers.f.half_carry = True
        return new_value

    @always_inline
    fn bit_test(mut self, value: Byte, bit_position: BitPosition):
        var bit_position_byte = bit_position.to_byte()
        var result = (value >> bit_position_byte) & 0b1
        self.registers.f.zero = result == 0
        self.registers.f.subtract = False
        self.registers.f.half_carry = True

    @always_inline
    fn reset_bit(mut self, value: Byte, bit_position: BitPosition) -> Byte:
        return value & ~(1 << bit_position.to_byte())

    @always_inline
    fn set_bit(mut self, value: Byte, bit_position: BitPosition) -> Byte:
        return value | (1 << bit_position.to_byte())

    @always_inline
    fn shift_right_logical(mut self, value: Byte) -> Byte:
        var new_value = value >> 1
        self.registers.f.zero = new_value == 0
        self.registers.f.subtract = False
        self.registers.f.half_carry = False
        self.registers.f.carry = value & 0b1 == 0b1
        return new_value

    @always_inline
    fn shift_right_arithmetic(mut self, value: Byte) -> Byte:
        var msb = value & 0x80
        var new_value = msb | (value >> 1)
        self.registers.f.zero = new_value == 0
        self.registers.f.subtract = False
        self.registers.f.half_carry = False
        self.registers.f.carry = value & 0b1 == 0b1
        return new_value

    @always_inline
    fn shift_left_arithmetic(mut self, value: Byte) -> Byte:
        var new_value = value << 1
        self.registers.f.zero = new_value == 0
        self.registers.f.subtract = False
        self.registers.f.half_carry = False
        self.registers.f.carry = value & 0x80 == 0x80
        return new_value

    @always_inline
    fn swap_nibbles(mut self, value: Byte) -> Byte:
        var new_value = ((value & 0xf) << 4) | ((value & 0xf0) >> 4)
        self.registers.f.zero = new_value == 0
        self.registers.f.subtract = False
        self.registers.f.half_carry = False
        self.registers.f.carry = False
        return new_value

    @always_inline
    fn jump(self, should_jump: Bool) raises -> Tuple[UInt16, Byte]:
        if should_jump:
            return Tuple[UInt16, Byte](self.read_next_word(), 16)
        else:
            return Tuple[UInt16, Byte](wrapping_add(self.pc, 3), 12)

    @always_inline
    fn jump_relative(self, should_jump: Bool) raises -> Tuple[UInt16, Byte]:
        var next_step = wrapping_add(self.pc, 2)
        if should_jump:
            var offset = Int8(self.read_next_byte())
            var pc = wrapping_add(next_step, UInt16(offset)) if offset >= 0 else wrapping_sub(next_step, UInt16(abs(offset)))

            return Tuple[UInt16, Byte](pc, 16)

        else:
            return Tuple[UInt16, Byte](next_step, 12)

    @always_inline
    fn call(mut self, should_jump: Bool) raises -> Tuple[UInt16, Byte]:
        var next_pc = wrapping_add(self.pc, 3)
        if should_jump:
            self.push(next_pc)
            return Tuple[UInt16, Byte](self.read_next_word(), 24)
        else:
            return Tuple[UInt16, Byte](next_pc, 12)

    @always_inline
    fn return_(mut self, should_jump: Bool) raises -> UInt16:
        if should_jump:
            return self.pop()
        else:
            return wrapping_add(self.pc, 1)

    @always_inline
    fn rst(mut self) raises:
        self.push(wrapping_add(self.pc, 1))

    @always_inline
    fn get[register: ByteTarget](self) raises -> Byte:
        if register == ByteTarget.A:
            return self.registers.a
        elif register == ByteTarget.B:
            return self.registers.b
        elif register == ByteTarget.C:
            return self.registers.c
        elif register == ByteTarget.D:
            return self.registers.d
        elif register == ByteTarget.E:
            return self.registers.e
        elif register == ByteTarget.H:
            return self.registers.h
        elif register == ByteTarget.L:
            return self.registers.l
        elif register == ByteTarget.D8:
            return self.bus.read_byte(self.pc + 1)
        elif register == ByteTarget.HLI:
            return self.bus.read_byte(self.registers.get_hl())

        raise Error(String("Invalid register", String(register)))

    @always_inline
    fn set[register: ByteTarget](mut self, value: Byte) raises:
        if register == ByteTarget.A:
            self.registers.a = value
        elif register == ByteTarget.B:
            self.registers.b = value
        elif register == ByteTarget.C:
            self.registers.c = value
        elif register == ByteTarget.D:
            self.registers.d = value
        elif register == ByteTarget.E:
            self.registers.e = value
        elif register == ByteTarget.H:
            self.registers.h = value
        elif register == ByteTarget.L:
            self.registers.l = value
        elif register == ByteTarget.D8:
            self.bus.write_byte(self.pc + 1, value) # TODO is this correct?
        elif register == ByteTarget.HLI:
            self.bus.write_byte(self.registers.get_hl(), value)
        else:
            raise Error(String("Invalid register", String(register)))

    fn run_operation[method: ByteMethod](mut self, value: Byte) raises -> Byte:
        if method == ByteMethod.Inc:
            return self.inc_byte(value)
        elif method == ByteMethod.Dec:
            return self.dec_byte(value)
        elif method == ByteMethod.RotateRightThroughCarryRetainZero:
            return self.rotate_right_through_carry_retain_zero(value)
        elif method == ByteMethod.RotateRightRetainZero:
            return self.rotate_right_retain_zero(value)
        elif method == ByteMethod.RotateLeftThroughCarryRetainZero:
            return self.rotate_left_through_carry_retain_zero(value)
        elif method == ByteMethod.RotateLeftRetainZero:
            return self.rotate_left_retain_zero(value)
        elif method == ByteMethod.ShiftRightArithmetic:
            return self.shift_right_arithmetic(value)
        elif method == ByteMethod.ShiftLeftArithmetic:
            return self.shift_left_arithmetic(value)
        elif method == ByteMethod.Add:
            return self.add_without_carry(value)
        elif method == ByteMethod.AddWithCarry:
            return self.add_with_carry(value)
        elif method == ByteMethod.Subtract:
            return self.sub_without_carry(value)
        elif method == ByteMethod.SubtractWithCarry:
            return self.sub_with_carry(value)
        elif method == ByteMethod.And:
            return self._and(value)
        elif method == ByteMethod.Or:
            return self._or(value)
        elif method == ByteMethod.Xor:
            return self._xor(value)
        elif method == ByteMethod.Compare:
            self.compare(value)
            return 0
        elif method == ByteMethod.RotateRightThroughCarrySetZero:
            return self.rotate_right_through_carry_set_zero(value)
        elif method == ByteMethod.RotateLeftThroughCarrySetZero:
            return self.rotate_left_through_carry_set_zero(value)
        elif method == ByteMethod.RotateRightSetZero:
            return self.rotate_right_set_zero(value)
        elif method == ByteMethod.RotateLeftSetZero:
            return self.rotate_left_set_zero(value)
        elif method == ByteMethod.SwapNibbles:
            return self.swap_nibbles(value) 
        elif method == ByteMethod.ShiftRightLogical:
            return self.shift_right_logical(value)
        elif method == ByteMethod.Complement:
            return self.complement(value)
        elif method == ByteMethod.DecimalAdjust:
            return self.decimal_adjust(value)

        raise Error(String("Invalid method ", String(method))) 

    fn run_operation[method: BitMethod, bit: BitPosition](mut self, value: Byte) raises -> Byte:
        if method == BitMethod.BitTest:
            self.bit_test(value, bit)
            return 0 # TODO how to handle this?
        elif method == BitMethod.ResetBit:
            return self.reset_bit(value, bit)
        elif method == BitMethod.SetBit:
            return self.set_bit(value, bit)

        raise Error(String("Invalid method ", String(method)))

    fn manipulate_8bit_register[register: ByteTarget, method: ByteMethod](mut self) raises -> Byte:
        var value = self.get[register]()
        return self.run_operation[method](value)

    fn manipulate_8bit_register[source_register: ByteTarget, method: ByteMethod, target_register: ByteTarget](mut self) raises:
        var value = self.get[source_register]()
        var result = self.run_operation[method](value)
        self.set[target_register](result)

    fn manipulate_8bit_register[source_register: ByteTarget, method: BitMethod, bit: BitPosition](mut self) raises -> Byte:
        var value = self.get[source_register]()
        return self.run_operation[method, bit](value)

    fn manipulate_8bit_register[source_register: ByteTarget, method: BitMethod, bit: BitPosition, target_register: ByteTarget](mut self) raises:
        var value = self.get[source_register]()
        var result = self.run_operation[method, bit](value)
        self.set[target_register](result)

    fn arithmetic_instruction[register: ByteTarget, method: ByteMethod, save: Bool = False](mut self) raises -> Tuple[UInt16, Byte]:
        var result = self.manipulate_8bit_register[register, method]()

        if save:
            self.registers.a = result

        if register == ByteTarget.D8:
            return Tuple[UInt16, Byte](wrapping_add(self.pc, 2), 8)
        elif register == ByteTarget.HLI:
            return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 8)

        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn prefix_instruction[register: ByteTarget, method: ByteMethod, save: Bool = False](mut self) raises -> Tuple[UInt16, Byte]:
        var result = self.manipulate_8bit_register[register, method]()

        if save:
            self.set[register](result)

        return Tuple[UInt16, Byte](wrapping_add(self.pc, 2), 16 if register == ByteTarget.HLI else 8)

    fn prefix_instruction[register: ByteTarget, method: BitMethod, bit: BitPosition, save: Bool = False](mut self) raises -> Tuple[UInt16, Byte]:
        if save:
            self.manipulate_8bit_register[register, method, bit, register]()
        else:
            var _result = self.manipulate_8bit_register[register, method, bit]() 

        return Tuple[UInt16, Byte](wrapping_add(self.pc, 2), 16 if register == ByteTarget.HLI else 8)


# Word methods

    @always_inline
    fn get[register: WordTarget](self) raises -> UInt16:
        if register == WordTarget.AF:
            return self.registers.get_af()
        elif register == WordTarget.BC:
            return self.registers.get_bc()
        elif register == WordTarget.DE:
            return self.registers.get_de()
        elif register == WordTarget.HL:
            return self.registers.get_hl()
        elif register == WordTarget.SP:
            return self.sp

        raise Error(String("Invalid register", String(register)))

    @always_inline
    fn set[register: WordTarget](mut self, value: UInt16) raises:
        if register == WordTarget.AF:
            self.registers.set_af(value)
        elif register == WordTarget.BC:
            self.registers.set_bc(value)
        elif register == WordTarget.DE:
            self.registers.set_de(value)
        elif register == WordTarget.HL:
            self.registers.set_hl(value)
        elif register == WordTarget.SP:
            self.sp = value
        else:
            raise Error(String("Invalid register", String(register)))

    fn run_operation[method: WordMethod](mut self, value: UInt16) raises -> UInt16:
        if method == WordMethod.Inc:
            return self.inc_word(value)
        elif method == WordMethod.Dec:
            return self.dec_word(value)
        
        raise Error(String("Invalid method", String(method)))

    fn manipulate_16bit_register[source_register: WordTarget, method: WordMethod, target_register: WordTarget](mut self) raises:
        var value = self.get[source_register]()
        var result = self.run_operation[method](value)
        self.set[target_register](result)





    fn foo(mut self) raises -> Byte:
        return self.manipulate_8bit_register[ByteTarget.A, ByteMethod.Inc]()



    fn RLC[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (rotate left) - bit rotate a specific register left by 1 (not through the carry flag)
        # PC:+2
        # WHEN: target is (HL):
        # Cycles: 16
        # ELSE:
        # Cycles: 8
        # Z:? S:0 H:0 C:?
        return self.prefix_instruction[target, ByteMethod.RotateLeftRetainZero, save = True]()

    fn RRC[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (rotate right) - bit rotate a specific register right by 1 (not through the carry flag)
        # PC:+2
        # WHEN: target is (HL):
        # Cycles: 16
        # ELSE:
        # Cycles: 8
        # Z:? S:0 H:0 C:?
        return self.prefix_instruction[target, ByteMethod.RotateRightRetainZero, save = True]()

    fn RL[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (rotate left) - bit rotate a specific register left by 1 through the carry flag
        # PC:+2
        # WHEN: target is (HL):
        # Cycles: 16
        # ELSE:
        # Cycles: 8
        # Z:? S:0 H:0 C:?
        log[LogLevel.Debug]("RL ", String(target))
        return self.prefix_instruction[target, ByteMethod.RotateLeftThroughCarrySetZero, save = True]()

    fn RR[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (rotate right) - bit rotate a specific register right by 1 through the carry flag
        # PC:+2
        # WHEN: target is (HL):
        # Cycles: 16
        # ELSE:
        # Cycles: 8
        # Z:? S:0 H:0 C:?
        return self.prefix_instruction[target, ByteMethod.RotateRightThroughCarrySetZero, save = True]()

    fn SLA[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (shift left arithmetic) - arithmetic shift a specific register left by 1
        # PC:+2
        # WHEN: target is (HL):
        # Cycles: 16
        # ELSE:
        # Cycles: 8
        # Z:? S:0 H:0 C:?
        return self.prefix_instruction[target, ByteMethod.ShiftLeftArithmetic, save = True]()

    fn SRA[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (shift right arithmetic) - arithmetic shift a specific register right by 1
        # PC:+2
        # WHEN: target is (HL):
        # Cycles: 16
        # ELSE:
        # Cycles: 8
        # Z:? S:0 H:0 C:?
        return self.prefix_instruction[target, ByteMethod.ShiftRightArithmetic, save = True]()

    fn SWAP[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: switch upper and lower nibble of a specific register
        # PC:+2
        # WHEN: target is (HL):
        # Cycles: 16
        # ELSE:
        # Cycles: 8
        # Z:? S:0 H:0 C:0
        return self.prefix_instruction[target, ByteMethod.SwapNibbles, save = True]()

    fn SRL[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (shift right logical) - bit shift a specific register right by 1
        # PC:+2
        # WHEN: target is (HL):
        # Cycles: 16
        # ELSE:
        # Cycles: 8
        # Z:? S:0 H:0 C:?
        return self.prefix_instruction[target, ByteMethod.ShiftRightLogical, save = True]()

    fn BIT[target: ByteTarget, bit: BitPosition](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (bit test) - test to see if a specific bit of a specific register is set
        # PC:+2
        # WHEN: target is (HL):
        # Cycles: 16
        # ELSE:
        # Cycles: 8
        # Z:? S:0 H:1 C:-
        log[LogLevel.Debug]("BIT ", String(bit), String(target))
        var result = self.prefix_instruction[target, BitMethod.BitTest, bit]()
        return result
        # return self.prefix_instruction[target, BitMethod.BitTest, bit]()

    fn RES[target: ByteTarget, bit: BitPosition](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (bit reset) - set a specific bit of a specific register to 0
        # PC:+2
        # WHEN: target is (HL):
        # Cycles: 16
        # ELSE:
        # Cycles: 8
        # Z:- S:- H:- C:-
        return self.prefix_instruction[target, BitMethod.ResetBit, bit, save = True]()

    fn SET[target: ByteTarget, bit: BitPosition](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (bit set) - set a specific bit of a specific register to 1
        # PC:+2
        # WHEN: target is (HL):
        # Cycles: 16
        # ELSE:
        # Cycles: 8
        # Z:- S:- H:- C:-
        return self.prefix_instruction[target, BitMethod.SetBit, bit, save = True]()

    fn execute_prefixed_instruction_byte(mut self, byte: Byte) raises -> Tuple[UInt16, Byte]:
            log[LogLevel.Debug]("executing prefixed instruction from byte", hex(byte), " from pc", hex(self.pc))

            if byte == 0x00: return self.RLC[ByteTarget.B]()
            if byte == 0x01: return self.RLC[ByteTarget.C]()
            if byte == 0x02: return self.RLC[ByteTarget.D]()
            if byte == 0x03: return self.RLC[ByteTarget.E]()
            if byte == 0x04: return self.RLC[ByteTarget.H]()
            if byte == 0x05: return self.RLC[ByteTarget.L]()
            if byte == 0x06: return self.RLC[ByteTarget.HLI]()
            if byte == 0x07: return self.RLC[ByteTarget.A]()

            if byte == 0x08: return self.RRC[ByteTarget.B]()
            if byte == 0x09: return self.RRC[ByteTarget.C]()
            if byte == 0x0a: return self.RRC[ByteTarget.D]()
            if byte == 0x0b: return self.RRC[ByteTarget.E]()
            if byte == 0x0c: return self.RRC[ByteTarget.H]()
            if byte == 0x0d: return self.RRC[ByteTarget.L]()
            if byte == 0x0e: return self.RRC[ByteTarget.HLI]()
            if byte == 0x0f: return self.RRC[ByteTarget.A]()

            if byte == 0x10: return self.RL[ByteTarget.B]()
            if byte == 0x11: return self.RL[ByteTarget.C]()
            if byte == 0x12: return self.RL[ByteTarget.D]()
            if byte == 0x13: return self.RL[ByteTarget.E]()
            if byte == 0x14: return self.RL[ByteTarget.H]()
            if byte == 0x15: return self.RL[ByteTarget.L]()
            if byte == 0x16: return self.RL[ByteTarget.HLI]()
            if byte == 0x17: return self.RL[ByteTarget.A]()

            if byte == 0x18: return self.RR[ByteTarget.B]()
            if byte == 0x19: return self.RR[ByteTarget.C]()
            if byte == 0x1a: return self.RR[ByteTarget.D]()
            if byte == 0x1b: return self.RR[ByteTarget.E]()
            if byte == 0x1c: return self.RR[ByteTarget.H]()
            if byte == 0x1d: return self.RR[ByteTarget.L]()
            if byte == 0x1e: return self.RR[ByteTarget.HLI]()
            if byte == 0x1f: return self.RR[ByteTarget.A]()

            if byte == 0x20: return self.SLA[ByteTarget.B]()
            if byte == 0x21: return self.SLA[ByteTarget.C]()
            if byte == 0x22: return self.SLA[ByteTarget.D]()
            if byte == 0x23: return self.SLA[ByteTarget.E]()
            if byte == 0x24: return self.SLA[ByteTarget.H]()
            if byte == 0x25: return self.SLA[ByteTarget.L]()
            if byte == 0x26: return self.SLA[ByteTarget.HLI]()
            if byte == 0x27: return self.SLA[ByteTarget.A]()

            if byte == 0x28: return self.SRA[ByteTarget.B]()
            if byte == 0x29: return self.SRA[ByteTarget.C]()
            if byte == 0x2a: return self.SRA[ByteTarget.D]()
            if byte == 0x2b: return self.SRA[ByteTarget.E]()
            if byte == 0x2c: return self.SRA[ByteTarget.H]()
            if byte == 0x2d: return self.SRA[ByteTarget.L]()
            if byte == 0x2e: return self.SRA[ByteTarget.HLI]()
            if byte == 0x2f: return self.SRA[ByteTarget.A]()

            if byte == 0x30: return self.SWAP[ByteTarget.B]()
            if byte == 0x31: return self.SWAP[ByteTarget.C]()
            if byte == 0x32: return self.SWAP[ByteTarget.D]()
            if byte == 0x33: return self.SWAP[ByteTarget.E]()
            if byte == 0x34: return self.SWAP[ByteTarget.H]()
            if byte == 0x35: return self.SWAP[ByteTarget.L]()
            if byte == 0x36: return self.SWAP[ByteTarget.HLI]()
            if byte == 0x37: return self.SWAP[ByteTarget.A]()

            if byte == 0x38: return self.SRL[ByteTarget.B]()
            if byte == 0x39: return self.SRL[ByteTarget.C]()
            if byte == 0x3a: return self.SRL[ByteTarget.D]()
            if byte == 0x3b: return self.SRL[ByteTarget.E]()
            if byte == 0x3c: return self.SRL[ByteTarget.H]()
            if byte == 0x3d: return self.SRL[ByteTarget.L]()
            if byte == 0x3e: return self.SRL[ByteTarget.HLI]()
            if byte == 0x3f: return self.SRL[ByteTarget.A]()

            if byte == 0x40: return self.BIT[ByteTarget.B, BitPosition.B0]()
            if byte == 0x41: return self.BIT[ByteTarget.C, BitPosition.B0]()
            if byte == 0x42: return self.BIT[ByteTarget.D, BitPosition.B0]()
            if byte == 0x43: return self.BIT[ByteTarget.E, BitPosition.B0]()
            if byte == 0x44: return self.BIT[ByteTarget.H, BitPosition.B0]()
            if byte == 0x45: return self.BIT[ByteTarget.L, BitPosition.B0]()
            if byte == 0x46: return self.BIT[ByteTarget.HLI, BitPosition.B0]()
            if byte == 0x47: return self.BIT[ByteTarget.A, BitPosition.B0]()

            if byte == 0x48: return self.BIT[ByteTarget.B, BitPosition.B1]()
            if byte == 0x49: return self.BIT[ByteTarget.C, BitPosition.B1]()
            if byte == 0x4a: return self.BIT[ByteTarget.D, BitPosition.B1]()
            if byte == 0x4b: return self.BIT[ByteTarget.E, BitPosition.B1]()
            if byte == 0x4c: return self.BIT[ByteTarget.H, BitPosition.B1]()
            if byte == 0x4d: return self.BIT[ByteTarget.L, BitPosition.B1]()
            if byte == 0x4e: return self.BIT[ByteTarget.HLI, BitPosition.B1]()
            if byte == 0x4f: return self.BIT[ByteTarget.A, BitPosition.B1]()

            if byte == 0x50: return self.BIT[ByteTarget.B, BitPosition.B2]()
            if byte == 0x51: return self.BIT[ByteTarget.C, BitPosition.B2]()
            if byte == 0x52: return self.BIT[ByteTarget.D, BitPosition.B2]()
            if byte == 0x53: return self.BIT[ByteTarget.E, BitPosition.B2]()
            if byte == 0x54: return self.BIT[ByteTarget.H, BitPosition.B2]()
            if byte == 0x55: return self.BIT[ByteTarget.L, BitPosition.B2]()
            if byte == 0x56: return self.BIT[ByteTarget.HLI, BitPosition.B2]()
            if byte == 0x57: return self.BIT[ByteTarget.A, BitPosition.B2]()

            if byte == 0x58: return self.BIT[ByteTarget.B, BitPosition.B3]()
            if byte == 0x59: return self.BIT[ByteTarget.C, BitPosition.B3]()
            if byte == 0x5a: return self.BIT[ByteTarget.D, BitPosition.B3]()
            if byte == 0x5b: return self.BIT[ByteTarget.E, BitPosition.B3]()
            if byte == 0x5c: return self.BIT[ByteTarget.H, BitPosition.B3]()
            if byte == 0x5d: return self.BIT[ByteTarget.L, BitPosition.B3]()
            if byte == 0x5e: return self.BIT[ByteTarget.HLI, BitPosition.B3]()
            if byte == 0x5f: return self.BIT[ByteTarget.A, BitPosition.B3]()

            if byte == 0x60: return self.BIT[ByteTarget.B, BitPosition.B4]()
            if byte == 0x61: return self.BIT[ByteTarget.C, BitPosition.B4]()
            if byte == 0x62: return self.BIT[ByteTarget.D, BitPosition.B4]()
            if byte == 0x63: return self.BIT[ByteTarget.E, BitPosition.B4]()
            if byte == 0x64: return self.BIT[ByteTarget.H, BitPosition.B4]()
            if byte == 0x65: return self.BIT[ByteTarget.L, BitPosition.B4]()
            if byte == 0x66: return self.BIT[ByteTarget.HLI, BitPosition.B4]()
            if byte == 0x67: return self.BIT[ByteTarget.A, BitPosition.B4]()

            if byte == 0x68: return self.BIT[ByteTarget.B, BitPosition.B5]()
            if byte == 0x69: return self.BIT[ByteTarget.C, BitPosition.B5]()
            if byte == 0x6a: return self.BIT[ByteTarget.D, BitPosition.B5]()
            if byte == 0x6b: return self.BIT[ByteTarget.E, BitPosition.B5]()
            if byte == 0x6c: return self.BIT[ByteTarget.H, BitPosition.B5]()
            if byte == 0x6d: return self.BIT[ByteTarget.L, BitPosition.B5]()
            if byte == 0x6e: return self.BIT[ByteTarget.HLI, BitPosition.B5]()
            if byte == 0x6f: return self.BIT[ByteTarget.A, BitPosition.B5]()

            if byte == 0x70: return self.BIT[ByteTarget.B, BitPosition.B6]()
            if byte == 0x71: return self.BIT[ByteTarget.C, BitPosition.B6]()
            if byte == 0x72: return self.BIT[ByteTarget.D, BitPosition.B6]()
            if byte == 0x73: return self.BIT[ByteTarget.E, BitPosition.B6]()
            if byte == 0x74: return self.BIT[ByteTarget.H, BitPosition.B6]()
            if byte == 0x75: return self.BIT[ByteTarget.L, BitPosition.B6]()
            if byte == 0x76: return self.BIT[ByteTarget.HLI, BitPosition.B6]()
            if byte == 0x77: return self.BIT[ByteTarget.A, BitPosition.B6]()

            if byte == 0x78: return self.BIT[ByteTarget.B, BitPosition.B7]()
            if byte == 0x79: return self.BIT[ByteTarget.C, BitPosition.B7]()
            if byte == 0x7a: return self.BIT[ByteTarget.D, BitPosition.B7]()
            if byte == 0x7b: return self.BIT[ByteTarget.E, BitPosition.B7]()
            if byte == 0x7c: return self.BIT[ByteTarget.H, BitPosition.B7]()
            if byte == 0x7d: return self.BIT[ByteTarget.L, BitPosition.B7]()
            if byte == 0x7e: return self.BIT[ByteTarget.HLI, BitPosition.B7]()
            if byte == 0x7f: return self.BIT[ByteTarget.A, BitPosition.B7]()

            if byte == 0x80: return self.RES[ByteTarget.B, BitPosition.B0]()
            if byte == 0x81: return self.RES[ByteTarget.C, BitPosition.B0]()
            if byte == 0x82: return self.RES[ByteTarget.D, BitPosition.B0]()
            if byte == 0x83: return self.RES[ByteTarget.E, BitPosition.B0]()
            if byte == 0x84: return self.RES[ByteTarget.H, BitPosition.B0]()
            if byte == 0x85: return self.RES[ByteTarget.L, BitPosition.B0]()
            if byte == 0x86: return self.RES[ByteTarget.HLI, BitPosition.B0]()
            if byte == 0x87: return self.RES[ByteTarget.A, BitPosition.B0]()

            if byte == 0x88: return self.RES[ByteTarget.B, BitPosition.B1]()
            if byte == 0x89: return self.RES[ByteTarget.C, BitPosition.B1]()
            if byte == 0x8a: return self.RES[ByteTarget.D, BitPosition.B1]()
            if byte == 0x8b: return self.RES[ByteTarget.E, BitPosition.B1]()
            if byte == 0x8c: return self.RES[ByteTarget.H, BitPosition.B1]()
            if byte == 0x8d: return self.RES[ByteTarget.L, BitPosition.B1]()
            if byte == 0x8e: return self.RES[ByteTarget.HLI, BitPosition.B1]()
            if byte == 0x8f: return self.RES[ByteTarget.A, BitPosition.B1]()

            if byte == 0x90: return self.RES[ByteTarget.B, BitPosition.B2]()
            if byte == 0x91: return self.RES[ByteTarget.C, BitPosition.B2]()
            if byte == 0x92: return self.RES[ByteTarget.D, BitPosition.B2]()
            if byte == 0x93: return self.RES[ByteTarget.E, BitPosition.B2]()
            if byte == 0x94: return self.RES[ByteTarget.H, BitPosition.B2]()
            if byte == 0x95: return self.RES[ByteTarget.L, BitPosition.B2]()
            if byte == 0x96: return self.RES[ByteTarget.HLI, BitPosition.B2]()
            if byte == 0x97: return self.RES[ByteTarget.A, BitPosition.B2]()

            if byte == 0x98: return self.RES[ByteTarget.B, BitPosition.B3]()
            if byte == 0x99: return self.RES[ByteTarget.C, BitPosition.B3]()
            if byte == 0x9a: return self.RES[ByteTarget.D, BitPosition.B3]()
            if byte == 0x9b: return self.RES[ByteTarget.E, BitPosition.B3]()
            if byte == 0x9c: return self.RES[ByteTarget.H, BitPosition.B3]()
            if byte == 0x9d: return self.RES[ByteTarget.L, BitPosition.B3]()
            if byte == 0x9e: return self.RES[ByteTarget.HLI, BitPosition.B3]()
            if byte == 0x9f: return self.RES[ByteTarget.A, BitPosition.B3]()

            if byte == 0xa0: return self.RES[ByteTarget.B, BitPosition.B4]()
            if byte == 0xa1: return self.RES[ByteTarget.C, BitPosition.B4]()
            if byte == 0xa2: return self.RES[ByteTarget.D, BitPosition.B4]()
            if byte == 0xa3: return self.RES[ByteTarget.E, BitPosition.B4]()
            if byte == 0xa4: return self.RES[ByteTarget.H, BitPosition.B4]()
            if byte == 0xa5: return self.RES[ByteTarget.L, BitPosition.B4]()
            if byte == 0xa6: return self.RES[ByteTarget.HLI, BitPosition.B4]()
            if byte == 0xa7: return self.RES[ByteTarget.A, BitPosition.B4]()

            if byte == 0xa8: return self.RES[ByteTarget.B, BitPosition.B5]()
            if byte == 0xa9: return self.RES[ByteTarget.C, BitPosition.B5]()
            if byte == 0xaa: return self.RES[ByteTarget.D, BitPosition.B5]()
            if byte == 0xab: return self.RES[ByteTarget.E, BitPosition.B5]()
            if byte == 0xac: return self.RES[ByteTarget.H, BitPosition.B5]()
            if byte == 0xad: return self.RES[ByteTarget.L, BitPosition.B5]()
            if byte == 0xae: return self.RES[ByteTarget.HLI, BitPosition.B5]()
            if byte == 0xaf: return self.RES[ByteTarget.A, BitPosition.B5]()

            if byte == 0xb0: return self.RES[ByteTarget.B, BitPosition.B6]()
            if byte == 0xb1: return self.RES[ByteTarget.C, BitPosition.B6]()
            if byte == 0xb2: return self.RES[ByteTarget.D, BitPosition.B6]()
            if byte == 0xb3: return self.RES[ByteTarget.E, BitPosition.B6]()
            if byte == 0xb4: return self.RES[ByteTarget.H, BitPosition.B6]()
            if byte == 0xb5: return self.RES[ByteTarget.L, BitPosition.B6]()
            if byte == 0xb6: return self.RES[ByteTarget.HLI, BitPosition.B6]()
            if byte == 0xb7: return self.RES[ByteTarget.A, BitPosition.B6]()

            if byte == 0xb8: return self.RES[ByteTarget.B, BitPosition.B7]()
            if byte == 0xb9: return self.RES[ByteTarget.C, BitPosition.B7]()
            if byte == 0xba: return self.RES[ByteTarget.D, BitPosition.B7]()
            if byte == 0xbb: return self.RES[ByteTarget.E, BitPosition.B7]()
            if byte == 0xbc: return self.RES[ByteTarget.H, BitPosition.B7]()
            if byte == 0xbd: return self.RES[ByteTarget.L, BitPosition.B7]()
            if byte == 0xbe: return self.RES[ByteTarget.HLI, BitPosition.B7]()
            if byte == 0xbf: return self.RES[ByteTarget.A, BitPosition.B7]()

            if byte == 0xc0: return self.SET[ByteTarget.B, BitPosition.B0]()
            if byte == 0xc1: return self.SET[ByteTarget.C, BitPosition.B0]()
            if byte == 0xc2: return self.SET[ByteTarget.D, BitPosition.B0]()
            if byte == 0xc3: return self.SET[ByteTarget.E, BitPosition.B0]()
            if byte == 0xc4: return self.SET[ByteTarget.H, BitPosition.B0]()
            if byte == 0xc5: return self.SET[ByteTarget.L, BitPosition.B0]()
            if byte == 0xc6: return self.SET[ByteTarget.HLI, BitPosition.B0]()
            if byte == 0xc7: return self.SET[ByteTarget.A, BitPosition.B0]()

            if byte == 0xc8: return self.SET[ByteTarget.B, BitPosition.B1]()
            if byte == 0xc9: return self.SET[ByteTarget.C, BitPosition.B1]()
            if byte == 0xca: return self.SET[ByteTarget.D, BitPosition.B1]()
            if byte == 0xcb: return self.SET[ByteTarget.E, BitPosition.B1]()
            if byte == 0xcc: return self.SET[ByteTarget.H, BitPosition.B1]()
            if byte == 0xcd: return self.SET[ByteTarget.L, BitPosition.B1]()
            if byte == 0xce: return self.SET[ByteTarget.HLI, BitPosition.B1]()
            if byte == 0xcf: return self.SET[ByteTarget.A, BitPosition.B1]()

            if byte == 0xd0: return self.SET[ByteTarget.B, BitPosition.B2]()
            if byte == 0xd1: return self.SET[ByteTarget.C, BitPosition.B2]()
            if byte == 0xd2: return self.SET[ByteTarget.D, BitPosition.B2]()
            if byte == 0xd3: return self.SET[ByteTarget.E, BitPosition.B2]()
            if byte == 0xd4: return self.SET[ByteTarget.H, BitPosition.B2]()
            if byte == 0xd5: return self.SET[ByteTarget.L, BitPosition.B2]()
            if byte == 0xd6: return self.SET[ByteTarget.HLI, BitPosition.B2]()
            if byte == 0xd7: return self.SET[ByteTarget.A, BitPosition.B2]()

            if byte == 0xd8: return self.SET[ByteTarget.B, BitPosition.B3]()
            if byte == 0xd9: return self.SET[ByteTarget.C, BitPosition.B3]()
            if byte == 0xda: return self.SET[ByteTarget.D, BitPosition.B3]()
            if byte == 0xdb: return self.SET[ByteTarget.E, BitPosition.B3]()
            if byte == 0xdc: return self.SET[ByteTarget.H, BitPosition.B3]()
            if byte == 0xdd: return self.SET[ByteTarget.L, BitPosition.B3]()
            if byte == 0xde: return self.SET[ByteTarget.HLI, BitPosition.B3]()
            if byte == 0xdf: return self.SET[ByteTarget.A, BitPosition.B3]()

            if byte == 0xe0: return self.SET[ByteTarget.B, BitPosition.B4]()
            if byte == 0xe1: return self.SET[ByteTarget.C, BitPosition.B4]()
            if byte == 0xe2: return self.SET[ByteTarget.D, BitPosition.B4]()
            if byte == 0xe3: return self.SET[ByteTarget.E, BitPosition.B4]()
            if byte == 0xe4: return self.SET[ByteTarget.H, BitPosition.B4]()
            if byte == 0xe5: return self.SET[ByteTarget.L, BitPosition.B4]()
            if byte == 0xe6: return self.SET[ByteTarget.HLI, BitPosition.B4]()
            if byte == 0xe7: return self.SET[ByteTarget.A, BitPosition.B4]()

            if byte == 0xe8: return self.SET[ByteTarget.B, BitPosition.B5]()
            if byte == 0xe9: return self.SET[ByteTarget.C, BitPosition.B5]()
            if byte == 0xea: return self.SET[ByteTarget.D, BitPosition.B5]()
            if byte == 0xeb: return self.SET[ByteTarget.E, BitPosition.B5]()
            if byte == 0xec: return self.SET[ByteTarget.H, BitPosition.B5]()
            if byte == 0xed: return self.SET[ByteTarget.L, BitPosition.B5]()
            if byte == 0xee: return self.SET[ByteTarget.HLI, BitPosition.B5]()
            if byte == 0xef: return self.SET[ByteTarget.A, BitPosition.B5]()

            if byte == 0xf0: return self.SET[ByteTarget.B, BitPosition.B6]()
            if byte == 0xf1: return self.SET[ByteTarget.C, BitPosition.B6]()
            if byte == 0xf2: return self.SET[ByteTarget.D, BitPosition.B6]()
            if byte == 0xf3: return self.SET[ByteTarget.E, BitPosition.B6]()
            if byte == 0xf4: return self.SET[ByteTarget.H, BitPosition.B6]()
            if byte == 0xf5: return self.SET[ByteTarget.L, BitPosition.B6]()
            if byte == 0xf6: return self.SET[ByteTarget.HLI, BitPosition.B6]()
            if byte == 0xf7: return self.SET[ByteTarget.A, BitPosition.B6]()

            if byte == 0xf8: return self.SET[ByteTarget.B, BitPosition.B7]()
            if byte == 0xf9: return self.SET[ByteTarget.C, BitPosition.B7]()
            if byte == 0xfa: return self.SET[ByteTarget.D, BitPosition.B7]()
            if byte == 0xfb: return self.SET[ByteTarget.E, BitPosition.B7]()
            if byte == 0xfc: return self.SET[ByteTarget.H, BitPosition.B7]()
            if byte == 0xfd: return self.SET[ByteTarget.L, BitPosition.B7]()
            if byte == 0xfe: return self.SET[ByteTarget.HLI, BitPosition.B7]()
            if byte == 0xff: return self.SET[ByteTarget.A, BitPosition.B7]()

            else: raise Error(String("Invalid prefixed instruction ", String(byte)))

    fn INC[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (increment) - increment the value in a specific register by 1
        # WHEN: target is 16 bit register
        # PC: +1
        # Cycles: 12
        # Z:- S:- H:- C:-
        # WHEN: target is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC: +1
        # Cycles: 4
        # Z:? S:0 H:? C:-

        log[LogLevel.Debug]("INC ", String(target))

        self.manipulate_8bit_register[target, ByteMethod.Inc, target]()
        var cycles = 8 if target == ByteTarget.HLI else 4
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), cycles)

    fn INC[target: WordTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (increment) - increment the value in a specific register by 1
        # WHEN: target is 16 bit register
        # PC: +1
        # Cycles: 12
        # Z:- S:- H:- C:-
        # WHEN: target is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC: +1
        # Cycles: 4
        # Z:? S:0 H:? C:-
        log[LogLevel.Debug]("INC ", String(target))
        self.manipulate_16bit_register[target, WordMethod.Inc, target]()
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 8)

    fn DEC[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (decrement) - decrement the value in a specific register by 1
        # WHEN: target is 16 bit register
        # PC: +1
        # Cycles: 12
        # Z:- S:- H:- C:-
        # WHEN: target is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC: +1
        # Cycles: 4
        # Z:? S:0 H:? C:-
        log[LogLevel.Debug]("DEC ", String(target))
        self.manipulate_8bit_register[target, ByteMethod.Dec, target]()
        var cycles = 8 if target == ByteTarget.HLI else 4
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), cycles)

    fn DEC[target: WordTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (decrement) - decrement the value in a specific register by 1
        # WHEN: target is 16 bit register
        # PC: +1
        # Cycles: 12
        # Z:- S:- H:- C:-
        # WHEN: target is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC: +1
        # Cycles: 4
        # Z:? S:0 H:? C:-
        self.manipulate_16bit_register[target, WordMethod.Dec, target]()
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 8)

    fn ADD[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (add) - add the value stored in a specific register
        # with the value in the A register
        # WHEN: target is D8
        # PC:+2
        # Cycles: 8
        # WHEN: target is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC: +1
        # Cycles: 4
        # Z:? S:0 H:? C:?
        # arithmetic_instruction!(register, self.add_without_carry => a)

        return self.arithmetic_instruction[target, ByteMethod.Add, save = True]()

    fn ADDHL[target: WordTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (add) - add the value stored in a specific register
        # with the value in the HL register
        # PC:+1
        # Cycles: 8
        # Z:- S:0 H:? C:?
        var value = self.get[target]()
        var result = self.add_hl(value)
        self.registers.set_hl(result)
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 8)
    
    fn ADC[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (add with carry) - add the value stored in a specific
        # register with the value in the A register and the value in the carry flag
        # WHEN: target is D8
        # PC:+2
        # Cycles: 8
        # WHEN: target is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC: +1
        # Cycles: 4
        # Z:? S:0 H:? C:?
                # arithmetic_instruction!(register, self.add_with_carry => a)
        return self.arithmetic_instruction[target, ByteMethod.AddWithCarry, save = True]()

    fn SUB[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (subtract) - subtract the value stored in a specific register
        # with the value in the A register
        # WHEN: target is D8
        # PC:+2
        # Cycles: 8
        # WHEN: target is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC: +1
        # Cycles: 4
        # Z:? S:1 H:? C:?
        return self.arithmetic_instruction[target, ByteMethod.Subtract, save = True]()

    fn SBC[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (subtract) - subtract the value stored in a specific register
        # with the value in the A register and the value in the carry flag
        # WHEN: target is D8
        # PC:+2
        # Cycles: 8
        # WHEN: target is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC: +1
        # Cycles: 4
        # Z:? S:1 H:? C:?
        return self.arithmetic_instruction[target, ByteMethod.SubtractWithCarry, save = True]()

    fn AND[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (AND) - do a bitwise and on the value in a specific
        # register and the value in the A register
        # WHEN: target is D8
        # PC:+2
        # Cycles: 8
        # WHEN: target is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC: +1
        # Cycles: 4
        # Z:? S:0 H:1 C:0
        return self.arithmetic_instruction[target, ByteMethod.And, save = True]()

    fn OR[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (OR) - do a bitwise or on the value in a specific
        # register and the value in the A register
        # WHEN: target is D8
        # PC:+2
        # Cycles: 8
        # WHEN: target is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC: +1
        # Cycles: 4
        # Z:? S:0 H:0 C:0
        return self.arithmetic_instruction[target, ByteMethod.Or, save = True]()

    fn XOR[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (XOR) - do a bitwise xor on the value in a specific
        # register and the value in the A register
        # WHEN: target is D8
        # PC:+2
        # Cycles: 8
        # WHEN: target is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC: +1
        # Cycles: 4
        # Z:? S:0 H:0 C:0
        log[LogLevel.Debug]("XOR ", String(target))
        return self.arithmetic_instruction[target, ByteMethod.Xor, save = True]()

    fn CP[target: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (compare) - just like SUB except the result of the
        # subtraction is not stored back into A
        # WHEN: target is D8
        # PC:+2
        # Cycles: 8
        # WHEN: target is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC: +1
        # Cycles: 4
        # Z:? S:1 H:? C:?
        log[LogLevel.Debug]("CP ", String(target))
        return self.arithmetic_instruction[target, ByteMethod.Compare, save = False]()

    fn ADDSP(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (add stack pointer) - add a one byte signed number to
        # the value stored in the stack pointer register
        # PC:+2
        # Cycles: 16
        # Z:0 S:0 H:? C:?

        # First cast the byte as signed with `as i8` then extend it to 16 bits
        # with `as i16` and then stop treating it like a signed integer with
        # `as u16`
        var value = UInt16(Int16(Int8(self.read_next_byte())))
        var result = wrapping_add(self.sp, value)

        # Half and whole carry are computed at the nibble and byte level instead
        # of the byte and word level like you might expect for 16 bit values
        var half_carry_mask = 0xF
        self.registers.f.half_carry =(self.sp & half_carry_mask) + (value & half_carry_mask) > half_carry_mask
        var carry_mask = 0xff
        self.registers.f.carry = (self.sp & carry_mask) + (value & carry_mask) > carry_mask
        self.registers.f.zero = False
        log[LogLevel.Debug]("ADD SP ", String(value), " ", String(result))
        self.registers.f.subtract = False

        self.sp = result

        return Tuple[UInt16, Byte](wrapping_add(self.pc, 2), 16)

    fn CCF(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (complement carry flag) - toggle the value of the carry flag
        # PC:+1
        # Cycles: 4
        # Z:- S:0 H:0 C:?
        self.registers.f.subtract = False
        self.registers.f.half_carry = False
        self.registers.f.carry = ~self.registers.f.carry
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn SCF(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (set carry flag) - set the carry flag to true
        # PC:+1
        # Cycles: 4
        # Z:- S:0 H:0 C:1
        self.registers.f.subtract = False
        self.registers.f.half_carry = False
        self.registers.f.carry = True
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)


    fn RRA(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (rotate right A register) - bit rotate A register right through the carry flag
        # PC:+1
        # Cycles: 4
        # Z:0 S:0 H:0 C:?
        self.manipulate_8bit_register[ByteTarget.A, ByteMethod.RotateRightThroughCarryRetainZero, ByteTarget.A]()
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn RLA(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (rotate left A register) - bit rotate A register left through the carry flag
        # PC:+1
        # Cycles: 4
        # Z:0 S:0 H:0 C:?
        log[LogLevel.Debug]("RLA")
        self.manipulate_8bit_register[ByteTarget.A, ByteMethod.RotateLeftThroughCarryRetainZero, ByteTarget.A]()
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn RRCA(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (rotate right A register) - bit rotate A register right (not through the carry flag)
        # PC:+1
        # Cycles: 4
        # Z:0 S:0 H:0 C:?
        self.manipulate_8bit_register[ByteTarget.A, ByteMethod.RotateRightRetainZero, ByteTarget.A]()
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn RLCA(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (rotate left A register) - bit rotate A register left (not through the carry flag)
        # PC:+1
        # Cycles: 4
        # Z:0 S:0 H:0 C:?
        self.manipulate_8bit_register[ByteTarget.A, ByteMethod.RotateLeftRetainZero, ByteTarget.A]()
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn CPL(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: (complement) - toggle every bit of the A register
        # PC:+1
        # Cycles: 4
        # Z:- S:1 H:1 C:-
        self.manipulate_8bit_register[ByteTarget.A, ByteMethod.Complement, ByteTarget.A]()
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn DAA(mut self) raises -> Tuple[UInt16, Byte]:
        # PC:+1
        # Cycles: 4
        # Z:? S:- H:0 C:?
        self.manipulate_8bit_register[ByteTarget.A, ByteMethod.DecimalAdjust, ByteTarget.A]()
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn JP[test: JumpTest](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: conditionally jump to the address stored in the next word in memory
        # PC:?/+3
        # Cycles: 16/12
        # Z:- N:- H:- C:-
        if test == JumpTest.NotZero:
            return self.jump(~self.registers.f.zero)
        if test == JumpTest.NotCarry:
            return self.jump(~self.registers.f.carry)
        if test == JumpTest.Zero:
            return self.jump(self.registers.f.zero)
        if test == JumpTest.Carry:
            return self.jump(self.registers.f.carry)
        if test == JumpTest.Always:
            return self.jump(True)
        
        raise Error(String("Invalid jump test", String(test)))        

    fn JR[test: JumpTest](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: conditionally jump to the address that is N bytes away in memory
        # where N is the next byte in memory interpreted as a signed byte
        # PC:?/+2
        # Cycles: 16/12
        # Z:- N:- H:- C:-
        if test == JumpTest.NotZero:
            var result = self.jump_relative(~self.registers.f.zero)
            log[LogLevel.Debug]("JR NZ, ", hex(result[0]))
            return result
        if test == JumpTest.NotCarry:
            return self.jump_relative(~self.registers.f.carry)
        if test == JumpTest.Zero:
            return self.jump_relative(self.registers.f.zero)
        if test == JumpTest.Carry:
            return self.jump_relative(self.registers.f.carry)
        if test == JumpTest.Always:
            return self.jump_relative(True)

        raise Error(String("Invalid jump test", String(test)))

    fn JPI(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: jump to the address stored in HL
        # 1
        # PC:HL
        # Cycles: 4
        # Z:- N:- H:- C:-
        return Tuple[UInt16, Byte](self.registers.get_hl(), 4)

    fn LD[target: ByteTarget, source: ByteTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: load byte store in a particular register into another
        # particular register
        # WHEN: source is d8
        # PC:+2
        # Cycles: 8
        # WHEN: source is (HL)
        # PC:+1
        # Cycles: 8
        # ELSE:
        # PC:+1
        # Cycles: 4
        # Z:- N:- H:- C:-
        var value = self.get[source]()
        self.set[target](value)

        log[LogLevel.Debug]("LD ", String(target), ", ", String(source), "[", hex(value), "]")

        if source == ByteTarget.D8:
            return Tuple[UInt16, Byte](wrapping_add(self.pc, 2), 8)
        elif source == ByteTarget.HLI:
            return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 8)
        else:
            return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn LD[target: WordTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: load next word in memory into a particular register
        # PC:+3
        # Cycles: 12
        # Z:- N:- H:- C:-
        var value = self.read_next_word()
        log[LogLevel.Debug]("LD ", String(target), ", ", hex(value), "[OR ", hex(self.bus.read_byte(self.pc + 1)), ", ", hex(self.bus.read_byte(self.pc + 2)), "]")
        self.set[target](value)
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 3), 12)

    fn LD_FromIndirect[indirect: Indirect](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: load a particular value stored at the source address into A
        # WHEN: source is word indirect
        # PC:+3
        # Cycles: 16
        # ELSE:
        # PC:+1
        # Cycles: 8
        # Z:- N:- H:- C:-
        if indirect == Indirect.BCIndirect:
            log[LogLevel.Debug]("LD A, (BC)")
            self.registers.a = self.bus.read_byte(self.registers.get_bc())
        elif indirect == Indirect.DEIndirect:
            log[LogLevel.Debug]("LD A, (DE)")
            self.registers.a = self.bus.read_byte(self.registers.get_de())
        elif indirect == Indirect.HLIndirectMinus:
            log[LogLevel.Debug]("LD A, (HL-)")
            var hl = self.registers.get_hl()
            self.registers.set_hl(wrapping_sub(hl, 1))
            self.registers.a = self.bus.read_byte(hl)
        elif indirect == Indirect.HLIndirectPlus:
            log[LogLevel.Debug]("LD A, (HL+)")
            var hl = self.registers.get_hl()
            self.registers.set_hl(wrapping_add(hl, 1))
            self.registers.a = self.bus.read_byte(hl)
        elif indirect == Indirect.WordIndirect:
            log[LogLevel.Debug]("LD A, (", hex(self.read_next_word()), ")")
            self.registers.a = self.bus.read_byte(self.read_next_word())
        elif indirect == Indirect.LastByteIndirect:
            log[LogLevel.Debug]("LD A, (FF00 + C)")
            var c = UInt16(self.registers.c)
            self.registers.a = self.bus.read_byte(0xFF00 + c)
        else:
            raise Error(String("Invalid indirect", String(indirect)))

        if indirect == Indirect.WordIndirect:
            return Tuple[UInt16, Byte](wrapping_add(self.pc, 3), 16)
        else:
            return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 8)

    fn LD_ToIndirect[indirect: Indirect](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: load the A register into memory at the source address
        # WHEN: instruction.source is word indirect
        # PC:+3
        # Cycles: 16
        # ELSE:
        # PC:+1
        # Cycles: 8
        # Z:- N:- H:- C:-
        if indirect == Indirect.BCIndirect:
            self.bus.write_byte(self.registers.get_bc(), self.registers.a)
        elif indirect == Indirect.DEIndirect:
            self.bus.write_byte(self.registers.get_de(), self.registers.a)
        elif indirect == Indirect.HLIndirectMinus:
            log[LogLevel.Debug]("LD (HL-), A")
            var hl = self.registers.get_hl()
            self.registers.set_hl(wrapping_sub(hl, 1))
            self.bus.write_byte(hl, self.registers.a)
        elif indirect == Indirect.HLIndirectPlus:
            log[LogLevel.Debug]("LD (HL+), A")
            var hl = self.registers.get_hl()
            self.registers.set_hl(wrapping_add(hl, 1))
            self.bus.write_byte(hl, self.registers.a)
        elif indirect == Indirect.WordIndirect:
            self.bus.write_byte(self.read_next_word(), self.registers.a)
        elif indirect == Indirect.LastByteIndirect:
            log[LogLevel.Debug]("LD ", hex(0xFF00 + UInt16(self.registers.c)),", A")

            self.bus.write_byte(0xFF00 + UInt16(self.registers.c), self.registers.a)
        else:
            raise Error(String("Invalid indirect", String(indirect)))

        if indirect == Indirect.WordIndirect:
            return Tuple[UInt16, Byte](wrapping_add(self.pc, 3), 16)
        else:
            return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 8)

    fn LD_FromA(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: Load the value in A into memory location located at 0xFF plus
        # an offset stored as the next byte in memory
        # PC:+2
        # Cycles: 12
        # Z:- N:- H:- C:-
        var offset = UInt16(self.read_next_byte())
        log[LogLevel.Debug]("LD (", hex(0xFF00 + offset), "), A")
        self.bus.write_byte(0xFF00 + offset, self.registers.a)
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 2), 12)

    fn LD_ToA(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: Load the value located at 0xFF plus an offset stored as the next byte in memory into A
        # PC:+2
        # Cycles: 12
        # Z:- N:- H:- C:-
        var offset = UInt16(self.read_next_byte())
        self.registers.a = self.bus.read_byte(0xFF00 + offset)
        log[LogLevel.Debug]("LD A, (", hex(0xFF00 + offset), ")")
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 2), 12)
    
    fn LD_SPFromHL(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: Load the value in HL into SP
        # PC:+1
        # Cycles: 8
        # Z:- N:- H:- C:-
        self.sp = self.registers.get_hl()
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 8)

    fn LD_FromSP(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: Load memory address with the contents of SP
        # PC:+3
        # Cycles: 20
        # Z:- N:- H:- C:-
        var address = self.read_next_word()
        self.bus.write_byte(address, UInt8(self.sp & 0xFF))
        self.bus.write_byte(wrapping_add(address, 1), UInt8((self.sp & 0xFF00) >> 8))
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 3), 20)

    fn LD_HLFromSPN(mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: load HL with SP plus some specified byte
        # PC:+2
        # Cycles: 12
        # Z:0 N:0 H:? C:?
        var value = UInt16(Int16(Int8(self.read_next_byte())))
        var result = wrapping_add(self.sp, value)
        self.registers.set_hl(result)
        self.registers.f.zero = False
        log[LogLevel.Debug]("LD HL, SP + N ", String(value), " ", String(result))
        self.registers.f.subtract = False
        # Half and whole carry are computed at the nibble and byte level instead
        # of the byte and word level like you might expect for 16 bit values
        self.registers.f.half_carry = (self.sp & 0xF) + (value & 0xF) > 0xF
        self.registers.f.carry = (self.sp & 0xFF) + (value & 0xFF) > 0xFF
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 2), 12)

    fn PUSH[target: WordTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: push a value from a given register on to the stack
        # PC:+1
        # Cycles: 16
        # Z:- N:- H:- C:-
        var value = self.get[target]()
        self.push(value)
        log[LogLevel.Debug]("PUSH ", String(target), "[", hex(value), "]")
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 16)

    fn POP[target: WordTarget](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: pop a value from the stack and store it in a given register
        # PC:+1
        # Cycles: 12
        # WHEN: target is AF
        # Z:? N:? H:? C:?
        # ELSE:
        # Z:- N:- H:- C:-
        var result = self.pop()
        self.set[target](result)
        log[LogLevel.Debug]("POP ", String(target), "[", hex(result), "]")
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 12)

    fn CALL[test: JumpTest](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: Conditionally PUSH the would be instruction on to the
        # stack and then jump to a specific address
        # PC:?/+3
        # Cycles: 24/12
        # Z:- N:- H:- C:-
        if test == JumpTest.NotZero:
            return self.call(~self.registers.f.zero)
        if test == JumpTest.NotCarry:
            return self.call(~self.registers.f.carry)
        if test == JumpTest.Zero:
            return self.call(self.registers.f.zero)
        if test == JumpTest.Carry:
            return self.call(self.registers.f.carry)
        if test == JumpTest.Always:
            log[LogLevel.Debug]("PC = ", hex(self.pc))
            log[LogLevel.Debug]("Byte at PC = ", hex(self.bus.read_byte(self.pc)))
            log[LogLevel.Debug]("CALL", hex(self.read_next_word()))
            return self.call(True)

        raise Error(String("Invalid jump test", String(test)))

    fn RET[test: JumpTest](mut self) raises -> Tuple[UInt16, Byte]:
        # DESCRIPTION: Conditionally POP two bytes from the stack and jump to that address
        # PC:?/+1
        # WHEN: condition is 'always'
        # Cycles: 16/8
        # ELSE:
        # Cycles: 20/8
        # Z:- N:- H:- C:-
        log[LogLevel.Debug]("RET ", String(test))
        var jump_condition: Bool
        if test == JumpTest.NotZero:
            jump_condition = ~self.registers.f.zero
        elif test == JumpTest.NotCarry:
            jump_condition = ~self.registers.f.carry
        elif test == JumpTest.Zero:
            jump_condition = self.registers.f.zero
        elif test == JumpTest.Carry:
            jump_condition = self.registers.f.carry
        elif test == JumpTest.Always:
            jump_condition = True
        else:
            raise Error(String("Invalid jump test", String(test)))

        var next_pc = self.return_(jump_condition)

        var cycles: UInt8
        if jump_condition and test == JumpTest.Always:
            cycles = 16
        elif jump_condition:
            cycles = 20
        else:
            cycles = 8

        return Tuple[UInt16, Byte](next_pc, cycles)

    fn RETI(mut self) raises -> Tuple[UInt16, Byte]:
        # PC:?
        # Cycles: 16
        # Z:- N:- H:- C:-
        self.interrupts_enabled = True
        return Tuple[UInt16, Byte](self.pop(), 16)
    
    fn RST[location: RSTLocation](mut self) raises -> Tuple[UInt16, Byte]:
        # PC:?
        # Cycles: 24
        # Z:- N:- H:- C:-
        self.rst()
        return Tuple[UInt16, Byte](location.to_hex(), 24)

    fn NOP(mut self) raises -> Tuple[UInt16, Byte]:
        # PC:+1
        # Cycles: 4
        # Z:- N:- H:- C:-
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn HALT(mut self) raises -> Tuple[UInt16, Byte]:
        # PC:+1
        # Cycles: 4
        # Z:- N:- H:- C:-
        self.is_halted = True
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn DI(mut self) raises -> Tuple[UInt16, Byte]:
        # PC:+1
        # Cycles: 4
        # Z:- N:- H:- C:-
        self.interrupts_enabled = False
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn EI(mut self) raises -> Tuple[UInt16, Byte]:
        # PC:+1
        # Cycles: 4
        # Z:- N:- H:- C:-
        self.interrupts_enabled = True
        return Tuple[UInt16, Byte](wrapping_add(self.pc, 1), 4)

    fn execute_unprefixed_instruction_byte(mut self, byte: Byte) raises -> Tuple[UInt16, Byte]:
            log[LogLevel.Debug]("executing unprefixed instruction from byte", hex(byte), "from pc", hex(self.pc))

            if byte == 0x3c: return self.INC[ByteTarget.A]()
            if byte == 0x04: return self.INC[ByteTarget.B]()
            if byte == 0x14: return self.INC[ByteTarget.D]()
            if byte == 0x24: return self.INC[ByteTarget.H]()
            if byte == 0x0c: return self.INC[ByteTarget.C]()
            if byte == 0x1c: return self.INC[ByteTarget.E]()
            if byte == 0x2c: return self.INC[ByteTarget.L]()
            if byte == 0x34: return self.INC[ByteTarget.HLI]()
            if byte == 0x03: return self.INC[WordTarget.BC]()
            if byte == 0x13: return self.INC[WordTarget.DE]()
            if byte == 0x23: return self.INC[WordTarget.HL]()
            if byte == 0x33: return self.INC[WordTarget.SP]()

            if byte == 0x3d: return self.DEC[ByteTarget.A]()
            if byte == 0x05: return self.DEC[ByteTarget.B]()
            if byte == 0x0d: return self.DEC[ByteTarget.C]()
            if byte == 0x15: return self.DEC[ByteTarget.D]()
            if byte == 0x1d: return self.DEC[ByteTarget.E]()
            if byte == 0x25: return self.DEC[ByteTarget.H]()
            if byte == 0x2d: return self.DEC[ByteTarget.L]()
            if byte == 0x35: return self.DEC[ByteTarget.HLI]()
            if byte == 0x0b: return self.DEC[WordTarget.BC]()
            if byte == 0x1b: return self.DEC[WordTarget.DE]()
            if byte == 0x2b: return self.DEC[WordTarget.HL]()
            if byte == 0x3b: return self.DEC[WordTarget.SP]()

            if byte == 0x87: return self.ADD[ByteTarget.A]()
            if byte == 0x80: return self.ADD[ByteTarget.B]()
            if byte == 0x81: return self.ADD[ByteTarget.C]()
            if byte == 0x82: return self.ADD[ByteTarget.D]()
            if byte == 0x83: return self.ADD[ByteTarget.E]()
            if byte == 0x84: return self.ADD[ByteTarget.H]()
            if byte == 0x85: return self.ADD[ByteTarget.L]()
            if byte == 0x86: return self.ADD[ByteTarget.HLI]()
            if byte == 0xc6: return self.ADD[ByteTarget.D8]()

            if byte == 0x09: return self.ADDHL[WordTarget.BC]()
            if byte == 0x19: return self.ADDHL[WordTarget.DE]()
            if byte == 0x29: return self.ADDHL[WordTarget.HL]()
            if byte == 0x39: return self.ADDHL[WordTarget.SP]()

            if byte == 0x8f: return self.ADC[ByteTarget.A]()
            if byte == 0x88: return self.ADC[ByteTarget.B]()
            if byte == 0x89: return self.ADC[ByteTarget.C]()
            if byte == 0x8a: return self.ADC[ByteTarget.D]()
            if byte == 0x8b: return self.ADC[ByteTarget.E]()
            if byte == 0x8c: return self.ADC[ByteTarget.H]()
            if byte == 0x8d: return self.ADC[ByteTarget.L]()
            if byte == 0x8e: return self.ADC[ByteTarget.HLI]()
            if byte == 0xce: return self.ADC[ByteTarget.D8]()

            if byte == 0x97: return self.SUB[ByteTarget.A]()
            if byte == 0x90: return self.SUB[ByteTarget.B]()
            if byte == 0x91: return self.SUB[ByteTarget.C]()
            if byte == 0x92: return self.SUB[ByteTarget.D]()
            if byte == 0x93: return self.SUB[ByteTarget.E]()
            if byte == 0x94: return self.SUB[ByteTarget.H]()
            if byte == 0x95: return self.SUB[ByteTarget.L]()
            if byte == 0x96: return self.SUB[ByteTarget.HLI]()
            if byte == 0xd6: return self.SUB[ByteTarget.D8]()

            if byte == 0x9f: return self.SBC[ByteTarget.A]()
            if byte == 0x98: return self.SBC[ByteTarget.B]()
            if byte == 0x99: return self.SBC[ByteTarget.C]()
            if byte == 0x9a: return self.SBC[ByteTarget.D]()
            if byte == 0x9b: return self.SBC[ByteTarget.E]()
            if byte == 0x9c: return self.SBC[ByteTarget.H]()
            if byte == 0x9d: return self.SBC[ByteTarget.L]()
            if byte == 0x9e: return self.SBC[ByteTarget.HLI]()
            if byte == 0xde: return self.SBC[ByteTarget.D8]()

            if byte == 0xa7: return self.AND[ByteTarget.A]()
            if byte == 0xa0: return self.AND[ByteTarget.B]()
            if byte == 0xa1: return self.AND[ByteTarget.C]()
            if byte == 0xa2: return self.AND[ByteTarget.D]()
            if byte == 0xa3: return self.AND[ByteTarget.E]()
            if byte == 0xa4: return self.AND[ByteTarget.H]()
            if byte == 0xa5: return self.AND[ByteTarget.L]()
            if byte == 0xa6: return self.AND[ByteTarget.HLI]()
            if byte == 0xe6: return self.AND[ByteTarget.D8]()

            if byte == 0xb7: return self.OR[ByteTarget.A]()
            if byte == 0xb0: return self.OR[ByteTarget.B]()
            if byte == 0xb1: return self.OR[ByteTarget.C]()
            if byte == 0xb2: return self.OR[ByteTarget.D]()
            if byte == 0xb3: return self.OR[ByteTarget.E]()
            if byte == 0xb4: return self.OR[ByteTarget.H]()
            if byte == 0xb5: return self.OR[ByteTarget.L]()
            if byte == 0xb6: return self.OR[ByteTarget.HLI]()
            if byte == 0xf6: return self.OR[ByteTarget.D8]()

            if byte == 0xaf: return self.XOR[ByteTarget.A]()
            if byte == 0xa8: return self.XOR[ByteTarget.B]()
            if byte == 0xa9: return self.XOR[ByteTarget.C]()
            if byte == 0xaa: return self.XOR[ByteTarget.D]()
            if byte == 0xab: return self.XOR[ByteTarget.E]()
            if byte == 0xac: return self.XOR[ByteTarget.H]()
            if byte == 0xad: return self.XOR[ByteTarget.L]()
            if byte == 0xae: return self.XOR[ByteTarget.HLI]()
            if byte == 0xee: return self.XOR[ByteTarget.D8]()

            if byte == 0xbf: return self.CP[ByteTarget.A]()
            if byte == 0xb8: return self.CP[ByteTarget.B]()
            if byte == 0xb9: return self.CP[ByteTarget.C]()
            if byte == 0xba: return self.CP[ByteTarget.D]()
            if byte == 0xbb: return self.CP[ByteTarget.E]()
            if byte == 0xbc: return self.CP[ByteTarget.H]()
            if byte == 0xbd: return self.CP[ByteTarget.L]()
            if byte == 0xbe: return self.CP[ByteTarget.HLI]()
            if byte == 0xfe: return self.CP[ByteTarget.D8]()

            if byte == 0xe8: return self.ADDSP()

            if byte == 0x3f: return self.CCF()
            if byte == 0x37: return self.SCF()
            if byte == 0x1f: return self.RRA()
            if byte == 0x17: return self.RLA()
            if byte == 0x0f: return self.RRCA()
            if byte == 0x07: return self.RLCA()
            if byte == 0x2f: return self.CPL()

            if byte == 0x27: return self.DAA()

            if byte == 0xc3: return self.JP[JumpTest.Always]()
            if byte == 0xc2: return self.JP[JumpTest.NotZero]()
            if byte == 0xd2: return self.JP[JumpTest.NotCarry]()
            if byte == 0xca: return self.JP[JumpTest.Zero]()
            if byte == 0xda: return self.JP[JumpTest.Carry]()

            if byte == 0x18: return self.JR[JumpTest.Always]()
            if byte == 0x28: return self.JR[JumpTest.Zero]()
            if byte == 0x38: return self.JR[JumpTest.Carry]()
            if byte == 0x20: return self.JR[JumpTest.NotZero]()
            if byte == 0x30: return self.JR[JumpTest.NotCarry]()

            if byte == 0xe9: return self.JPI()

            if byte == 0xf2: return self.LD_FromIndirect[Indirect.LastByteIndirect]()
            if byte == 0x0a: return self.LD_FromIndirect[Indirect.BCIndirect]()
            if byte == 0x1a: return self.LD_FromIndirect[Indirect.DEIndirect]()
            if byte == 0x2a: return self.LD_FromIndirect[Indirect.HLIndirectPlus]()
            if byte == 0x3a: return self.LD_FromIndirect[Indirect.HLIndirectMinus]()
            if byte == 0xfa: return self.LD_FromIndirect[Indirect.WordIndirect]()

            if byte == 0xe2: return self.LD_ToIndirect[Indirect.LastByteIndirect]()
            if byte == 0x02: return self.LD_ToIndirect[Indirect.BCIndirect]()
            if byte == 0x12: return self.LD_ToIndirect[Indirect.DEIndirect]()
            if byte == 0x22: return self.LD_ToIndirect[Indirect.HLIndirectPlus]()
            if byte == 0x32: return self.LD_ToIndirect[Indirect.HLIndirectMinus]()
            if byte == 0xea: return self.LD_ToIndirect[Indirect.WordIndirect]()

            if byte == 0x01: return self.LD[WordTarget.BC]()
            if byte == 0x11: return self.LD[WordTarget.DE]()
            if byte == 0x21: return self.LD[WordTarget.HL]()
            if byte == 0x31: return self.LD[WordTarget.SP]()

            if byte == 0x40: return self.LD[ByteTarget.B, ByteTarget.B]()
            if byte == 0x41: return self.LD[ByteTarget.B, ByteTarget.C]()
            if byte == 0x42: return self.LD[ByteTarget.B, ByteTarget.D]()
            if byte == 0x43: return self.LD[ByteTarget.B, ByteTarget.E]()
            if byte == 0x44: return self.LD[ByteTarget.B, ByteTarget.H]()
            if byte == 0x45: return self.LD[ByteTarget.B, ByteTarget.L]()
            if byte == 0x46: return self.LD[ByteTarget.B, ByteTarget.HLI]()
            if byte == 0x47: return self.LD[ByteTarget.B, ByteTarget.A]()

            if byte == 0x48: return self.LD[ByteTarget.C, ByteTarget.B]()
            if byte == 0x49: return self.LD[ByteTarget.C, ByteTarget.C]()
            if byte == 0x4a: return self.LD[ByteTarget.C, ByteTarget.D]()
            if byte == 0x4b: return self.LD[ByteTarget.C, ByteTarget.E]()
            if byte == 0x4c: return self.LD[ByteTarget.C, ByteTarget.H]()
            if byte == 0x4d: return self.LD[ByteTarget.C, ByteTarget.L]()
            if byte == 0x4e: return self.LD[ByteTarget.C, ByteTarget.HLI]()
            if byte == 0x4f: return self.LD[ByteTarget.C, ByteTarget.A]()

            if byte == 0x50: return self.LD[ByteTarget.D, ByteTarget.B]()
            if byte == 0x51: return self.LD[ByteTarget.D, ByteTarget.C]()
            if byte == 0x52: return self.LD[ByteTarget.D, ByteTarget.D]()
            if byte == 0x53: return self.LD[ByteTarget.D, ByteTarget.E]()
            if byte == 0x54: return self.LD[ByteTarget.D, ByteTarget.H]()
            if byte == 0x55: return self.LD[ByteTarget.D, ByteTarget.L]()
            if byte == 0x56: return self.LD[ByteTarget.D, ByteTarget.HLI]()
            if byte == 0x57: return self.LD[ByteTarget.D, ByteTarget.A]()

            if byte == 0x58: return self.LD[ByteTarget.E, ByteTarget.B]()
            if byte == 0x59: return self.LD[ByteTarget.E, ByteTarget.C]()
            if byte == 0x5a: return self.LD[ByteTarget.E, ByteTarget.D]()
            if byte == 0x5b: return self.LD[ByteTarget.E, ByteTarget.E]()
            if byte == 0x5c: return self.LD[ByteTarget.E, ByteTarget.H]()
            if byte == 0x5d: return self.LD[ByteTarget.E, ByteTarget.L]()
            if byte == 0x5e: return self.LD[ByteTarget.E, ByteTarget.HLI]()
            if byte == 0x5f: return self.LD[ByteTarget.E, ByteTarget.A]()

            if byte == 0x60: return self.LD[ByteTarget.H, ByteTarget.B]()
            if byte == 0x61: return self.LD[ByteTarget.H, ByteTarget.C]()
            if byte == 0x62: return self.LD[ByteTarget.H, ByteTarget.D]()
            if byte == 0x63: return self.LD[ByteTarget.H, ByteTarget.E]()
            if byte == 0x64: return self.LD[ByteTarget.H, ByteTarget.H]()
            if byte == 0x65: return self.LD[ByteTarget.H, ByteTarget.L]()
            if byte == 0x66: return self.LD[ByteTarget.H, ByteTarget.HLI]()
            if byte == 0x67: return self.LD[ByteTarget.H, ByteTarget.A]()

            if byte == 0x68: return self.LD[ByteTarget.L, ByteTarget.B]()
            if byte == 0x69: return self.LD[ByteTarget.L, ByteTarget.C]()
            if byte == 0x6a: return self.LD[ByteTarget.L, ByteTarget.D]()
            if byte == 0x6b: return self.LD[ByteTarget.L, ByteTarget.E]()
            if byte == 0x6c: return self.LD[ByteTarget.L, ByteTarget.H]()
            if byte == 0x6d: return self.LD[ByteTarget.L, ByteTarget.L]()
            if byte == 0x6e: return self.LD[ByteTarget.L, ByteTarget.HLI]()
            if byte == 0x6f: return self.LD[ByteTarget.L, ByteTarget.A]()

            if byte == 0x70: return self.LD[ByteTarget.HLI, ByteTarget.B]()
            if byte == 0x71: return self.LD[ByteTarget.HLI, ByteTarget.C]()
            if byte == 0x72: return self.LD[ByteTarget.HLI, ByteTarget.D]()
            if byte == 0x73: return self.LD[ByteTarget.HLI, ByteTarget.E]()
            if byte == 0x74: return self.LD[ByteTarget.HLI, ByteTarget.H]()
            if byte == 0x75: return self.LD[ByteTarget.HLI, ByteTarget.L]()
            if byte == 0x77: return self.LD[ByteTarget.HLI, ByteTarget.A]()

            if byte == 0x78: return self.LD[ByteTarget.A, ByteTarget.B]()
            if byte == 0x79: return self.LD[ByteTarget.A, ByteTarget.C]()
            if byte == 0x7a: return self.LD[ByteTarget.A, ByteTarget.D]()
            if byte == 0x7b: return self.LD[ByteTarget.A, ByteTarget.E]()
            if byte == 0x7c: return self.LD[ByteTarget.A, ByteTarget.H]()
            if byte == 0x7d: return self.LD[ByteTarget.A, ByteTarget.L]()
            if byte == 0x7e: return self.LD[ByteTarget.A, ByteTarget.HLI]()
            if byte == 0x7f: return self.LD[ByteTarget.A, ByteTarget.A]()

            if byte == 0x3e: return self.LD[ByteTarget.A, ByteTarget.D8]()
            if byte == 0x06: return self.LD[ByteTarget.B, ByteTarget.D8]()
            if byte == 0x0e: return self.LD[ByteTarget.C, ByteTarget.D8]()
            if byte == 0x16: return self.LD[ByteTarget.D, ByteTarget.D8]()
            if byte == 0x1e: return self.LD[ByteTarget.E, ByteTarget.D8]()
            if byte == 0x26: return self.LD[ByteTarget.H, ByteTarget.D8]()
            if byte == 0x2e: return self.LD[ByteTarget.L, ByteTarget.D8]()
            if byte == 0x36: return self.LD[ByteTarget.HLI, ByteTarget.D8]()

            if byte == 0xe0: return self.LD_FromA()
            if byte == 0xf0: return self.LD_ToA()

            if byte == 0x08: return self.LD_FromSP()
            if byte == 0xf9: return self.LD_SPFromHL()
            if byte == 0xf8: return self.LD_HLFromSPN()

            if byte == 0xc5: return self.PUSH[WordTarget.BC]()
            if byte == 0xd5: return self.PUSH[WordTarget.DE]()
            if byte == 0xe5: return self.PUSH[WordTarget.HL]()
            if byte == 0xf5: return self.PUSH[WordTarget.AF]()

            if byte == 0xc1: return self.POP[WordTarget.BC]()
            if byte == 0xd1: return self.POP[WordTarget.DE]()
            if byte == 0xe1: return self.POP[WordTarget.HL]()
            if byte == 0xf1: return self.POP[WordTarget.AF]()

            if byte == 0xc4: return self.CALL[JumpTest.NotZero]()
            if byte == 0xd4: return self.CALL[JumpTest.NotCarry]()
            if byte == 0xcc: return self.CALL[JumpTest.Zero]()
            if byte == 0xdc: return self.CALL[JumpTest.Carry]()
            if byte == 0xcd: return self.CALL[JumpTest.Always]()

            if byte == 0xc0: return self.RET[JumpTest.NotZero]()
            if byte == 0xd0: return self.RET[JumpTest.NotCarry]()
            if byte == 0xc8: return self.RET[JumpTest.Zero]()
            if byte == 0xd8: return self.RET[JumpTest.Carry]()
            if byte == 0xc9: return self.RET[JumpTest.Always]()
            if byte == 0xd9: return self.RETI()

            if byte == 0xc7: return self.RST[RSTLocation.X00]()
            if byte == 0xd7: return self.RST[RSTLocation.X10]()
            if byte == 0xe7: return self.RST[RSTLocation.X20]()
            if byte == 0xf7: return self.RST[RSTLocation.X30]()
            if byte == 0xcf: return self.RST[RSTLocation.X08]()
            if byte == 0xdf: return self.RST[RSTLocation.X18]()
            if byte == 0xef: return self.RST[RSTLocation.X28]()
            if byte == 0xff: return self.RST[RSTLocation.X38]()

            if byte == 0x00: return self.NOP()
            if byte == 0x76: return self.HALT()
            if byte == 0xf3: return self.DI()
            if byte == 0xfb: return self.EI()

            raise Error(String("Invalid unprefixed instruction", String(byte)))