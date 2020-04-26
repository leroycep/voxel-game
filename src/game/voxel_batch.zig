const std = @import("std");
const c = @import("../c.zig");
const Vec3 = @import("../utils/vec3.zig").Vec3;
const Vec3f = Vec3(f32);

const RAYBOX_VERTEX_SOURCE = @embedFile("./raybox_vertex.glsl");
const RAYBOX_FRAGMENT_SOURCE = @embedFile("./raybox_fragment.glsl");
const MAX_VOXELS = 1000;

const QUAD_VERTS = [_]f32{
    -0.5, 0.5,
    0.5,  0.5,
    -0.5, -0.5,
    0.5,  -0.5,
};
const POS_SIZE_ATTRS = 4;
const COLOR_ATTRS = 3;

pub const Camera = struct {
    projMat: [16]f32,
    near: f32,
    far: f32,
    pos: Vec3f,
    dir: Vec3f,
    up: Vec3f,

    pub fn init(pos: Vec3f, fov: f32, aspect: f32, zNear: f32, zFar: f32) @This() {
        return @This(){
            .projMat = perspective(fov, aspect, zNear, zFar),
            .near = zNear,
            .far = zFar,
            .pos = pos,
            .dir = Vec3f.new(.{ 0, 0, 1 }),
            .up = Vec3f.new(.{ 0, 1, 0 }),
        };
    }

    pub fn view(self: @This()) [16]f32 {
        return lookAt(self.pos, self.pos.add(self.dir), self.up);
    }

    pub fn viewProjection(self: @This()) [16]f32 {
        return mat4.mul(self.projMat, self.view());
    }
};

pub const VoxelBatch = struct {
    uniforms: struct {
        projMat: i32,
        viewMat: i32,
        camPos: i32,
        near: i32,
        far: i32,
    },
    shader: u32,
    camera: Camera,
    mesh_vbo: u32,
    position_vbo: u32,
    color_vbo: u32,

    voxel_count: u32,
    pos_size_data: [MAX_VOXELS * POS_SIZE_ATTRS]f32 = undefined,
    color_data: [MAX_VOXELS * COLOR_ATTRS]u8 = undefined,

    pub fn init(self: *@This()) !void {
        // Create raybox shader
        const vertexShader = c.glCreateShader(c.GL_VERTEX_SHADER);
        defer c.glDeleteShader(vertexShader);
        _ = c.glShaderSource(vertexShader, 1, &(@as([:0]const u8, RAYBOX_VERTEX_SOURCE).ptr), null);
        _ = c.glCompileShader(vertexShader);

        if (!getShaderCompileStatus(vertexShader)) {
            var infoLog: [512]u8 = [_]u8{0} ** 512;
            var infoLen: c.GLsizei = 0;
            c.glGetShaderInfoLog(vertexShader, infoLog.len, &infoLen, &infoLog);
            std.debug.warn("Error compiling vertex shader: {}\n", .{infoLog[0..@intCast(usize, infoLen)]});
            return error.VertexShaderCompile;
        }

        const fragmentShader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        defer c.glDeleteShader(fragmentShader);
        _ = c.glShaderSource(fragmentShader, 1, &(@as([:0]const u8, RAYBOX_FRAGMENT_SOURCE).ptr), null);
        _ = c.glCompileShader(fragmentShader);

        if (!getShaderCompileStatus(fragmentShader)) {
            var infoLog: [512]u8 = [_]u8{0} ** 512;
            var infoLen: c.GLsizei = 0;
            c.glGetShaderInfoLog(fragmentShader, infoLog.len, &infoLen, &infoLog);
            std.debug.warn("Error compiling fragment shader: {}\n", .{infoLog[0..@intCast(usize, infoLen)]});
            return error.FragmentShaderCompile;
        }

        self.shader = c.glCreateProgram();
        c.glAttachShader(self.shader, vertexShader);
        c.glAttachShader(self.shader, fragmentShader);
        c.glLinkProgram(self.shader);

        if (!getProgramLinkStatus(self.shader)) {
            var infoLog: [512]u8 = [_]u8{0} ** 512;
            var infoLen: c.GLsizei = 0;
            c.glGetProgramInfoLog(self.shader, infoLog.len, &infoLen, &infoLog);
            std.debug.warn("Error linking shader program: {}\n", .{infoLog[0..@intCast(usize, infoLen)]});
            return error.ShaderLink;
        }

        c.glUseProgram(self.shader);
        self.uniforms.projMat = c.glGetUniformLocation(self.shader, "projMat");
        self.uniforms.viewMat = c.glGetUniformLocation(self.shader, "viewMat");
        self.uniforms.camPos = c.glGetUniformLocation(self.shader, "cam_pos");
        self.uniforms.near = c.glGetUniformLocation(self.shader, "near");
        self.uniforms.far = c.glGetUniformLocation(self.shader, "far");

        c.glGenBuffers(1, &self.mesh_vbo);
        c.glGenBuffers(1, &self.position_vbo);
        c.glGenBuffers(1, &self.color_vbo);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.mesh_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, QUAD_VERTS.len * @sizeOf(f32), &QUAD_VERTS, c.GL_STATIC_DRAW);

        // VBO containing position of each voxel billboard
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.position_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, self.pos_size_data.len * @sizeOf(f32), null, c.GL_STREAM_DRAW);

        // VBO containing color of each voxel
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.color_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, self.color_data.len * @sizeOf(u8), null, c.GL_STREAM_DRAW);

        self.voxel_count = 0;
    }

    pub fn begin(self: *@This()) void {
        self.voxel_count = 0;
    }

    pub fn end(self: *@This()) void {
        self.flush();
    }

    pub fn drawVoxel(self: *@This(), pos: Vec3f, size: f32, color: [3]u8) void {
        if (self.voxel_count >= MAX_VOXELS) {
            self.flush();
        }

        self.pos_size_data[self.voxel_count * POS_SIZE_ATTRS + 0] = pos.items[0];
        self.pos_size_data[self.voxel_count * POS_SIZE_ATTRS + 1] = pos.items[1];
        self.pos_size_data[self.voxel_count * POS_SIZE_ATTRS + 2] = pos.items[2];
        self.pos_size_data[self.voxel_count * POS_SIZE_ATTRS + 3] = size;

        self.color_data[self.voxel_count * COLOR_ATTRS + 0] = color[0];
        self.color_data[self.voxel_count * COLOR_ATTRS + 1] = color[1];
        self.color_data[self.voxel_count * COLOR_ATTRS + 2] = color[2];

        self.voxel_count += 1;
    }

    pub fn flush(self: *@This()) void {
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.position_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, self.pos_size_data.len * @sizeOf(f32), null, c.GL_STREAM_DRAW);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, self.voxel_count * POS_SIZE_ATTRS * @sizeOf(f32), &self.pos_size_data);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.color_vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, self.color_data.len * @sizeOf(u8), null, c.GL_STREAM_DRAW);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, self.voxel_count * COLOR_ATTRS * @sizeOf(u8), &self.color_data);

        // 1st attribute buffer: mesh vertices
        c.glEnableVertexAttribArray(0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.mesh_vbo);
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 0, null);

        // 2nd attribute buffer: position and size
        c.glEnableVertexAttribArray(1);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.position_vbo);
        c.glVertexAttribPointer(1, 4, c.GL_FLOAT, c.GL_FALSE, 0, null);

        // 3rd attribute buffer: color
        c.glEnableVertexAttribArray(2);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.color_vbo);
        c.glVertexAttribPointer(2, COLOR_ATTRS, c.GL_UNSIGNED_BYTE, c.GL_TRUE, 0, null);

        c.glUseProgram(self.shader);

        c.glUniformMatrix4fv(self.uniforms.projMat, 1, c.GL_FALSE, &self.camera.projMat);
        c.glUniformMatrix4fv(self.uniforms.viewMat, 1, c.GL_FALSE, &self.camera.view());
        c.glUniform3fv(self.uniforms.camPos, 1, &self.camera.pos.items);
        c.glUniform1f(self.uniforms.near, self.camera.near);
        c.glUniform1f(self.uniforms.far, self.camera.far);

        c.glVertexAttribDivisor(0, 0);
        c.glVertexAttribDivisor(1, 1);
        c.glVertexAttribDivisor(2, 1);

        c.glDrawArraysInstanced(c.GL_TRIANGLE_STRIP, 0, @divFloor(QUAD_VERTS.len, 2), @intCast(c_int, self.voxel_count));

        self.voxel_count = 0;
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

pub fn getShaderCompileStatus(shader: c.GLuint) bool {
    var success: c.GLint = undefined;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);
    return success == c.GL_TRUE;
}

pub fn getProgramLinkStatus(program: c.GLuint) bool {
    var success: c.GLint = undefined;
    c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
    return success == c.GL_TRUE;
}
