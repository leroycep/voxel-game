const std = @import("std");
const c = @import("../c.zig");
const platform = @import("../platform.zig");

const VERTEX_SHADER_SOURCE = @embedFile("./vertex.glsl");
const FRAGMENT_SHADER_SOURCE = @embedFile("./fragment.glsl");

const MAX_VOXELS = 1000;
const VERTS = [_]f32{
    -1.0, -1.0, 0.0,
    1.0,  -1.0, 0.0,
    -1.0, 1.0,  0.0,
    1.0,  1.0,  0.0,
};

pub const Screen = struct {
    alloc: *std.mem.Allocator,
    shader: u32,
    mesh_vbo: u32,
    position_vbo: u32,
    color_vbo: u32,
    voxel_count: u32,
    position_size_data: []f32,
    color_data: []u8,

    pub fn new(alloc: *std.mem.Allocator) @This() {
        return @This(){
            .alloc = alloc,
            .shader = 0,
            .mesh_vbo = 0,
            .position_vbo = 0,
            .color_vbo = 0,
            .voxel_count = 0,
            .position_size_data = &[_]f32{},
            .color_data = &[_]u8{},
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

        c.glGenBuffers(1, &self.mesh_vbo);
        c.glGenBuffers(1, &self.position_vbo);
        c.glGenBuffers(1, &self.color_vbo);

        // VBO containing 4 vertices of particles
        // All particles share these verts using instancing
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.mesh_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, VERTS.len * @sizeOf(f32), &VERTS, c.GL_STATIC_DRAW);

        // VBO containing position of each voxel billboard
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.position_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, MAX_VOXELS * 4 * @sizeOf(f32), null, c.GL_STREAM_DRAW);

        // VBO containing color of each voxel
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.color_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, MAX_VOXELS * 4 * @sizeOf(u8), null, c.GL_STREAM_DRAW);

        self.position_size_data = try self.alloc.alloc(f32, MAX_VOXELS);
        self.color_data = try self.alloc.alloc(u8, MAX_VOXELS);

        self.position_size_data[0] = 0.0;
        self.position_size_data[1] = 0.0;
        self.position_size_data[2] = 0.0;
        self.position_size_data[3] = 0.1;

        self.position_size_data[4] = -0.5;
        self.position_size_data[5] = 0.0;
        self.position_size_data[6] = 0.0;
        self.position_size_data[7] = 0.05;

        self.color_data[0] = 255;
        self.color_data[1] = 0;
        self.color_data[2] = 0;

        self.color_data[3] = 0;
        self.color_data[4] = 255;
        self.color_data[5] = 0;

        self.voxel_count = 2;
    }

    pub fn deinit(self: *@This(), ctx: platform.Context) void {
        self.alloc.free(self.position_size_data);
        self.alloc.free(self.color_data);
    }

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
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.position_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, MAX_VOXELS * 4 * @sizeOf(f32), null, c.GL_STREAM_DRAW);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, self.voxel_count * 4 * @sizeOf(f32), self.position_size_data.ptr);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.color_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, MAX_VOXELS * 4 * @sizeOf(u8), null, c.GL_STREAM_DRAW);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, self.voxel_count * 4 * @sizeOf(u8), self.color_data.ptr);

        // 1st attribute buffer: vertices
        c.glEnableVertexAttribArray(0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.mesh_vbo);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 0, null);

        // 2nd attribute buffer: vertices
        c.glEnableVertexAttribArray(1);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.position_vbo);
        c.glVertexAttribPointer(1, 4, c.GL_FLOAT, c.GL_FALSE, 0, null);

        // 3rd attribute buffer: vertices
        c.glEnableVertexAttribArray(2);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.color_vbo);
        c.glVertexAttribPointer(2, 4, c.GL_UNSIGNED_BYTE, c.GL_TRUE, 0, null);

        c.glUseProgram(self.shader);

        c.glVertexAttribDivisor(0, 0);
        c.glVertexAttribDivisor(1, 1);
        c.glVertexAttribDivisor(2, 1);

        c.glDrawArraysInstanced(c.GL_TRIANGLE_STRIP, 0, 4, @intCast(c_int, self.voxel_count));

        c.SDL_GL_SwapWindow(ctx.window);
    }
};
