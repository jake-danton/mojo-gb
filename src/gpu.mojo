from .log import LogLevel, log
from .math import overflowing_add

from collections import InlineArray
from memory import UnsafePointer, memset_zero

from testing.testing import Testable

@value
@register_passable("trivial")
struct Color(Testable):
    var value: Byte

    alias White = Color(255)
    alias LightGray = Color(192)
    alias DarkGray = Color(96)
    alias Black = Color(0)

    fn __eq__(self, other: Color) -> Bool:
        return self.value == other.value
    
    fn __ne__(self, other: Color) -> Bool:
        return self.value != other.value

    fn to_byte(self) -> Byte:
        return self.value

    fn __str__(self) -> String:
        if self == Color.White:
            return "White"
        elif self == Color.LightGray:
            return "LightGray"
        elif self == Color.DarkGray:
            return "DarkGray"
        elif self == Color.Black:
            return "Black"
        else:
            return "Unknown"

    @staticmethod
    fn from_byte(value: Byte) raises -> Color:
        if value == 0:
            return Color.White
        elif value == 1:
            return Color.LightGray
        elif value == 2:
            return Color.DarkGray
        elif value == 3:
            return Color.Black
        else:
            raise Error("Cannot convert {} to color", value)

# TODO Tuple?
@value
@register_passable("trivial")
struct BackgroundColors(Testable):
    var color_0: Color
    var color_1: Color
    var color_2: Color
    var color_3: Color

    fn __init__(out self):
        self.color_0 = Color.White
        self.color_1 = Color.LightGray
        self.color_2 = Color.DarkGray
        self.color_3 = Color.Black

    # TODO Handle invalid byte better
    @implicit
    fn __init__(out self, value: Byte):
        try:
            self.color_0 = Color.from_byte(value & 0b11)
            self.color_1 = Color.from_byte((value >> 2) & 0b11)
            self.color_2 = Color.from_byte((value >> 4) & 0b11)
            self.color_3 = Color.from_byte(value >> 6)
        except Error:
            self.color_0 = Color.White
            self.color_1 = Color.LightGray
            self.color_2 = Color.DarkGray
            self.color_3 = Color.Black

    fn __eq__(self, other: BackgroundColors) -> Bool:
        return self.color_0 == other.color_0 and self.color_1 == other.color_1 and self.color_2 == other.color_2 and self.color_3 == other.color_3

    fn __ne__(self, other: BackgroundColors) -> Bool:
        return self.color_0 != other.color_0 or self.color_1 != other.color_1 or self.color_2 != other.color_2 or self.color_3 != other.color_3

    fn __str__(self) -> String:
        return String("BackgroundColors(", String(self.color_0), ", ", String(self.color_1), ", ", String(self.color_2), ", ", String(self.color_3), ")")

    fn to_byte(self) -> Byte:
        return self.color_0.to_byte() | (self.color_1.to_byte() << 2) | (self.color_2.to_byte() << 4) | (self.color_3.to_byte() << 6)

@value
@register_passable("trivial")
struct TileMap(EqualityComparable):
    var value: Byte

    alias X9800 = TileMap(0)
    alias X9C00 = TileMap(1)

    fn __eq__(self, other: TileMap) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: TileMap) -> Bool:
        return self.value != other.value

@value
@register_passable("trivial")
struct BackgroundAndWindowDataSelect(EqualityComparable):
    var value: Byte

    alias X8000 = BackgroundAndWindowDataSelect(0)
    alias X8800 = BackgroundAndWindowDataSelect(1)

    fn __eq__(self, other: BackgroundAndWindowDataSelect) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: BackgroundAndWindowDataSelect) -> Bool:
        return self.value != other.value

@value
@register_passable("trivial")
struct ObjectSize(EqualityComparable):
    var value: Byte

    alias OS8X8 = ObjectSize(0)
    alias OS8X16 = ObjectSize(1)

    fn __eq__(self, other: ObjectSize) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: ObjectSize) -> Bool:
        return self.value != other.value

@value
@register_passable("trivial")
struct Mode(EqualityComparable, Stringable):
    var value: Byte

    alias HorizontalBlank = Mode(0)
    alias VerticalBlank = Mode(1)
    alias OAMAccess = Mode(2)
    alias VRAMAccess = Mode(3)

    fn __eq__(self, other: Mode) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: Mode) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == Mode.HorizontalBlank:
            return "HorizontalBlank"
        elif self == Mode.VerticalBlank:
            return "VerticalBlank"
        elif self == Mode.OAMAccess:
            return "OAMAccess"
        elif self == Mode.VRAMAccess:
            return "VRAMAccess"
        else:
            return String("Unknown(", self.value, ")")

    fn to_byte(self) -> Byte:
        return self.value


@value
@register_passable("trivial")
struct TilePixelValue(EqualityComparable, Stringable):
    var value: Byte

    alias Zero = Self(0)
    alias One = Self(1)
    alias Two = Self(2)
    alias Three = Self(3)

    # TODO is this needed?
    fn __init__(out self):
        self.value = 0

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        return String(self.value)

@value
struct TileRow[ROW_SIZE: Int = 8](Sized):
    var data: UnsafePointer[TilePixelValue]

    fn __init__(out self):
        self.data = UnsafePointer[TilePixelValue].alloc(ROW_SIZE)
        for i in range(ROW_SIZE):
            self.data[i] = TilePixelValue.Zero

    fn __len__(self) -> Int:
        return ROW_SIZE

    fn __getitem__(self, index: UInt16) -> TilePixelValue:
        return self.data[index]

    fn __setitem__(mut self, index: UInt16, value: TilePixelValue):
        self.data[index] = value

@value
struct Tile[ROW_SIZE: Int = 8, COLUMN_SIZE: Int = 8](Sized):
    var data: UnsafePointer[TileRow[ROW_SIZE]]

    fn __init__(out self):
        self.data = UnsafePointer[TileRow[ROW_SIZE]].alloc(COLUMN_SIZE)
        for i in range(COLUMN_SIZE):
            self.data[i] = TileRow[ROW_SIZE]()

    fn __len__(self) -> Int:
        return Self.COLUMN_SIZE

    fn __getitem__(self, index: UInt16) -> TileRow[ROW_SIZE]:
        return self.data[index]
    
    fn __setitem__(mut self, index: UInt16, value: TileRow[ROW_SIZE]):
        self.data[index] = value

@value
struct TileSet[SIZE: Int = 384, ROW_SIZE: Int = 8, COLUMN_SIZE: Int = 8](Sized):
    var data: UnsafePointer[Tile[ROW_SIZE, COLUMN_SIZE]]

    fn __init__(out self):
        self.data = UnsafePointer[Tile[ROW_SIZE, COLUMN_SIZE]].alloc(SIZE)
        for i in range(SIZE):
            self.data[i] = Tile[ROW_SIZE, COLUMN_SIZE]()

    fn __len__(self) -> Int:
        return SIZE

    fn __getitem__(self, index: UInt16) -> Tile[ROW_SIZE, COLUMN_SIZE]:
        var result = self.data[index]
        return result

    fn __setitem__(mut self, index: UInt16, value: Tile[ROW_SIZE, COLUMN_SIZE]):
        self.data[index] = value

@value
@register_passable("trivial")
struct ObjectPalette(Testable):
    var value: Byte

    alias Zero = ObjectPalette(0)
    alias One = ObjectPalette(1)

    # TODO is this needed?
    fn __init__(out self):
        self.value = 0

    fn __eq__(self, other: ObjectPalette) -> Bool:
        return self.value == other.value
    
    fn __ne__(self, other: ObjectPalette) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == ObjectPalette.Zero:
            return "Zero"
        elif self == ObjectPalette.One:
            return "One"
        else:
            return String("Unknown(", self.value, ")")

@value
@register_passable("trivial")
struct ObjectData():
    var x: Int16
    var y: Int16
    var tile: Byte
    var palette: ObjectPalette
    var xflip: Bool
    var yflip: Bool
    var priority: Bool

    fn __init__(out self):
        self.x = -16
        self.y = -8
        self.tile = 0
        self.palette = ObjectPalette.Zero
        self.xflip = False
        self.yflip = False
        self.priority = False

@value
@register_passable("trivial")
struct InterruptRequest(Testable):
    var value: Byte

    alias Neither = InterruptRequest(0)
    alias VBlank = InterruptRequest(1)
    alias LCDStat = InterruptRequest(2)
    alias Both = InterruptRequest(3)

    fn __eq__(self, other: InterruptRequest) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: InterruptRequest) -> Bool:
        return self.value != other.value

    fn __str__(self) -> String:
        if self == InterruptRequest.Neither:
            return "Neither"
        elif self == InterruptRequest.VBlank:
            return "VBlank"
        elif self == InterruptRequest.LCDStat:
            return "LCDStat"
        elif self == InterruptRequest.Both:
            return "Both"
        else:
            return String("Unknown(", self.value, ")")

    fn add(mut self, other: InterruptRequest):
        if self == InterruptRequest.Neither:
            self = other
        elif self == InterruptRequest.VBlank and other == InterruptRequest.LCDStat:
            self = InterruptRequest.Both
        elif self == InterruptRequest.LCDStat and other == InterruptRequest.VBlank:
            self = InterruptRequest.Both

@value
struct Window:
    var x: Byte
    var y: Byte

struct GPU[VRAM_BEGIN: Int, VRAM_SIZE: Int, OAM_SIZE: Int, SCREEN_HEIGHT: Int = 144, SCREEN_WIDTH: Int = 160, NUMBER_OF_OBJECTS: Int = 40, NUMBER_OF_TILES: Int = 384, TILE_ROW_SIZE: Int = 8, TILE_COLUMN_SIZE: Int = 8]():
    var canvas_buffer: UnsafePointer[Byte]
    var tile_set: TileSet[NUMBER_OF_TILES, TILE_ROW_SIZE, TILE_COLUMN_SIZE]
    var object_datas: InlineArray[ObjectData, NUMBER_OF_OBJECTS]
    var vram: UnsafePointer[UInt8]
    var oam: InlineArray[UInt8, OAM_SIZE]

    var background_colors: BackgroundColors
    var viewport_x_offset: UInt8
    var viewport_y_offset: UInt8
    var lcd_display_enabled: Bool
    var window_display_enabled: Bool
    var background_display_enabled: Bool
    var object_display_enabled: Bool
    var line_equals_line_check_interrupt_enabled: Bool
    var oam_interrupt_enabled: Bool
    var vblank_interrupt_enabled: Bool
    var hblank_interrupt_enabled: Bool
    var line_check: UInt8
    var line_equals_line_check: Bool
    var window_tile_map: TileMap
    var background_tile_map: TileMap
    var background_and_window_data_select: BackgroundAndWindowDataSelect
    var object_size: ObjectSize
    var obj_0_color_1: Color
    var obj_0_color_2: Color
    var obj_0_color_3: Color
    var obj_1_color_1: Color
    var obj_1_color_2: Color
    var obj_1_color_3: Color
    var window: Window
    var line: UInt8
    var mode: Mode
    var cycles: UInt16

    # Performance optimization
    var dirty_lines: InlineArray[Bool, SCREEN_HEIGHT]

    fn __init__(out self):
        self.canvas_buffer = UnsafePointer[Byte].alloc(SCREEN_WIDTH * SCREEN_HEIGHT)
        memset_zero(self.canvas_buffer, SCREEN_WIDTH * SCREEN_HEIGHT)
        self.tile_set = TileSet[NUMBER_OF_TILES, TILE_ROW_SIZE, TILE_COLUMN_SIZE]()
        self.object_datas = InlineArray[ObjectData, NUMBER_OF_OBJECTS](ObjectData())
        # TODO move into its own thing?
        self.vram = UnsafePointer[UInt8].alloc(VRAM_SIZE)
        memset_zero(self.vram, VRAM_SIZE)
        self.oam = InlineArray[UInt8, OAM_SIZE](OAM_SIZE)

        self.background_colors = BackgroundColors()
        self.viewport_x_offset = 0
        self.viewport_y_offset = 0
        self.lcd_display_enabled = False
        self.window_display_enabled = False
        self.background_display_enabled = False
        self.object_display_enabled = False
        self.line_equals_line_check_interrupt_enabled = False
        self.oam_interrupt_enabled = False
        self.vblank_interrupt_enabled = False
        self.hblank_interrupt_enabled = False
        self.line_check = 0
        self.line_equals_line_check = False
        self.window_tile_map = TileMap.X9800
        self.background_tile_map = TileMap.X9800
        self.background_and_window_data_select = BackgroundAndWindowDataSelect.X8800
        self.object_size = ObjectSize.OS8X8
        self.obj_0_color_1 = Color.LightGray
        self.obj_0_color_2 = Color.DarkGray
        self.obj_0_color_3 = Color.Black
        self.obj_1_color_1 = Color.LightGray
        self.obj_1_color_2 = Color.DarkGray
        self.obj_1_color_3 = Color.Black
        self.window = Window(0, 0)
        self.line = 0
        self.cycles = 0
        self.mode = Mode.HorizontalBlank

        self.dirty_lines = InlineArray[Bool, SCREEN_HEIGHT](False)

    fn __del__(owned self):
        self.canvas_buffer.free()
        self.vram.free()

    fn __moveinit__(out self, owned existing: Self):
        self.canvas_buffer = existing.canvas_buffer
        self.tile_set = existing.tile_set
        self.object_datas = existing.object_datas
        self.vram = existing.vram
        self.oam = existing.oam
        self.background_colors = existing.background_colors
        self.viewport_x_offset = existing.viewport_x_offset
        self.viewport_y_offset = existing.viewport_y_offset
        self.lcd_display_enabled = existing.lcd_display_enabled
        self.window_display_enabled = existing.window_display_enabled
        self.background_display_enabled = existing.background_display_enabled
        self.object_display_enabled = existing.object_display_enabled
        self.line_equals_line_check_interrupt_enabled = existing.line_equals_line_check_interrupt_enabled
        self.oam_interrupt_enabled = existing.oam_interrupt_enabled
        self.vblank_interrupt_enabled = existing.vblank_interrupt_enabled
        self.hblank_interrupt_enabled = existing.hblank_interrupt_enabled
        self.line_check = existing.line_check
        self.line_equals_line_check = existing.line_equals_line_check
        self.window_tile_map = existing.window_tile_map
        self.background_tile_map = existing.background_tile_map
        self.background_and_window_data_select = existing.background_and_window_data_select
        self.object_size = existing.object_size
        self.obj_0_color_1 = existing.obj_0_color_1
        self.obj_0_color_2 = existing.obj_0_color_2
        self.obj_0_color_3 = existing.obj_0_color_3
        self.obj_1_color_1 = existing.obj_1_color_1
        self.obj_1_color_2 = existing.obj_1_color_2
        self.obj_1_color_3 = existing.obj_1_color_3
        self.window = existing.window
        self.line = existing.line
        self.cycles = existing.cycles
        self.mode = existing.mode
        self.dirty_lines = existing.dirty_lines^

    fn write_vram(mut self, index: UInt16, value: UInt8) raises:
        self.vram[index] = value
        if index >= 0x1800:
            return

        # Tiles rows are encoded in two bytes with the first byte always
        # on an even address. Bitwise ANDing the address with 0xffe
        # gives us the address of the first byte.
        # For example: `12 & 0xFFFE == 12` and `13 & 0xFFFE == 12`
        var normalized_index = index & 0xFFFE

        # First we need to get the two bytes that encode the tile row.
        var byte1 = self.vram[normalized_index]
        var byte2 = self.vram[normalized_index + 1]

        # A tiles is 8 rows tall. Since each row is encoded with two bytes a tile
        # is therefore 16 bytes in total.
        var tile_index = index / 16
        # Every two bytes is a new row
        var row_index = (index % 16) / 2

        # Now we're going to loop 8 times to get the 8 pixels that make up a given row.
        for pixel_index in range(8):
            # To determine a pixel's value we must first find the corresponding bit that encodes
            # that pixels value:
            # 1111_1111
            # 0123 4567
            #
            # As you can see the bit that corresponds to the nth pixel is the bit in the nth
            # position *from the left*. Bits are normally indexed from the right.
            #
            # To find the first pixel (a.k.a pixel 0) we find the left most bit (a.k.a bit 7). For
            # the second pixel (a.k.a pixel 1) we first the second most left bit (a.k.a bit 6) and
            # so on.
            #
            # We then create a mask with a 1 at that position and 0s everywhere else.
            #
            # Bitwise ANDing this mask with our bytes will leave that particular bit with its
            # original value and every other bit with a 0.
            var mask = 1 << (7 - pixel_index)
            var lsb = byte1 & mask
            var msb = byte2 & mask

            # If the masked values are not 0 the masked bit must be 1. If they are 0, the masked
            # bit must be 0.
            #
            # Finally we can tell which of the four tile values the pixel is. For example, if the least
            # significant byte's bit is 1 and the most significant byte's bit is also 1, then we
            # have tile value `Three`.

            @parameter
            fn match_value(lsb: UInt8, msb: UInt8) raises -> TilePixelValue:
                if lsb == 0 and msb == 0:
                    return TilePixelValue.Zero
                elif lsb != 0 and msb == 0:
                    return TilePixelValue.One
                elif lsb == 0 and msb != 0:
                    return TilePixelValue.Two
                elif lsb != 0 and msb != 0:
                    return TilePixelValue.Three
                raise Error("")

            var value = match_value(lsb, msb)

            self.tile_set[tile_index][row_index][pixel_index] = value

    fn write_oam(mut self, index: UInt16, value: UInt8):
        self.oam[index] = value
        var object_index = index / 4
        if object_index > NUMBER_OF_OBJECTS:
            return
        
        var byte = index % 4

        var data = self.object_datas[object_index]

        if byte == 0:
            data.y = Int16(value) - 0x10
        elif byte == 1:
            data.x = Int16(value) - 0x8
        elif byte == 2:
            data.tile = value
        else:
            data.palette = ObjectPalette.One if (value & 0x10) != 0 else ObjectPalette.Zero

            data.xflip = (value & 0x20) != 0
            data.yflip = (value & 0x40) != 0
            data.priority = (value & 0x80) == 0

        self.object_datas[object_index] = data
                        
    fn step(mut self, cycles: UInt8) raises -> InterruptRequest:
        var request = InterruptRequest.Neither
        if not self.lcd_display_enabled:
            return request

        self.cycles += UInt16(cycles)
        log[LogLevel.Debug]("Step ", self.cycles, " cycles in ", String(self.mode), " mode at line ", self.line)

        if self.mode == Mode.HorizontalBlank:
            log[LogLevel.Debug]("HBlank")
            if self.cycles >= 200:
                self.cycles = self.cycles % 200
                self.line += 1

                if self.line >= 144:
                    log[LogLevel.Debug]("HBlank -> VBlank")
                    self.mode = Mode.VerticalBlank
                    request.add(InterruptRequest.VBlank)
                    if self.vblank_interrupt_enabled:
                        request.add(InterruptRequest.LCDStat)
                else:
                    log[LogLevel.Debug]("HBlank -> OAMAccess")
                    self.mode = Mode.OAMAccess
                    if self.oam_interrupt_enabled:
                        request.add(InterruptRequest.LCDStat)
                self.set_equal_lines_check(request)
        elif self.mode == Mode.VerticalBlank:
            log[LogLevel.Debug]("VBlank")
            if self.cycles >= 456:
                self.cycles = self.cycles % 456
                self.line += 1
                if self.line == 154:
                    log[LogLevel.Debug]("VBlank -> OAMAccess")
                    self.mode = Mode.OAMAccess
                    self.line = 0
                    if self.oam_interrupt_enabled:
                        request.add(InterruptRequest.LCDStat)
                self.set_equal_lines_check(request)
        elif self.mode == Mode.OAMAccess:
            log[LogLevel.Debug]("OAMAccess")
            if self.cycles >= 80:
                self.cycles = self.cycles % 80
                log[LogLevel.Debug]("OAMAccess -> VRAMAccess")
                self.mode = Mode.VRAMAccess
        elif self.mode == Mode.VRAMAccess:
            log[LogLevel.Debug]("VRAMAccess")
            if self.cycles >= 172:
                self.cycles = self.cycles % 172
                if self.hblank_interrupt_enabled:
                    request.add(InterruptRequest.LCDStat)
                log[LogLevel.Debug]("VRAMAccess -> HBlank")
                self.mode = Mode.HorizontalBlank
                self.render_scan_line()
        return request

    fn set_equal_lines_check(mut self, mut request: InterruptRequest):
        var line_equals_line_check = self.line == self.line_check
        if line_equals_line_check and self.line_equals_line_check_interrupt_enabled:
            request.add(InterruptRequest.LCDStat)
        self.line_equals_line_check = line_equals_line_check

    fn background_1(self) -> UnsafePointer[UInt8]:
        return self.vram + 0x1800

    fn background_1_size(self) -> Int:
        return 0x1C00 - 0x1800

    fn render_scan_line(mut self) raises:
        log[LogLevel.Debug]("Rendering scan line")
        var scan_line = InlineArray[TilePixelValue, SCREEN_WIDTH](unsafe_uninitialized = True)
        if self.background_display_enabled:
            # The x index of the current tile
            var tile_x_index = UInt16(self.viewport_x_offset // 8)
            # The current scan line's y-offset in the entire background space is a combination
            # of both the line inside the view port we're currently on and the amount of the view port is scrolled
            var tile_y_index = UInt16(wrapping_add(self.line, self.viewport_y_offset))
            # The current tile we're on is equal to the total y offset broken up into 8 pixel chunks
            # and multipled by the width of the entire background (i.e. 32 tiles)
            var tile_offset = (tile_y_index // 8) * 32

            # Where is our tile map defined?
            var background_tile_map = 0x9800 if self.background_tile_map == TileMap.X9800 else 0x9C00
            # Munge this so that the beginning of VRAM is index 0
            var tile_map_begin = UInt16(background_tile_map - VRAM_BEGIN)
            # Where we are in the tile map is the beginning of the tile map
            # plus the current tile's offset
            var tile_map_offset = tile_map_begin + tile_offset

            # When line and scrollY are zero we just start at the top of the tile
            # If they're non-zero we must index into the tile cycling through 0 - 7
            var row_y_offset = tile_y_index % 8
            var pixel_x_index = UInt16(self.viewport_x_offset % 8)

            if self.background_and_window_data_select == BackgroundAndWindowDataSelect.X8800:
                raise Error("TODO: support 0x8800 background and window data select")

            var canvas_buffer_offset = UInt16(self.line) * SCREEN_WIDTH
            # Start at the beginning of the line and go pixel by pixel
            for line_x in range(SCREEN_WIDTH):
                # Grab the tile index specified in the tile map
                var tile_index = UInt16(self.vram[tile_map_offset + tile_x_index])

                var tile_value = self.tile_set[tile_index][row_y_offset][pixel_x_index]
                var color = self.tile_value_to_background_color(tile_value).to_byte()
                if color != self.canvas_buffer[canvas_buffer_offset]:
                    self.dirty_lines[self.line] = True
                    self.canvas_buffer[canvas_buffer_offset] = color

                canvas_buffer_offset += 1
                scan_line[line_x] = tile_value
                # Loop through the 8 pixels within the tile
                pixel_x_index = (pixel_x_index + 1) % 8

                # Check if we've fully looped through the tile
                if pixel_x_index == 0:
                    # Now increase the tile x_offset by 1
                    tile_x_index = tile_x_index + 1

                if self.background_and_window_data_select == BackgroundAndWindowDataSelect.X8800:
                    raise Error("TODO: support 0x8800 background and window data select")

        if self.object_display_enabled:
            var object_height = 16 if self.object_size == ObjectSize.OS8X16 else 8
            for object_index in range(len(self.object_datas)):
                var object_data = self.object_datas[object_index]
                var line =  Int16(self.line)
                if object_data.y <= line and object_data.y + object_height > line:
                    var pixel_y_offset = UInt16(line - object_data.y)
                    var tile_index = UInt16(object_data.tile + 1) if object_height == 16 and (not object_data.yflip and pixel_y_offset > 7) or (object_data.yflip and pixel_y_offset <= 7) else UInt16(object_data.tile)

                    var tile = self.tile_set[tile_index]
                    var tile_row = tile[(7 - (pixel_y_offset % 8))] if object_data.yflip else tile[(pixel_y_offset % 8)]

                    var canvas_y_offset = Int32(line * SCREEN_WIDTH)
                    var canvas_offset = UInt16((canvas_y_offset + Int32(object_data.x)))
                    for x in range(8):
                        var pixel_x_offset = UInt16(7 - x if object_data.xflip else x)
                        var x_offset = object_data.x + x
                        var pixel = tile_row[pixel_x_offset]
                        if x_offset >= 0
                            and x_offset < SCREEN_WIDTH
                            and pixel != TilePixelValue.Zero
                            and (object_data.priority
                                or scan_line[x_offset] == TilePixelValue.Zero):
                            var color = self.tile_value_to_background_color(pixel).to_byte()
                            if color != self.canvas_buffer[canvas_offset]:
                                self.dirty_lines[self.line] = True
                                self.canvas_buffer[canvas_offset] = color
    
                        canvas_offset += 1

        if self.window_display_enabled:
            pass

    fn tile_value_to_background_color(self, tile_value: TilePixelValue) raises -> Color:
        if tile_value == TilePixelValue.Zero:
            return self.background_colors.color_0
        if tile_value == TilePixelValue.One:
            return self.background_colors.color_1
        if tile_value == TilePixelValue.Two:
            return self.background_colors.color_2
        if tile_value == TilePixelValue.Three:
            return self.background_colors.color_3
        
        raise Error("Unrecognized TilePixelValue {}", String(tile_value))
