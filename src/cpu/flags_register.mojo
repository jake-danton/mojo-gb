alias ZERO_FLAG_BYTE_POSITION = 7
alias SUBTRACT_FLAG_BYTE_POSITION = 6
alias HALF_CARRY_FLAG_BYTE_POSITION = 5
alias CARRY_FLAG_BYTE_POSITION = 4

@value
@register_passable("trivial")
struct FlagsRegister:
    var zero: Bool
    var subtract: Bool
    var half_carry: Bool
    var carry: Bool

    fn __init__(out self):
        self.zero = False
        self.subtract = False
        self.half_carry = False
        self.carry = False

    @implicit
    fn __init__(out self, byte: Byte):
        self.zero = ((byte >> ZERO_FLAG_BYTE_POSITION) & 0b1) != 0
        self.subtract = ((byte >> SUBTRACT_FLAG_BYTE_POSITION) & 0b1) != 0
        self.half_carry = ((byte >> HALF_CARRY_FLAG_BYTE_POSITION) & 0b1) != 0
        self.carry = ((byte >> CARRY_FLAG_BYTE_POSITION) & 0b1) != 0

    fn to_byte(self) -> Byte:
        return (1 if self.zero else 0) << ZERO_FLAG_BYTE_POSITION
            | (1 if self.subtract else 0) << SUBTRACT_FLAG_BYTE_POSITION
            | (1 if self.half_carry else 0) << HALF_CARRY_FLAG_BYTE_POSITION
            | (1 if self.carry else 0) << CARRY_FLAG_BYTE_POSITION
