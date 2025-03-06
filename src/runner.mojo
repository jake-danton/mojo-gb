from src import *
from src.log import LogLevel, log

from collections import Dict
from memory import memcpy
from python import Python, PythonObject
from time import sleep, perf_counter_ns

alias ONE_SECOND_IN_NANOSECONDS = 1_000_000_000
alias ONE_SECOND_IN_MICROS = 1_000_000_000
alias ONE_SECOND_IN_CYCLES = 4_190_000
alias NUMBER_OF_PIXELS = 23_040

alias SCREEN_HEIGHT: Int = 144
alias SCREEN_WIDTH: Int = 160

struct EmulatorRunner:
    """
    Handles input for a Game Boy emulator using self.pygame.
    Maps keyboard and gamepad inputs to Game Boy joypad buttons.
    """
    
    var pygame: PythonObject
    var screen: PythonObject
    var gb_surface: PythonObject
    var gb_white: PythonObject
    var gb_light_gray: PythonObject
    var gb_dark_gray: PythonObject
    var gb_black: PythonObject

    var scale: Int

    fn __init__(out self) raises:
        self.pygame = None
        self.screen = None
        self.gb_surface = None
        self.gb_white = None
        self.gb_light_gray = None
        self.gb_dark_gray = None
        self.gb_black = None
        self.scale = 1

    fn setup(mut self, scale: Int = 1) raises:
        """Initialize the input handler with default key mappings."""
        self.pygame = Python.import_module("pygame")

        self.pygame.init()
        self.pygame.joystick.init()

        # Check if any joysticks/controllers are connected
        var joystick_count = self.pygame.joystick.get_count()
        if joystick_count == 0:
            log[LogLevel.Info]("No joysticks connected")
        else:
            # Initialize the first joystick
            var joystick = self.pygame.joystick.Joystick(0)
            joystick.init()
            log[LogLevel.Info]("Initialized ", joystick.get_name())

        # Display initialization
        self.scale = scale
        self.screen = self.pygame.display.set_mode((scale * SCREEN_WIDTH, scale * SCREEN_HEIGHT))
        self.pygame.display.set_caption("Mojo Gameboy Emulator")

        self.gb_surface = self.pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT))
        self.gb_white = self.pygame.Color(255, 255, 255)
        self.gb_light_gray = self.pygame.Color(192, 192, 192)
        self.gb_dark_gray = self.pygame.Color(96, 96, 96)
        self.gb_black = self.pygame.Color(0, 0, 0)
        
    fn process_events(mut self, mut cpu: CPU) raises -> Bool:
        """Process pygame events and update joypad state."""
        for event in self.pygame.event.get():
            if event.type == self.pygame.QUIT:
                return False  # Signal to quit the emulator
                
            # Process keyboard input
            elif event.type == self.pygame.KEYDOWN:
                log[LogLevel.Debug]("Key down:", event.key)

                if event.key == self.pygame.K_RIGHT:
                    cpu.bus.joypad.right = True
                elif event.key == self.pygame.K_LEFT:
                    cpu.bus.joypad.left = True
                elif event.key == self.pygame.K_UP:
                    cpu.bus.joypad.up = True
                elif event.key == self.pygame.K_DOWN:
                    cpu.bus.joypad.down = True
                elif event.key == self.pygame.K_z:
                    cpu.bus.joypad.a = True
                elif event.key == self.pygame.K_x:
                    cpu.bus.joypad.b = True
                elif event.key == self.pygame.K_BACKSPACE:
                    cpu.bus.joypad.select = True
                elif event.key == self.pygame.K_RETURN:
                    cpu.bus.joypad.start = True
                    
                # Check for emulator-specific controls (e.g., quit on Escape)
                elif event.key == self.pygame.K_ESCAPE:
                    return False  # Signal to quit the emulator
                    
            elif event.type == self.pygame.KEYUP:
                log[LogLevel.Debug]("Key up:", event.key)
                if event.key == self.pygame.K_RIGHT:
                    cpu.bus.joypad.right = False
                elif event.key == self.pygame.K_LEFT:
                    cpu.bus.joypad.left = False
                elif event.key == self.pygame.K_UP:
                    cpu.bus.joypad.up = False
                elif event.key == self.pygame.K_DOWN:
                    cpu.bus.joypad.down = False
                elif event.key == self.pygame.K_z:
                    cpu.bus.joypad.a = False
                elif event.key == self.pygame.K_x:
                    cpu.bus.joypad.b = False
                elif event.key == self.pygame.K_BACKSPACE:
                    cpu.bus.joypad.select = False
                elif event.key == self.pygame.K_RETURN:
                    cpu.bus.joypad.start = False
            
            # Process gamepad input if available
            if event.type == self.pygame.JOYBUTTONDOWN:
                log[LogLevel.Debug]("Joystick button down:", event.value)
                if event.button == 0:
                    cpu.bus.joypad.a = True
                elif event.button == 1:
                    cpu.bus.joypad.b = True
                elif event.button == 6:
                    cpu.bus.joypad.select = True
                elif event.button == 7:
                    cpu.bus.joypad.start = True

            elif event.type == self.pygame.JOYBUTTONUP:
                log[LogLevel.Debug]("Joystick button up:", event.value)
                if event.button == 0:
                    cpu.bus.joypad.a = False
                elif event.button == 1:
                    cpu.bus.joypad.b = False
                elif event.button == 6:
                    cpu.bus.joypad.select = False
                elif event.button == 7:
                    cpu.bus.joypad.start = False

            elif event.type == self.pygame.JOYHATMOTION:
                log[LogLevel.Debug]("Joystick hat motion:", event.value)
                var x = event.value[0]
                var y = event.value[1]
                if x == 1:
                    cpu.bus.joypad.right = True
                    cpu.bus.joypad.left = False
                elif x == -1:
                    cpu.bus.joypad.left = True
                    cpu.bus.joypad.right = False
                else:
                    cpu.bus.joypad.right = False
                    cpu.bus.joypad.left = False
                
                if y == 1:
                    cpu.bus.joypad.down = True
                    cpu.bus.joypad.up = False
                elif y == -1:
                    cpu.bus.joypad.up = True
                    cpu.bus.joypad.down = False
                else:
                    cpu.bus.joypad.down = False
                    cpu.bus.joypad.up = False

            
        return True  # Continue running the emulator
     
    fn run(mut self, mut cpu: CPU) raises:
        alias CLOCK_SPEED = 4_194_304
        alias FRAME_RATE = 120
        alias ONE_SECOND_IN_NANOSECONDS = 1_000_000_000
        alias ONE_FRAME_IN_NANOSECONDS = 1_000_000_000 // FRAME_RATE
        alias ONE_FRAME_IN_CYCLES = CLOCK_SPEED // FRAME_RATE
        var last_render = perf_counter_ns()
        var cycles_elapsed_in_frame: UInt64 = 0
        var running = True
        while running:
            running = self.process_events(cpu)

            var cycles_to_run: UInt64 = ONE_FRAME_IN_CYCLES

            cycles_elapsed_in_frame = 0
            while cycles_elapsed_in_frame <= cycles_to_run:
                cycles_elapsed_in_frame += UInt64(cpu.step())

            var now = perf_counter_ns()
            if now - last_render >= ONE_FRAME_IN_NANOSECONDS:
                self.render_frame(cpu.bus.gpu)

                cycles_elapsed_in_frame = 0
                last_render = now

        self.pygame.quit()

    fn render_frame(self, mut gpu: GPU) raises:
        """Renders the Game Boy screen onto the Pygame window."""
        log[LogLevel.Debug]("Rendering frame")

        self.gb_surface.lock()
        var raw_pixels = self.pygame.surfarray.pixels2d(self.gb_surface)
        var pixel_updated = False

        for y in range(SCREEN_HEIGHT):
            if not gpu.dirty_lines[y]:
                log[LogLevel.Debug]("Skipping line", y)
                continue

            gpu.dirty_lines[y] = False
            pixel_updated = True
            for x in range(SCREEN_WIDTH):
                var gb_pixel = Int32(gpu.canvas_buffer[SCREEN_WIDTH * y + x])
                raw_pixels[x, y] = (0xFF << 24) | (gb_pixel << 16) | (gb_pixel << 8) | gb_pixel

        self.gb_surface.unlock()

        if not pixel_updated:
            log[LogLevel.Debug]("No pixels updated. Skipping frame.")
            return

        # Scale and blit onto the main screen
        var scaled_surface = self.pygame.transform.scale(self.gb_surface, (SCREEN_WIDTH * self.scale, SCREEN_HEIGHT * self.scale))
        self.screen.blit(scaled_surface, (0, 0))

        # Refresh the display
        self.pygame.display.flip()
