@always_inline
fn overflowing_add(a: Byte, b:Byte) -> Tuple[Byte, Bool]:
    var sum = UInt16(a) + UInt16(b)
    return (Byte(sum % 0x100), Bool(sum > 0xFF))

@always_inline
fn overflowing_add(a: UInt16, b:UInt16) -> Tuple[UInt16, Bool]:
    var sum = UInt32(a) + UInt32(b)
    return (UInt16(sum % 0x10000), Bool(sum > 0xFFFF))

@always_inline
fn overflowing_sub(a: Byte, b:Byte) -> Tuple[Byte, Bool]:
    var diff = UInt16(a) - UInt16(b)
    return (Byte(diff % 0x100), Bool(diff > 0xFF))

@always_inline
fn overflowing_sub(a: UInt16, b:UInt16) -> Tuple[UInt16, Bool]:
    var diff = UInt32(a) - UInt32(b)
    return (UInt16(diff % 0x10000), Bool(diff > 0xFFFF))

@always_inline
fn wrapping_add(a: Byte, b:Byte) -> Byte:
    return a + b

@always_inline
fn wrapping_add(a: UInt16, b:UInt16) -> UInt16:
    return a + b

@always_inline
fn wrapping_sub(a: Byte, b:Byte) -> Byte:
    return a - b

@always_inline
fn wrapping_sub(a: UInt16, b:UInt16) -> UInt16:
    return a - b

@always_inline
fn rotate_left(n: Byte, d: UInt8) -> Byte:
    """Rotates the bits of n to the left by d positions."""
    alias bit_width = 8
    var d_clamped = d % bit_width
    return ((n << d_clamped) | (n >> (bit_width - d_clamped))) & ((1 << bit_width) - 1)

@always_inline
fn rotate_right(n: Byte, d: UInt8) -> Byte:
    """Rotates the bits of n to the right by d positions."""
    alias bit_width = 8
    var d_clamped = d % bit_width
    return ((n >> d_clamped) | (n << (bit_width - d_clamped))) & ((1 << bit_width) - 1)