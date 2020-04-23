const std = @import("std");
const c = @import("../c.zig");
const platform = @import("../platform.zig");

pub const Screen = struct {
    alloc: *std.mem.Allocator,

    pub fn new(alloc: *std.mem.Allocator) @This() {
        return @This(){
            .alloc = alloc,
        };
    }

    pub fn init(self: @This(), ctx: platform.Context) !void {}

    pub fn deinit(self: @This(), ctx: platform.Context) void {}

    pub fn update(self: *@This(), ctx: platform.Context, tickTime: f64, delta: f64) !void {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                c.SDL_QUIT => ctx.should_quit.* = true,
                c.SDL_KEYDOWN => if (event.key.keysym.sym == c.SDLK_ESCAPE) {
                    ctx.should_quit.* = true;
                },
                else => {},
            }
        }
    }

    pub fn render(self: *@This(), ctx: platform.Context, alpha: f64) !void {
        c.SDL_GL_SwapWindow(ctx.window);
    }
};
