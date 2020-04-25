const std = @import("std");
const builtin = @import("builtin");
const Timer = std.time.Timer;
const c = @import("./c.zig");

const constants = @import("./constants.zig");
const sdl = @import("./sdl.zig");
const platform = @import("./platform.zig");
const GameScreen = @import("./game/screen.zig").Screen;

const SCREEN_WIDTH = 640;
const SCREEN_HEIGHT = 480;

pub fn main() !void {
    const alloc = std.heap.c_allocator;

    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO | c.SDL_INIT_GAMECONTROLLER) != 0) {
        return sdl.logErr(error.InitFailed);
    }
    defer c.SDL_Quit();

    sdl.assertZero(c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_ES));
    sdl.assertZero(c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MAJOR_VERSION, 3));
    sdl.assertZero(c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MINOR_VERSION, 0));

    var window = c.SDL_CreateWindow("Voxel Game", c.SDL_WINDOWPOS_UNDEFINED_MASK, c.SDL_WINDOWPOS_UNDEFINED_MASK, SCREEN_WIDTH, SCREEN_HEIGHT, c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE) orelse {
        return sdl.logErr(error.CouldntCreateWindow);
    };
    defer c.SDL_DestroyWindow(window);

    var glcontext = c.SDL_GL_CreateContext(window);
    defer c.SDL_GL_DeleteContext(glcontext);

    // Enable vsync so that we don't eat up CPU rendering frames that can't be presented
    sdl.assertZero(c.SDL_GL_SetSwapInterval(1));

    if (builtin.mode == .Debug) {
        c.glEnable(c.GL_DEBUG_OUTPUT);
        c.glDebugMessageCallback(sdl.glErrCallback, null);
    }

    c.glEnable(c.GL_DEPTH_TEST);

    // Timestep based on the Gaffer on Games post, "Fix Your Timestep"
    //    https://www.gafferongames.com/post/fix_your_timestep/
    const MAX_DELTA = constants.MAX_DELTA_SECONDS;
    const TICK_DELTA = constants.TICK_DELTA_SECONDS;
    var timer = try Timer.start();
    var tickTime: f64 = 0.0;
    var accumulator: f64 = 0.0;
    var should_quit = false;

    // Initialize context
    var context = platform.Context{
        .window = window,
        .glcontext = &glcontext,
        .should_quit = &should_quit,
    };

    // Initialize app
    var screen = GameScreen.new(alloc);
    try screen.init(context);
    defer screen.deinit(context);

    while (!should_quit) {
        var delta = @intToFloat(f64, timer.lap()) / std.time.ns_per_s; // Delta in seconds
        if (delta > MAX_DELTA) {
            delta = MAX_DELTA; // Try to avoid spiral of death when lag hits
        }

        accumulator += delta;

        while (accumulator >= TICK_DELTA) {
            try screen.update(context, tickTime, TICK_DELTA);
            accumulator -= TICK_DELTA;
            tickTime += TICK_DELTA;
        }

        // Where the render is between two timesteps.
        // If we are halfway between frames (based on what's in the accumulator)
        // then alpha will be equal to 0.5
        const alpha = accumulator / TICK_DELTA;

        try screen.render(context, alpha);
    }
}
