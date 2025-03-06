from src import *
from testing import *

fn clean_gpu() -> GPU[VRAM_BEGIN, VRAM_SIZE, OAM_SIZE]:
    var gpu = GPU[VRAM_BEGIN, VRAM_SIZE, OAM_SIZE]()
    return gpu^

fn test_mode_transition_horizontal_blank_to_vertical_blank() raises:
    var gpu = clean_gpu()
    gpu.lcd_display_enabled = True
    gpu.mode = Mode.HorizontalBlank
    gpu.line = 143
    gpu.cycles = 200

    var request = gpu.step(1)

    assert_equal(gpu.mode, Mode.VerticalBlank)
    assert_equal(gpu.line, 144)
    assert_equal(request, InterruptRequest.VBlank)

fn test_mode_transition_vertical_blank_to_oam_access() raises:
    var gpu = clean_gpu()
    gpu.lcd_display_enabled = True
    gpu.mode = Mode.VerticalBlank
    gpu.line = 153
    gpu.cycles = 456
    gpu.oam_interrupt_enabled = True

    var request = gpu.step(1)

    assert_equal(gpu.mode, Mode.OAMAccess)
    assert_equal(gpu.line, 0)
    assert_equal(request, InterruptRequest.LCDStat)

fn test_mode_transition_oam_access_to_vram_access() raises:
    var gpu = clean_gpu()
    gpu.lcd_display_enabled = True
    gpu.mode = Mode.OAMAccess
    gpu.cycles = 80

    var request = gpu.step(1)

    assert_equal(gpu.mode, Mode.VRAMAccess)
    assert_equal(request, InterruptRequest.Neither)

fn test_mode_transition_vram_access_to_horizontal_blank() raises:
    var gpu = clean_gpu()
    gpu.lcd_display_enabled = True
    gpu.mode = Mode.VRAMAccess
    gpu.cycles = 172
    gpu.hblank_interrupt_enabled = True

    var request = gpu.step(1)

    assert_equal(gpu.mode, Mode.HorizontalBlank)
    assert_equal(request, InterruptRequest.LCDStat)

fn test_mode_transition_horizontal_blank_to_oam_access() raises:
    var gpu = clean_gpu()
    gpu.lcd_display_enabled = True
    gpu.mode = Mode.HorizontalBlank
    gpu.line = 0
    gpu.cycles = 200
    gpu.oam_interrupt_enabled = True

    var request = gpu.step(1)

    assert_equal(gpu.mode, Mode.OAMAccess)
    assert_equal(gpu.line, 1)
    assert_equal(request, InterruptRequest.LCDStat)

fn test_write_vram_updates_tile_set() raises:
    var gpu = clean_gpu()
    gpu.write_vram(0, 0b0011_1010)
    gpu.write_vram(1, 0b0101_1100)

    var tile = gpu.tile_set[0]
    assert_equal(tile[0][0], TilePixelValue.Zero)
    assert_equal(tile[0][1], TilePixelValue.Two)
    assert_equal(tile[0][2], TilePixelValue.One)
    assert_equal(tile[0][3], TilePixelValue.Three)
    assert_equal(tile[0][4], TilePixelValue.Three)
    assert_equal(tile[0][5], TilePixelValue.Two)
    assert_equal(tile[0][6], TilePixelValue.One)
    assert_equal(tile[0][7], TilePixelValue.Zero)

fn test_write_oam_updates_object_data() raises:
    var gpu = clean_gpu()
    var object = gpu.object_datas[0]

    # Test the y only set writing to the first byte
    assert_equal(object.y, -8)
    gpu.write_oam(0, 0x10 + 1)
    object = gpu.object_datas[0]
    assert_equal(object.y, 1)

    # Test the x only set writing to the second byte
    assert_equal(object.x, -16)
    gpu.write_oam(1, 0x08 + 2)
    object = gpu.object_datas[0]
    assert_equal(object.x, 2)

    # Test the tile only set writing to the third byte
    assert_equal(object.tile, 0)
    gpu.write_oam(2, 3)
    object = gpu.object_datas[0]
    assert_equal(object.tile, 3)

    # Test the flags only set writing to the fourth byte
    assert_equal(object.palette, ObjectPalette.Zero)
    assert_equal(object.xflip, False)
    assert_equal(object.yflip, False)
    assert_equal(object.priority, False)
    gpu.write_oam(3, 0b01110000)
    object = gpu.object_datas[0]
    assert_equal(object.palette, ObjectPalette.One)
    assert_equal(object.xflip, True)
    assert_equal(object.yflip, True)
    assert_equal(object.priority, True)

fn test_interrupt_request_add() raises:
    var request = InterruptRequest.Neither
    request.add(InterruptRequest.VBlank)
    assert_equal(request, InterruptRequest.VBlank)

    request.add(InterruptRequest.LCDStat)
    assert_equal(request, InterruptRequest.Both)

    request.add(InterruptRequest.Neither)
    assert_equal(request, InterruptRequest.Both)

fn test_background_colors_from_u8() raises:
    var colors: BackgroundColors = Byte(0b11_10_01_00)
    assert_equal(
        colors,
        BackgroundColors(Color.White, Color.LightGray, Color.DarkGray, Color.Black)
    )

fn test_mode_transition_with_lcd_disabled() raises:
    var gpu = clean_gpu()
    gpu.lcd_display_enabled = False
    gpu.mode = Mode.HorizontalBlank
    gpu.cycles = 200

    var request = gpu.step(1)

    assert_equal(gpu.mode, Mode.HorizontalBlank)
    assert_equal(gpu.line, 0)
    assert_equal(request, InterruptRequest.Neither)

fn test_render_scan_line() raises:
    var gpu = clean_gpu()
    gpu.lcd_display_enabled = True
    gpu.background_display_enabled = True
    gpu.viewport_x_offset = 0
    gpu.viewport_y_offset = 0
    gpu.background_colors = BackgroundColors(Color.White, Color.LightGray, Color.DarkGray, Color.Black)
    gpu.vram[0x1800] = 0
    for i in range(8):
        for j in range(8):
            gpu.tile_set[0][i][j] = TilePixelValue.One

    gpu.background_and_window_data_select = BackgroundAndWindowDataSelect.X8000
    
    for y in range(gpu.SCREEN_HEIGHT):
        gpu.render_scan_line()
        gpu.line = (gpu.line + 1) % gpu.SCREEN_HEIGHT
        for x in range(gpu.SCREEN_WIDTH):
            var pixel_index = gpu.SCREEN_WIDTH * y + x
            assert_equal(gpu.canvas_buffer[pixel_index], Color.LightGray.to_byte())
