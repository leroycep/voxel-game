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

    pub fn init(self: @This()) !void {}

    pub fn deinit(self: @This()) !void {}

    pub fn update(self: *@This(), tickTime: f64, delta: f64) !void {}

    pub fn render(self: *@This(), ctx: platform.Context, alpha: f64) !void {
        c.SDL_GL_SwapWindow(ctx.window);
    }
};
