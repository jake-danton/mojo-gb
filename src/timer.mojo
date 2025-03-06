@value
@register_passable("trivial")
struct Frequency(EqualityComparable):
    """
        The number of CPU cycles that occur per tick of the clock.
        This is equal to the number of cpu cycles per second (4194304)
        divided by the timer frequency.
    """
    var cycles_per_tick: Byte

    alias F4096 = Frequency(1024)
    alias F16384 = Frequency(256)
    alias F262144 = Frequency(16)
    alias F65536 = Frequency(64)

    fn __eq__(self, other: Frequency) -> Bool:
        return self.cycles_per_tick == other.cycles_per_tick

    fn __ne__(self, other: Frequency) -> Bool:
        return self.cycles_per_tick != other.cycles_per_tick

    @staticmethod
    fn from_byte(out self: Self, value: Byte):
        var value_two_bits = value & 0b11

        if value_two_bits == 0b00:
            self = Frequency.F4096
        elif value_two_bits == 0b11:
            self = Frequency.F16384
        elif value_two_bits == 0b10:
            self = Frequency.F65536
        else:
            self = Frequency.F262144

    fn to_byte(self) -> Byte:
        if self == Frequency.F4096:
            return 0b00
        elif self == Frequency.F16384:
            return 0b11
        elif self == Frequency.F65536:
            return 0b10
        else:
            return 0b01
        

struct Timer:
    var frequency: Frequency
    var cycles: UInt64
    var value: Byte
    var modulo: Byte
    var on: Bool

    fn __init__(out self, frequency: Frequency):
        self.frequency = frequency
        self.cycles = 0
        self.value = 0
        self.modulo = 0
        self.on = False
        
    fn __moveinit__(out self, owned existing: Self):
        self.frequency = existing.frequency
        self.cycles = existing.cycles
        self.value = existing.value
        self.modulo = existing.modulo
        self.on = existing.on

    fn step(mut self, cycles: Byte) -> Bool:
        if not self.on:
            return False

        self.cycles += UInt64(cycles)

        var cycles_per_tick = UInt64(self.frequency.cycles_per_tick)

        if self.cycles > cycles_per_tick:
            self.cycles = self.cycles % cycles_per_tick

            var result = overflowing_add(self.value, 1)

            self.value = result[0]

            var did_overflow = result[1]
            if did_overflow:
                self.value = self.modulo
            return did_overflow
        else:
            return False