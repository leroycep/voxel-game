const c = @import("./c.zig");

pub const Context = struct {
    window: *c.SDL_Window,
    glcontext: *c.SDL_GLContext,
};
