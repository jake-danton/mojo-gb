@value
@register_passable("trivial")
struct Serial(EqualityComparable):
    var sb_register: Byte
    var sc_register: Byte

    fn __init__(out self):
        self.sb_register = 0
        self.sc_register = 0

    fn __eq__(self, other: Serial) -> Bool:
        return (
            self.sb_register == other.sb_register
            and self.sc_register == other.sc_register
        )

    fn __ne__(self, other: Serial) -> Bool:
        return (
            self.sb_register != other.sb_register
            or self.sc_register != other.sc_register
        )
