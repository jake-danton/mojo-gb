from .utils import *

@value
@register_passable("trivial")
struct Column:
    var value: Byte
    
    alias Zero = Column(0)
    alias One = Column(1)

    fn __eq__(self, other: Column) -> Bool:
        return self.value == other.value

@value
struct Joypad:
    var column: Column
    var start: Bool
    var select: Bool
    var b: Bool
    var a: Bool
    var down: Bool
    var up: Bool
    var left: Bool
    var right: Bool

    fn __init__(out self):
        self.column = Column.Zero
        self.start = False
        self.select = False
        self.b = False
        self.a = False
        self.down = False
        self.up = False
        self.left = False
        self.right = False

    fn to_byte(self) -> Byte:
        var column_bit: Byte = 1 << 5 if self.column == Column.Zero else 1 << 4

        var bit_4 = bit(not ((self.down and self.reading_column_0())
                or (self.start and self.reading_column_1()))) << 3

        var bit_3 = bit(not ((self.up and self.reading_column_0())
                or (self.select and self.reading_column_1()))) << 2

        var bit_2 = bit(not ((self.left and self.reading_column_0())
                or (self.b and self.reading_column_1()))) << 1

        var bit_1 = bit(not ((self.right and self.reading_column_0())
                or (self.a and self.reading_column_1())))

        var row_bits = bit_4 | bit_3 | bit_2 | bit_1
        return column_bit | row_bits

    fn reading_column_0(self) -> Bool:
        return self.column == Column.Zero

    fn reading_column_1(self) -> Bool:
        return self.column == Column.One
