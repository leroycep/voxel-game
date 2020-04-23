const c = @import("./c.zig");

pub const Context = struct {
    should_quit: *bool,
    window: *c.SDL_Window,
    glcontext: *c.SDL_GLContext,
};
