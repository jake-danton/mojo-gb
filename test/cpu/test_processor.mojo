from src import *
from testing import *
from memory import UnsafePointer, memset_zero, stack_allocation

fn clean_cpu() -> CPU[ROM_BANK_0_SIZE + ROM_BANK_N_SIZE]:
    var boot_rom = UnsafePointer[Byte].alloc(BOOT_ROM_SIZE)
    memset_zero(boot_rom, BOOT_ROM_SIZE)
    var game_rom = UnsafePointer[Byte].alloc(ROM_BANK_0_SIZE + ROM_BANK_N_SIZE)
    memset_zero(game_rom, ROM_BANK_0_SIZE + ROM_BANK_N_SIZE)
    var bus = MemoryBus(boot_rom, game_rom)
    var cpu = CPU[ROM_BANK_0_SIZE + ROM_BANK_N_SIZE](bus^)
    cpu.bus.boot_rom_disabled = True
    return cpu^

fn check_flags(cpu: CPU[ROM_BANK_0_SIZE + ROM_BANK_N_SIZE], zero: Bool = False, subtract: Bool = False, half_carry: Bool = False, carry: Bool = False) raises:
    var flags = cpu.registers.f
    assert_equal(flags.zero, zero)
    assert_equal(flags.subtract, subtract)
    assert_equal(flags.half_carry, half_carry)
    assert_equal(flags.carry, carry)

# INC

fn test_execute_inc_8bit_non_overflow() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    var _result = cpu.INC[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0x8)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)


fn test_execute_inc_8bit_half_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0xF
    var _result = cpu.INC[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0x10)
    check_flags(cpu, zero = False, subtract = False, half_carry = True, carry = False)


fn test_execute_inc_8bit_overflow() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0xFF
    var _result = cpu.INC[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0x0)
    check_flags(cpu, zero = True, subtract = False, half_carry = True, carry = False)


fn test_execute_inc_16bit_byte_overflow() raises:
    var cpu = clean_cpu()
    cpu.registers.set_bc(0xFF)
    var _result = cpu.INC[WordTarget.BC]()

    assert_equal(cpu.registers.get_bc(), 0x0100)
    assert_equal(cpu.registers.b, 0x01)
    assert_equal(cpu.registers.c, 0x00)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)


fn test_execute_inc_16bit_overflow() raises:
    var cpu = clean_cpu()
    cpu.registers.set_bc(0xFFFF)
    var _result = cpu.INC[WordTarget.BC]()

    assert_equal(cpu.registers.get_bc(), 0x0)
    assert_equal(cpu.registers.b, 0x00)
    assert_equal(cpu.registers.c, 0x00)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)

# DEC

fn test_execute_dec_8bit_non_overflow() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    var _result = cpu.DEC[ByteTarget.A]()
    
    assert_equal(cpu.registers.a, 0x6)
    check_flags(cpu, zero = False, subtract = True, half_carry = False, carry = False)


fn test_execute_dec_8bit_half_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x80
    var _result = cpu.DEC[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0x7f)
    check_flags(cpu, zero = False, subtract = True, half_carry = True, carry = False)


fn test_execute_dec_8bit_underflow() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x0
    var _result = cpu.DEC[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0xFF)
    check_flags(cpu, zero = False, subtract = True, half_carry = True, carry = False)


fn test_execute_dec_16bit_underflow() raises:
    var cpu = clean_cpu()
    cpu.registers.set_bc(0x0000)
    var _result = cpu.DEC[WordTarget.BC]()

    assert_equal(cpu.registers.get_bc(), 0xFFFF)
    assert_equal(cpu.registers.b, 0xFF)
    assert_equal(cpu.registers.c, 0xFF)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)

# ADD

fn test_execute_add_8bit_non_overflow_target_a() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    var _result = cpu.ADD[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0xe)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)


fn test_execute_add_8bit_non_overflow_target_c() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    cpu.registers.c = 0x3
    var _result = cpu.ADD[ByteTarget.C]()

    assert_equal(cpu.registers.a, 0xa)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)


fn test_execute_add_8bit_non_overflow_target_c_with_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    cpu.registers.c = 0x3
    cpu.registers.f.carry = True
    var _result = cpu.ADD[ByteTarget.C]()

    assert_equal(cpu.registers.a, 0xa)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)


fn test_execute_add_8bit_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0xFC
    cpu.registers.b = 0x9
    var _result = cpu.ADD[ByteTarget.B]()

    assert_equal(cpu.registers.a, 0x05)
    check_flags(cpu, zero = False, subtract = False, half_carry = True, carry = True)

# ADDHL

fn test_execute_add_hl() raises:
    var cpu = clean_cpu()
    cpu.registers.b = 0x07
    cpu.registers.c = 0x00
    cpu.registers.h = 0x03
    cpu.registers.l = 0x00
    var _result = cpu.ADDHL[WordTarget.BC]()

    assert_equal(cpu.registers.get_hl(), 0x0A00)
    check_flags(cpu, zero = False, subtract = False, half_carry = True, carry = False)

# ADC

fn test_execute_addc_8bit_non_overflow_target_a_no_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    var _result = cpu.ADD[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0xe)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)


fn test_execute_addc_8bit_non_overflow_target_a_with_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    cpu.registers.f.carry = True
    var _result = cpu.ADC[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0xf)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)


fn test_execute_addc_8bit_non_overflow_target_c_with_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    cpu.registers.c = 0x3
    cpu.registers.f.carry = True
    var _result = cpu.ADC[ByteTarget.C]()

    assert_equal(cpu.registers.a, 0xb)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)


fn test_execute_addc_8bit_carry_with_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0xFC
    cpu.registers.b = 0x3
    cpu.registers.f.carry = True
    var _result = cpu.ADC[ByteTarget.B]()

    assert_equal(cpu.registers.a, 0x00)
    check_flags(cpu, zero = True, subtract = False, half_carry = True, carry = True)

# SUB

fn test_execute_sub_8bit_non_underflow_target_a() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    var _result = cpu.SUB[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0x0)
    check_flags(cpu, zero = True, subtract = True, half_carry = False, carry = False)


fn test_execute_sub_8bit_non_underflow_target_c() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    cpu.registers.c = 0x3
    var _result = cpu.SUB[ByteTarget.C]()

    assert_equal(cpu.registers.a, 0x4)
    check_flags(cpu, zero = False, subtract = True, half_carry = False, carry = False)


fn test_execute_sub_8bit_non_overflow_target_c_with_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    cpu.registers.c = 0x3
    cpu.registers.f.carry = True
    var _result = cpu.SUB[ByteTarget.C]()

    assert_equal(cpu.registers.a, 0x4)
    check_flags(cpu, zero = False, subtract = True, half_carry = False, carry = False)


fn test_execute_sub_8bit_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x4
    cpu.registers.b = 0x9
    var _result = cpu.SUB[ByteTarget.B]()

    assert_equal(cpu.registers.a, 0xFB)
    check_flags(cpu, zero = False, subtract = True, half_carry = True, carry = True)

# SBC

fn test_execute_subc_8bit_non_overflow_target_a_no_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    var _result = cpu.SBC[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0x0)
    check_flags(cpu, zero = True, subtract = True, half_carry = False, carry = False)


fn test_execute_subc_8bit_non_overflow_target_a_with_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    cpu.registers.f.carry = True
    var _result = cpu.SBC[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0xFF)
    check_flags(cpu, zero = False, subtract = True, half_carry = True, carry = True)


fn test_execute_subc_8bit_non_overflow_target_c_with_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    cpu.registers.c = 0x3
    cpu.registers.f.carry = True
    var _result = cpu.SBC[ByteTarget.C]()

    assert_equal(cpu.registers.a, 0x3)
    check_flags(cpu, zero = False, subtract = True, half_carry = False, carry = False)

# AND

fn test_execute_and_8bit() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    var _result = cpu.AND[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0x7)
    check_flags(cpu, zero = False, subtract = False, half_carry = True, carry = False)


fn test_execute_and_8bit_with_zero() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x8
    var _result = cpu.AND[ByteTarget.B]()

    assert_equal(cpu.registers.a, 0x0)
    check_flags(cpu, zero = True, subtract = False, half_carry = True, carry = False)

# OR

fn test_execute_or_8bit() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    var _result = cpu.OR[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0x7)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)


fn test_execute_or_8bit_with_zero() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x8
    var _result = cpu.OR[ByteTarget.B]()

    assert_equal(cpu.registers.a, 0x8)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)

# XOR

fn test_execute_xor_8bit() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b0000_0111
    var _result = cpu.XOR[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0x0)
    check_flags(cpu, zero = True, subtract = False, half_carry = False, carry = False)


fn test_execute_xor_8bit_with_zero() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x8
    var _result = cpu.XOR[ByteTarget.B]()

    assert_equal(cpu.registers.a, 0x8)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)

# CP

fn test_execute_cp_8bit_non_underflow_target_a() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    var _result = cpu.CP[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0x7)
    check_flags(cpu, zero = True, subtract = True, half_carry = False, carry = False)


fn test_execute_cp_8bit_non_underflow_target_c() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    cpu.registers.c = 0x3
    var _result = cpu.CP[ByteTarget.C]()

    assert_equal(cpu.registers.a, 0x7)
    check_flags(cpu, zero = False, subtract = True, half_carry = False, carry = False)


fn test_execute_cp_8bit_non_overflow_target_c_with_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x7
    cpu.registers.c = 0x3
    cpu.registers.f.carry = True
    var _result = cpu.CP[ByteTarget.C]()

    assert_equal(cpu.registers.a, 0x7)
    check_flags(cpu, zero = False, subtract = True, half_carry = False, carry = False)


fn test_execute_cp_8bit_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x4
    cpu.registers.b = 0x9
    var _result = cpu.CP[ByteTarget.B]()

    assert_equal(cpu.registers.a, 0x4)
    check_flags(cpu, zero = False, subtract = True, half_carry = True, carry = True)

# RRA

fn test_execute_rra_8bit() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1
    var _result = cpu.RRA()

    assert_equal(cpu.registers.a, 0x0)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = True)

# RLA

fn test_execute_rla_8bit() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x80
    var _result = cpu.RLA()

    assert_equal(cpu.registers.a, 0x0)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = True)

# RRCA

fn test_execute_rrca_8bit() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1
    cpu.registers.f.carry = True
    var _result = cpu.RRCA()

    assert_equal(cpu.registers.a, 0x80)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = True)

# RLCA

fn test_execute_rlca_8bit() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0x80
    cpu.registers.f.carry = True
    var _result = cpu.RLCA()

    assert_equal(cpu.registers.a, 0x1)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = True)

# CPL

fn test_execute_cpl_8bit() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0100
    var _result = cpu.CPL()

    assert_equal(cpu.registers.a, 0b0100_1011)
    check_flags(cpu, zero = False, subtract = True, half_carry = True, carry = False)

# BIT

fn test_execute_bit_8bit_b1() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0100
    var _result = cpu.BIT[ByteTarget.A, BitPosition.B1]()

    assert_equal(cpu.registers.a, 0b1011_0100)
    check_flags(cpu, zero = True, subtract = False, half_carry = True, carry = False)


fn test_execute_bit_8bit_b2() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0100
    var _result = cpu.BIT[ByteTarget.A, BitPosition.B2]()

    assert_equal(cpu.registers.a, 0b1011_0100)
    check_flags(cpu, zero = False, subtract = False, half_carry = True, carry = False)

# RES

fn test_execute_res_8bit_b1() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0100
    var _result = cpu.RES[ByteTarget.A, BitPosition.B1]()

    assert_equal(cpu.registers.a, 0b1011_0100)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)


fn test_execute_res_8bit() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0100
    var _result = cpu.RES[ByteTarget.A, BitPosition.B2]()

    assert_equal(cpu.registers.a, 0b1011_0000)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)

# SET

fn test_execute_set_8bit_b1() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0100
    var _result = cpu.SET[ByteTarget.A, BitPosition.B1]()

    assert_equal(cpu.registers.a, 0b1011_0110)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)


fn test_execute_set_8bit_b2() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0100
    var _result = cpu.SET[ByteTarget.A, BitPosition.B2]()

    assert_equal(cpu.registers.a, 0b1011_0100)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)

# SRL

fn test_execute_srl_8bit() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0101
    var _result = cpu.SRL[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0b0101_1010)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = True)

# RR

fn test_execute_rr_no_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0101
    cpu.registers.f.carry = False
    var _result = cpu.RR[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0b0101_1010)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = True)


fn test_execute_rr_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0101
    cpu.registers.f.carry = True
    var _result = cpu.RR[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0b1101_1010)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = True)

# RL

fn test_execute_rl_no_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0101
    cpu.registers.f.carry = False
    var _result = cpu.RL[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0b0110_1010)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = True)


fn test_execute_rl_carry() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0101
    cpu.registers.f.carry = True
    var _result = cpu.RL[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0b0110_1011)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = True)

# SRA

fn test_execute_sra() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0101
    var _result = cpu.SRA[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0b1101_1010)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = True)

# SLA

fn test_execute_sla() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0101
    var _result = cpu.SLA[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0b0110_1010)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = True)

# SWAP

fn test_execute_swap() raises:
    var cpu = clean_cpu()
    cpu.registers.a = 0b1011_0101
    var _result = cpu.SWAP[ByteTarget.A]()

    assert_equal(cpu.registers.a, 0b0101_1011)
    check_flags(cpu, zero = False, subtract = False, half_carry = False, carry = False)

# JP

fn test_execute_jp() raises:
    var cpu = clean_cpu()
    cpu.pc = 0xF8
    cpu.bus.write_byte(0xF9, 0xFC)
    cpu.bus.write_byte(0xFA, 0x02)
    var result1 = cpu.JP[JumpTest.Always]()

    assert_equal(result1[0], 0x02FC)

    var result2 = cpu.JP[JumpTest.Carry]()

    assert_equal(result2[0], 0xFB)

# JR

fn test_execute_jr() raises:
    var cpu = clean_cpu()
    cpu.pc = 0xF8
    cpu.bus.write_byte(0xF9, 0x4)
    var result1 = cpu.JR[JumpTest.Always]()

    assert_equal(result1[0], 0xFE)

    cpu.bus.write_byte(0xF9, 0xFC) # == -4
    var result2 = cpu.JR[JumpTest.Always]()

    assert_equal(result2[0], 0xF6)

# LD a, (??)

fn test_execute_ld_a_indirect() raises:
    var cpu = clean_cpu()
    cpu.registers.set_bc(0xF9)
    cpu.bus.write_byte(0xF9, 0x4)
    var _result_bc = cpu.LD_FromIndirect[Indirect.BCIndirect]()

    assert_equal(cpu.registers.a, 0x04)

    cpu.registers.set_hl(0xA1)
    cpu.bus.write_byte(0xA1, 0x9)
    var _result_hl = cpu.LD_FromIndirect[Indirect.HLIndirectPlus]()

    assert_equal(cpu.registers.a, 0x09)
    assert_equal(cpu.registers.get_hl(), 0xA2)

# LD ?, ?

fn test_execute_ld_byte() raises:
    var cpu = clean_cpu()
    cpu.registers.b = 0x4
    var _result = cpu.LD[ByteTarget.D, ByteTarget.B]()

    assert_equal(cpu.registers.b, 0x4)
    assert_equal(cpu.registers.d, 0x4)

# PUSH/POP

fn test_execute_push_pop() raises:
    var cpu = clean_cpu()
    cpu.registers.b = 0x4
    cpu.registers.c = 0x89
    cpu.sp = 0x10
    var _result_push = cpu.PUSH[WordTarget.BC]()

    assert_equal(cpu.bus.read_byte(0xF), 0x04)
    assert_equal(cpu.bus.read_byte(0xE), 0x89)
    assert_equal(cpu.sp, 0xE)

    var _result_pop = cpu.POP[WordTarget.DE]()

    assert_equal(cpu.registers.d, 0x04)
    assert_equal(cpu.registers.e, 0x89)

# -----------------------------------------------------------------------------

# Step

fn test_test_step() raises:
    var cpu = clean_cpu()
    cpu.bus.write_byte(0, 0x23) # INC(HL)
    cpu.bus.write_byte(1, 0xB5) # OR(L)
    cpu.bus.write_byte(2, 0xCB) # PREFIX
    cpu.bus.write_byte(3, 0xe8) # SET(B, 5)
    for _i in range(3):
        var _result = cpu.step()
    
    assert_equal(cpu.registers.h, 0b0)
    assert_equal(cpu.registers.l, 0b1)
    assert_equal(cpu.registers.a, 0b1)
    assert_equal(cpu.registers.b, 0b0010_0000)
