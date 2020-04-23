const std = @import("std");
const c = @import("../c.zig");
const platform = @import("../platform.zig");

const VERTEX_SHADER_SOURCE = @embedFile("./vertex.glsl");
const FRAGMENT_SHADER_SOURCE = @embedFile("./fragment.glsl");

pub const Screen = struct {
    alloc: *std.mem.Allocator,
    shader: u32,
    vbo: u32,

    pub fn new(alloc: *std.mem.Allocator) @This() {
        return @This(){
            .alloc = alloc,
            .shader = 0,
            .vbo = 0,
        };
    }

    pub fn init(self: *@This(), ctx: platform.Context) !void {
        const vertexShader = c.glCreateShader(c.GL_VERTEX_SHADER);
        defer c.glDeleteShader(vertexShader);
        _ = c.glShaderSource(vertexShader, 1, &(@as([:0]const u8, VERTEX_SHADER_SOURCE).ptr), null);
        _ = c.glCompileShader(vertexShader);

        const fragmentShader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        defer c.glDeleteShader(fragmentShader);
        _ = c.glShaderSource(fragmentShader, 1, &(@as([:0]const u8, FRAGMENT_SHADER_SOURCE).ptr), null);
        _ = c.glCompileShader(fragmentShader);

        self.shader = c.glCreateProgram();
        c.glAttachShader(self.shader, vertexShader);
        c.glAttachShader(self.shader, fragmentShader);
        c.glLinkProgram(self.shader);

        c.glGenBuffers(1, &self.vbo);
    }

    pub fn deinit(self: *@This(), ctx: platform.Context) void {}

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
        const VERTS = [_]f32{
            -0.5, -0.5, 0.0,
            0.5,  -0.5, 0.0,
            0.0,  0.5,  0.0,
        };

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, VERTS.len * @sizeOf(f32), &VERTS, c.GL_STATIC_DRAW);

        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
        c.glEnableVertexAttribArray(0);

        c.glUseProgram(self.shader);

        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

        c.SDL_GL_SwapWindow(ctx.window);
    }
};
