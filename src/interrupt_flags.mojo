@value
@register_passable("trivial")
struct InterruptFlags:
    var vblank: Bool
    var lcdstat: Bool
    var timer: Bool
    var serial: Bool
    var joypad: Bool

    fn __init__(out self):
        self.vblank = False
        self.lcdstat = False
        self.timer = False
        self.serial = False
        self.joypad = False

    @implicit
    fn __init__(out self, byte: Byte):
        self.vblank = (byte & 0b1) == 0b1
        self.lcdstat = (byte & 0b10) == 0b10
        self.timer = (byte & 0b100) == 0b100
        self.serial = (byte & 0b1000) == 0b1000
        self.joypad = (byte & 0b10000) == 0b10000

    fn to_byte(self) -> Byte:
        # unused bits always read as 1s
        return 0b11100000 |
               ((1 if self.joypad else 0) << 4) |
               ((1 if self.serial else 0) << 3) |
               ((1 if self.timer else 0) << 2) |
               ((1 if self.lcdstat else 0) << 1) |
               (1 if self.vblank else 0)