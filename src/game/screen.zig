const std = @import("std");
const c = @import("../c.zig");
const platform = @import("../platform.zig");
const Vec3 = @import("../utils/vec3.zig").Vec3;
const Vec3f = Vec3(f32);
const mat4 = @import("../utils/mat4.zig");
const sin = std.math.sin;
const cos = std.math.cos;

const VERTEX_SHADER_SOURCE = @embedFile("./vertex.glsl");
const FRAGMENT_SHADER_SOURCE = @embedFile("./fragment.glsl");
const RAYBOX_VERTEX_SOURCE = @embedFile("./raybox_vertex.glsl");
const RAYBOX_FRAGMENT_SOURCE = @embedFile("./raybox_fragment.glsl");

const MAX_VOXELS = 1000;
const VERTS = [_]f32{
    -0.5, 0.5,  0.5, // Front-top-left
    0.5,  0.5,  0.5, // Front-top-right
    -0.5, -0.5, 0.5, // Front-bottom-left
    0.5,  -0.5, 0.5, // Front-bottom-right
    0.5,  -0.5, -0.5, // Back-bottom-right
    0.5,  0.5,  0.5, // Front-top-right
    0.5,  0.5,  -0.5, // Back-top-right
    -0.5, 0.5,  0.5, // Front-top-left
    -0.5, 0.5,  -0.5, // Back-top-left
    -0.5, -0.5, 0.5, // Front-bottom-left
    -0.5, -0.5, -0.5, // Back-bottom-left
    0.5,  -0.5, -0.5, // Back-bottom-right
    -0.5, 0.5,  -0.5, // Back-top-left
    0.5,  0.5,  -0.5, // Back-top-right
};
const QUAD_VERTS = [_]f32{
    -0.5, 0.5,
    0.5,  0.5,
    -0.5, -0.5,
    0.5,  -0.5,
};
const COLOR_ATTRS = 3;

const Camera = struct {
    projectionMatrix: [16]f32,
    pos: Vec3f,
    dir: Vec3f,
    up: Vec3f,

    fn init(pos: Vec3f, fov: f32, aspect: f32, zNear: f32, zFar: f32) @This() {
        return @This(){
            .projectionMatrix = perspective(fov, aspect, zNear, zFar),
            .pos = pos,
            .dir = Vec3f.new(.{ 0, 0, 1 }),
            .up = Vec3f.new(.{ 0, 1, 0 }),
        };
    }

    pub fn view(self: @This()) [16]f32 {
        return lookAt(self.pos, self.pos.add(self.dir), self.up);
    }

    pub fn viewProjection(self: @This()) [16]f32 {
        return mat4.mul(self.projectionMatrix, self.view());
    }
};

pub const ShaderMode = enum {
    InstancedCube,
    Raybox,
};

pub const Screen = struct {
    alloc: *std.mem.Allocator,
    shader: u32,
    raybox_shader: u32,
    shader_mode: ShaderMode,
    camera: Camera,
    projectionMatrixUniform: i32,
    raybox_projectionMatrixUniform: i32,
    raybox_viewMatUniform: i32,
    raybox_camPosUniform: i32,
    mesh_vbo: u32,
    raybox_mesh_vbo: u32,
    position_vbo: u32,
    color_vbo: u32,
    voxel_count: u32,
    position_size_data: []f32,
    color_data: []u8,
    iskeydown: struct {
        forward: bool,
        backward: bool,
        left: bool,
        right: bool,
        up: bool,
        down: bool,
    },
    ctrlr_axis: struct {
        left_v: i16,
        left_h: i16,
        right_v: i16,
        right_h: i16,
    },
    look_angle: struct {
        h: f32,
        v: f32,
    },

    pub fn new(alloc: *std.mem.Allocator) @This() {
        const camerapos = Vec3f.new(.{ 5, 0, -10 });
        return @This(){
            .alloc = alloc,
            .shader = 0,
            .raybox_shader = 0,
            .shader_mode = .InstancedCube,
            .camera = Camera.init(camerapos, std.math.tau * 1.0 / 4.0, 640 / 480, 0.01, 100),
            .projectionMatrixUniform = -1,
            .raybox_projectionMatrixUniform = -1,
            .raybox_viewMatUniform = -1,
            .raybox_camPosUniform = -1,
            .mesh_vbo = 0,
            .raybox_mesh_vbo = 0,
            .position_vbo = 0,
            .color_vbo = 0,
            .voxel_count = 0,
            .position_size_data = &[_]f32{},
            .color_data = &[_]u8{},
            .iskeydown = .{
                .forward = false,
                .backward = false,
                .left = false,
                .right = false,
                .up = false,
                .down = false,
            },
            .ctrlr_axis = .{
                .left_v = 0,
                .left_h = 0,
                .right_v = 0,
                .right_h = 0,
            },
            .look_angle = .{
                .h = 0.0,
                .v = 0.0,
            },
        };
    }

    pub fn init(self: *@This(), ctx: platform.Context) !void {
        // Create instanced cube shader
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

        c.glUseProgram(self.shader);
        self.projectionMatrixUniform = c.glGetUniformLocation(self.shader, "projectionMatrix");

        // Create raybox shader
        const raybox_vertexShader = c.glCreateShader(c.GL_VERTEX_SHADER);
        defer c.glDeleteShader(raybox_vertexShader);
        _ = c.glShaderSource(raybox_vertexShader, 1, &(@as([:0]const u8, RAYBOX_VERTEX_SOURCE).ptr), null);
        _ = c.glCompileShader(raybox_vertexShader);

        const raybox_fragmentShader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        defer c.glDeleteShader(raybox_fragmentShader);
        _ = c.glShaderSource(raybox_fragmentShader, 1, &(@as([:0]const u8, RAYBOX_FRAGMENT_SOURCE).ptr), null);
        _ = c.glCompileShader(raybox_fragmentShader);

        self.raybox_shader = c.glCreateProgram();
        c.glAttachShader(self.raybox_shader, raybox_vertexShader);
        c.glAttachShader(self.raybox_shader, raybox_fragmentShader);
        c.glLinkProgram(self.raybox_shader);

        c.glUseProgram(self.raybox_shader);
        self.raybox_projectionMatrixUniform = c.glGetUniformLocation(self.raybox_shader, "projectionMatrix");
        self.raybox_viewMatUniform = c.glGetUniformLocation(self.raybox_shader, "viewMat");
        self.raybox_camPosUniform = c.glGetUniformLocation(self.raybox_shader, "cam_pos");

        // Generate vertex buffer objects
        c.glGenBuffers(1, &self.mesh_vbo);
        c.glGenBuffers(1, &self.raybox_mesh_vbo);
        c.glGenBuffers(1, &self.position_vbo);
        c.glGenBuffers(1, &self.color_vbo);

        // VBO containing 4 vertices of particles
        // All particles share these verts using instancing
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.mesh_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, VERTS.len * @sizeOf(f32), &VERTS, c.GL_STATIC_DRAW);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.raybox_mesh_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, QUAD_VERTS.len * @sizeOf(f32), &QUAD_VERTS, c.GL_STATIC_DRAW);

        // VBO containing position of each voxel billboard
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.position_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, MAX_VOXELS * 4 * @sizeOf(f32), null, c.GL_STREAM_DRAW);

        // VBO containing color of each voxel
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.color_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, MAX_VOXELS * COLOR_ATTRS * @sizeOf(u8), null, c.GL_STREAM_DRAW);

        self.position_size_data = try self.alloc.alloc(f32, MAX_VOXELS * 4);
        self.color_data = try self.alloc.alloc(u8, MAX_VOXELS * COLOR_ATTRS);

        self.position_size_data[0] = 0.0;
        self.position_size_data[1] = 0.0;
        self.position_size_data[2] = 0.0;
        self.position_size_data[3] = 1;

        self.position_size_data[4] = 1;
        self.position_size_data[5] = 0.0;
        self.position_size_data[6] = 0;
        self.position_size_data[7] = 1;

        self.position_size_data[8] = 0;
        self.position_size_data[9] = 0;
        self.position_size_data[10] = 1;
        self.position_size_data[11] = 1;

        self.color_data[0] = 255;
        self.color_data[1] = 0;
        self.color_data[2] = 0;

        self.color_data[3] = 0;
        self.color_data[4] = 255;
        self.color_data[5] = 0;

        self.color_data[6] = 0;
        self.color_data[7] = 0;
        self.color_data[8] = 255;

        self.voxel_count = 3;

        _ = c.SDL_SetRelativeMouseMode(.SDL_TRUE);
        var i: i32 = 0;
        var controller = while (i < c.SDL_NumJoysticks()) : (i += 1) {
            if (c.SDL_IsGameController(i) == .SDL_TRUE) {
                break c.SDL_GameControllerOpen(i);
            }
        } else null;
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
                c.SDL_KEYDOWN => switch (event.key.keysym.sym) {
                    c.SDLK_ESCAPE => ctx.should_quit.* = true,
                    c.SDLK_w => self.iskeydown.forward = true,
                    c.SDLK_s => self.iskeydown.backward = true,
                    c.SDLK_a => self.iskeydown.left = true,
                    c.SDLK_d => self.iskeydown.right = true,
                    c.SDLK_h => self.shader_mode = switch (self.shader_mode) {
                        .InstancedCube => .Raybox,
                        .Raybox => .InstancedCube,
                    },
                    c.SDLK_SPACE => self.iskeydown.up = true,
                    c.SDLK_LSHIFT => self.iskeydown.down = true,
                    else => {},
                },
                c.SDL_KEYUP => switch (event.key.keysym.sym) {
                    c.SDLK_w => self.iskeydown.forward = false,
                    c.SDLK_s => self.iskeydown.backward = false,
                    c.SDLK_a => self.iskeydown.left = false,
                    c.SDLK_d => self.iskeydown.right = false,
                    c.SDLK_SPACE => self.iskeydown.up = false,
                    c.SDLK_LSHIFT => self.iskeydown.down = false,
                    else => {},
                },
                c.SDL_MOUSEMOTION => {
                    const MOUSE_SPEED = 0.1;
                    self.look_angle.h -= MOUSE_SPEED * @floatCast(f32, delta) * @intToFloat(f32, event.motion.xrel);
                    self.look_angle.v -= MOUSE_SPEED * @floatCast(f32, delta) * @intToFloat(f32, event.motion.yrel);
                },
                c.SDL_CONTROLLERAXISMOTION => switch (event.caxis.axis) {
                    c.SDL_CONTROLLER_AXIS_LEFTX => self.ctrlr_axis.left_h = event.caxis.value,
                    c.SDL_CONTROLLER_AXIS_LEFTY => self.ctrlr_axis.left_v = event.caxis.value,
                    c.SDL_CONTROLLER_AXIS_RIGHTX => self.ctrlr_axis.right_h = event.caxis.value,
                    c.SDL_CONTROLLER_AXIS_RIGHTY => self.ctrlr_axis.right_v = event.caxis.value,
                    else => {},
                },
                c.SDL_CONTROLLERBUTTONDOWN => switch (event.cbutton.button) {
                    c.SDL_CONTROLLER_BUTTON_RIGHTSTICK => self.iskeydown.up = true,
                    c.SDL_CONTROLLER_BUTTON_LEFTSTICK => self.iskeydown.down = true,
                    else => {},
                },
                c.SDL_CONTROLLERBUTTONUP => switch (event.cbutton.button) {
                    c.SDL_CONTROLLER_BUTTON_RIGHTSTICK => self.iskeydown.up = false,
                    c.SDL_CONTROLLER_BUTTON_LEFTSTICK => self.iskeydown.down = false,
                    else => {},
                },
                else => {},
            }
        }

        const ANALOG_SPEED = 5.0;
        var look_h_amt = @intToFloat(f32, self.ctrlr_axis.right_h) / @intToFloat(f32, std.math.maxInt(i16));
        var look_v_amt = @intToFloat(f32, self.ctrlr_axis.right_v) / @intToFloat(f32, std.math.maxInt(i16));
        self.look_angle.h -= ANALOG_SPEED * @floatCast(f32, delta) * look_h_amt;
        self.look_angle.v -= ANALOG_SPEED * @floatCast(f32, delta) * look_v_amt;
        self.look_angle.v = std.math.clamp(self.look_angle.v, @as(f32, -std.math.pi * 2.0 / 5.0), std.math.pi * 2.0 / 5.0);
        var forward_amt: f32 = 0.0;
        forward_amt = -@intToFloat(f32, self.ctrlr_axis.left_v) / @intToFloat(f32, std.math.maxInt(i16));
        if (self.iskeydown.forward) {
            forward_amt += 1;
        }
        if (self.iskeydown.backward) {
            forward_amt -= 1;
        }
        var side_amt: f32 = 0;
        side_amt = @intToFloat(f32, self.ctrlr_axis.left_h) / @intToFloat(f32, std.math.maxInt(i16));
        if (self.iskeydown.right) {
            side_amt += 1;
        }
        if (self.iskeydown.left) {
            side_amt -= 1;
        }
        var vert_amt: f32 = 0;
        if (self.iskeydown.up) {
            vert_amt += 1;
        }
        if (self.iskeydown.down) {
            vert_amt -= 1;
        }
        const forward_vec = Vec3f.new(.{ self.camera.dir.items[0], 0, self.camera.dir.items[2] }).normalize();
        const vert_vec = Vec3f.new(.{ 0, 1, 0 }).normalize();
        const side_vec = forward_vec.cross(vert_vec);
        const SPEED = 0.1;
        const move_vec = forward_vec.scalMul(forward_amt * SPEED).add(side_vec.scalMul(side_amt * SPEED)).add(vert_vec.scalMul(vert_amt * SPEED));
        self.camera.pos = self.camera.pos.add(move_vec);
        self.camera.dir = Vec3f.new(.{
            cos(self.look_angle.v) * sin(self.look_angle.h),
            sin(self.look_angle.v),
            cos(self.look_angle.v) * cos(self.look_angle.h),
        });
    }

    pub fn render(self: *@This(), ctx: platform.Context, alpha: f64) !void {
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.position_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, MAX_VOXELS * 4 * @sizeOf(f32), null, c.GL_STREAM_DRAW);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, self.voxel_count * 4 * @sizeOf(f32), self.position_size_data.ptr);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.color_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, MAX_VOXELS * COLOR_ATTRS * @sizeOf(u8), null, c.GL_STREAM_DRAW);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, self.voxel_count * COLOR_ATTRS * @sizeOf(u8), self.color_data.ptr);

        // 2nd attribute buffer: position and size
        c.glEnableVertexAttribArray(1);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.position_vbo);
        c.glVertexAttribPointer(1, 4, c.GL_FLOAT, c.GL_FALSE, 0, null);

        // 3rd attribute buffer: color
        c.glEnableVertexAttribArray(2);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.color_vbo);
        c.glVertexAttribPointer(2, COLOR_ATTRS, c.GL_UNSIGNED_BYTE, c.GL_TRUE, 0, null);

        switch (self.shader_mode) {
            .InstancedCube => try self.render_InstancedCube_shader(ctx, alpha),
            .Raybox => try self.render_Raybox_shader(ctx, alpha),
        }

        c.SDL_GL_SwapWindow(ctx.window);
    }

    pub fn render_InstancedCube_shader(self: *@This(), ctx: platform.Context, alpha: f64) !void {
        // 1st attribute buffer: mesh vertices
        c.glEnableVertexAttribArray(0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.mesh_vbo);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 0, null);

        c.glUseProgram(self.shader);

        c.glUniformMatrix4fv(self.projectionMatrixUniform, 1, c.GL_FALSE, &self.camera.viewProjection());

        c.glVertexAttribDivisor(0, 0);
        c.glVertexAttribDivisor(1, 1);
        c.glVertexAttribDivisor(2, 1);

        c.glDrawArraysInstanced(c.GL_TRIANGLE_STRIP, 0, @divFloor(VERTS.len, 3), @intCast(c_int, self.voxel_count));
    }

    pub fn render_Raybox_shader(self: *@This(), ctx: platform.Context, alpha: f64) !void {
        // 1st attribute buffer: mesh vertices
        c.glEnableVertexAttribArray(0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.raybox_mesh_vbo);
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 0, null);

        c.glUseProgram(self.raybox_shader);

        c.glUniformMatrix4fv(self.raybox_projectionMatrixUniform, 1, c.GL_FALSE, &self.camera.viewProjection());
        c.glUniformMatrix4fv(self.raybox_viewMatUniform, 1, c.GL_FALSE, &self.camera.view());
        c.glUniform3fv(self.raybox_camPosUniform, 1, &self.camera.pos.items);

        c.glVertexAttribDivisor(0, 0);
        c.glVertexAttribDivisor(1, 1);
        c.glVertexAttribDivisor(2, 1);

        c.glDrawArraysInstanced(c.GL_TRIANGLE_STRIP, 0, @divFloor(QUAD_VERTS.len, 2), @intCast(c_int, self.voxel_count));
    }
};

fn perspective(fov: f32, aspect: f32, near: f32, far: f32) [16]f32 {
    var proj_matrix = std.mem.zeroes([16]f32);

    const tan_half_angle = std.math.tan(0.5 * fov);

    proj_matrix[4 * 0 + 0] = 1 / (aspect * tan_half_angle);
    proj_matrix[4 * 1 + 1] = 1 / tan_half_angle;
    proj_matrix[4 * 2 + 2] = -(far + near) / (far - near);
    proj_matrix[4 * 3 + 2] = -1;
    proj_matrix[4 * 2 + 3] = -(2 * far * near) / (far - near);

    return proj_matrix;
}

fn lookAt(eye: Vec3f, target: Vec3f, up: Vec3f) [16]f32 {
    const f = target.sub(eye).normalize();
    const s = f.cross(up.normalize()).normalize();
    const u = s.cross(f);

    var res: [16]f32 = undefined;
    std.mem.set(f32, &res, 1);

    res[4 * 0 + 0] = s.items[0];
    res[4 * 0 + 1] = s.items[1];
    res[4 * 0 + 2] = s.items[2];
    res[4 * 1 + 0] = u.items[0];
    res[4 * 1 + 1] = u.items[1];
    res[4 * 1 + 2] = u.items[2];
    res[4 * 2 + 0] = -f.items[0];
    res[4 * 2 + 1] = -f.items[1];
    res[4 * 2 + 2] = -f.items[2];
    res[4 * 0 + 3] = -s.dot(eye);
    res[4 * 1 + 3] = -u.dot(eye);
    res[4 * 2 + 3] = f.dot(eye);

    res[4 * 3 + 0] = 0;
    res[4 * 3 + 1] = 0;
    res[4 * 3 + 2] = 0;

    return res;
}
