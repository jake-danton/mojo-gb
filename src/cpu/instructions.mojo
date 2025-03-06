@value
@register_passable("trivial")
struct BitPosition(EqualityComparable, Stringable):
    var value: Byte

    alias B0 = BitPosition(0)
    alias B1 = BitPosition(1)
    alias B2 = BitPosition(2)
    alias B3 = BitPosition(3)
    alias B4 = BitPosition(4)
    alias B5 = BitPosition(5)
    alias B6 = BitPosition(6)
    alias B7 = BitPosition(7)

    @implicit
    fn __init__(out self, value: Byte):
        self.value = value

    fn __eq__(self, other: BitPosition) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: BitPosition) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == BitPosition.B0:
            return "0"
        elif self == BitPosition.B1:
            return "1"
        elif self == BitPosition.B2:
            return "2"
        elif self == BitPosition.B3:
            return "3"
        elif self == BitPosition.B4:
            return "4"
        elif self == BitPosition.B5:
            return "5"
        elif self == BitPosition.B6:
            return "6"
        elif self == BitPosition.B7:
            return "7"
        else:
            return String("BitPosition(", self.value, ")")

    fn to_byte(self) -> Byte:
        return self.value


@value
@register_passable("trivial")
struct ByteTarget(EqualityComparable, Stringable):
    var value: Byte

    alias A = Self(0)
    alias B = Self(1)
    alias C = Self(2)
    alias D = Self(3)
    alias E = Self(4)
    alias H = Self(5)
    alias L = Self(6)
    alias D8 = Self(7)
    alias HLI = Self(8)

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == Self.A:
            return "A"
        elif self == Self.B:
            return "B"
        elif self == Self.C:
            return "C"
        elif self == Self.D:
            return "D"
        elif self == Self.E:
            return "E"
        elif self == Self.H:
            return "H"
        elif self == Self.L:
            return "L"
        elif self == Self.D8:
            return "D8"
        elif self == Self.HLI:
            return "(HL)"
        else:
            return String("ByteTarget(", self.value, ")")

@value
@register_passable("trivial")
struct WordTarget(EqualityComparable, Stringable):
    var value: Byte

    alias AF = Self(0)
    alias BC = Self(1)
    alias DE = Self(2)
    alias HL = Self(3)
    alias SP = Self(4)

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value
    
    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == Self.AF:
            return "AF"        
        elif self == Self.BC:
            return "BC"
        elif self == Self.DE:
            return "DE"
        elif self == Self.HL:
            return "HL"
        elif self == Self.SP:
            return "SP"
        else:
            return String("WordTarget(", self.value, ")")

@value
@register_passable("trivial")
struct JumpTest(EqualityComparable, Stringable):
    var value : Byte

    alias NotZero = Self(0)
    alias NotCarry = Self(1)
    alias Zero = Self(2)
    alias Carry = Self(3)
    alias Always = Self(4)

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == Self.NotZero:
            return "NZ"
        elif self == Self.NotCarry:
            return "NC"
        elif self == Self.Zero:
            return "Z"
        elif self == Self.Carry:
            return "C"
        elif self == Self.Always:
            return "Always"
        else:
            return String("JumpTest(", self.value, ")")

@value
@register_passable("trivial")
struct Indirect(EqualityComparable, Stringable):
    var value: Byte

    alias BCIndirect = Self(0)
    alias DEIndirect = Self(1)
    alias HLIndirectMinus = Self(2)
    alias HLIndirectPlus = Self(3)
    alias WordIndirect = Self(4)
    alias LastByteIndirect = Self(5)

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == Self.BCIndirect:
            return "(BC)"
        elif self == Self.DEIndirect:
            return "(DE)"
        elif self == Self.HLIndirectMinus:
            return "(HL-)"
        elif self == Self.HLIndirectPlus:
            return "(HL+)"
        elif self == Self.WordIndirect:
            return "(word)"
        elif self == Self.LastByteIndirect:
            return "(FF00+C)"
        else:
            return String("Indirect(", self.value, ")")

@value
@register_passable("trivial")
struct LoadType(EqualityComparable, Stringable):
    var value: Byte

    # Byte(LoadByteTarget, LoadByteSource),
    # Word(LoadWordTarget),
    # AFromIndirect(Indirect),
    # IndirectFromA(Indirect),
    alias AFromByteAddress = Self(0)
    alias ByteAddressFromA = Self(1)
    alias SPFromHL = Self(2)
    alias HLFromSPN = Self(3)
    alias IndirectFromSP = Self(4)

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == Self.AFromByteAddress:
            return "A <- (byte)"
        elif self == Self.ByteAddressFromA:
            return "(byte) <- A"
        elif self == Self.SPFromHL:
            return "SP <- HL"
        elif self == Self.HLFromSPN:
            return "HL <- SP + n"
        elif self == Self.IndirectFromSP:
            return "(word) <- SP"
        else:
            return String("LoadType(", self.value, ")")

@value
@register_passable("trivial")
struct ByteMethod(EqualityComparable, Stringable):
    var value: Byte

    alias Inc = Self(0)
    alias Dec = Self(1)

    alias RotateRightThroughCarryRetainZero = Self(2)
    alias RotateRightRetainZero = Self(3)
    alias RotateLeftThroughCarryRetainZero = Self(4)
    alias RotateLeftRetainZero = Self(5)
    alias ShiftLeftArithmetic = Self(6)
    alias ShiftRightArithmetic = Self(7)

    alias SwapNibbles = Self(8)
    alias ShiftRightLogical = Self(9)

    alias Add = Self(10)
    alias AddHL = Self(11)
    alias AddWithCarry = Self(12)
    alias AddStackPointer = Self(13)

    alias Subtract = Self(14)
    alias SubtractWithCarry = Self(15)

    alias And = Self(16)
    alias Or = Self(17)
    alias Xor = Self(18)

    alias Compare = Self(19)

    alias Complement = Self(24)

    alias DecimalAdjust = Self(26)

    alias RotateRightThroughCarrySetZero = Self(27)
    alias RotateRightSetZero = Self(28)
    alias RotateLeftThroughCarrySetZero = Self(29)
    alias RotateLeftSetZero = Self(30)

    # alias Jump = Self(27)
    # alias JumpRelative = Self(28)
    # alias JumpHL = Self(29)

    # alias Load = Self(30)

    # alias Push = Self(31)
    # alias Pop = Self(32)
    # alias Call = Self(33)
    # alias Return = Self(34)

    # alias RETI = Self(35)
    # alias RST = Self(36)
    # alias NOP = Self(37)
    # alias HALT = Self(38)
    # alias DI = Self(39)
    # alias EI = Self(40)

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == Self.Inc:
            return "INC"
        elif self == Self.Dec:
            return "DEC"
        elif self == Self.RotateRightThroughCarryRetainZero:
            return "RRC"
        elif self == Self.RotateRightRetainZero:
            return "RR"
        elif self == Self.RotateLeftThroughCarryRetainZero:
            return "RLC"
        elif self == Self.RotateLeftRetainZero:
            return "RL"
        elif self == Self.ShiftLeftArithmetic:
            return "SLA"
        elif self == Self.ShiftRightArithmetic:
            return "SRA"
        elif self == Self.SwapNibbles:
            return "SWAP"
        elif self == Self.ShiftRightLogical:
            return "SRL"
        elif self == Self.Add:
            return "ADD"
        elif self == Self.AddHL:
            return "ADD HL"
        elif self == Self.AddWithCarry:
            return "ADC"
        elif self == Self.AddStackPointer:
            return "ADD SP"
        elif self == Self.Subtract:
            return "SUB"
        elif self == Self.SubtractWithCarry:
            return "SBC"
        elif self == Self.And:
            return "AND"
        elif self == Self.Or:
            return "OR"
        elif self == Self.Xor:
            return "XOR"
        elif self == Self.Compare:
            return "CP"
        elif self == Self.Complement:
            return "CPL"
        elif self == Self.DecimalAdjust:
            return "DAA"
        else:
            return String("ByteMethod(", self.value, ")")


@value
@register_passable("trivial")
struct WordMethod(EqualityComparable, Stringable):
    var value: Byte

    alias Inc = Self(0)
    alias Dec = Self(1)

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == Self.Inc:
            return "INC"
        elif self == Self.Dec:
            return "DEC"
        else:
            return String("WordMethod(", self.value, ")")

@value
@register_passable("trivial")
struct BitMethod(EqualityComparable, Stringable):
    var value: Byte

    alias BitTest = Self(0)
    alias ResetBit = Self(1)
    alias SetBit = Self(2)

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == Self.BitTest:
            return "BIT"
        elif self == Self.ResetBit:
            return "RES"
        elif self == Self.SetBit:
            return "SET"
        else:
            return String("BitMethod(", self.value, ")")

@value
@register_passable("trivial")
struct RSTLocation(EqualityComparable, Stringable):
    var value: UInt16

    alias X00 = Self(0x00)
    alias X08 = Self(0x08)
    alias X10 = Self(0x10)
    alias X18 = Self(0x18)
    alias X20 = Self(0x20)
    alias X28 = Self(0x28)
    alias X30 = Self(0x30)
    alias X38 = Self(0x38)

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == Self.X00:
            return "0x00"
        elif self == Self.X08:
            return "0x08"
        elif self == Self.X10:
            return "0x10"
        elif self == Self.X18:
            return "0x18"
        elif self == Self.X20:
            return "0x20"
        elif self == Self.X28:
            return "0x28"
        elif self == Self.X30:
            return "0x30"
        elif self == Self.X38:
            return "0x38"
        else:
            return String("RSTLocation(", self.value, ")")

    fn to_hex(self) -> UInt16:
        return self.value
