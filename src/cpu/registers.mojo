from .flags_register import FlagsRegister

@value
@register_passable("trivial")
struct Registers:
    var a: Byte
    var b: Byte
    var c: Byte
    var d: Byte
    var e: Byte
    var f: FlagsRegister
    var h: Byte
    var l: Byte

    fn __init__(out self):
        self.a = 0
        self.b = 0
        self.c = 0
        self.d = 0
        self.e = 0
        self.f = FlagsRegister()
        self.h = 0
        self.l = 0

    fn get_af(self) -> UInt16:
        return (UInt16(self.a) << 8) | UInt16(self.f.to_byte())

    fn set_af(mut self, value: UInt16):
        self.a = UInt8((value & 0xFF00) >> 8)
        self.f = FlagsRegister(UInt8(value & 0xFF))

    fn get_bc(self) -> UInt16:
        return (UInt16(self.b) << 8) | UInt16(self.c)

    fn set_bc(mut self, value: UInt16):
        self.b = UInt8((value & 0xFF00) >> 8)
        self.c = UInt8(value & 0xFF)

    fn get_de(self) -> UInt16:
        return (UInt16(self.d) << 8) | UInt16(self.e)

    fn set_de(mut self, value: UInt16):
        self.d = UInt8((value & 0xFF00) >> 8)
        self.e = UInt8(value & 0xFF)

    fn get_hl(self) -> UInt16:
        return (UInt16(self.h) << 8) | UInt16(self.l)

    fn set_hl(mut self, value: UInt16):
        self.h = UInt8((value & 0xFF00) >> 8)
        self.l = UInt8(value & 0xFF)
