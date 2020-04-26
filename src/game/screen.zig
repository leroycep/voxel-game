const std = @import("std");
const c = @import("../c.zig");
const platform = @import("../platform.zig");
const Vec3 = @import("../utils/vec3.zig").Vec3;
const Vec3f = Vec3(f32);
const voxel_batch = @import("./voxel_batch.zig");
const Camera = voxel_batch.Camera;
const VoxelBatch = voxel_batch.VoxelBatch;
const mat4 = @import("../utils/mat4.zig");
const sin = std.math.sin;
const cos = std.math.cos;

const MAX_VOXELS = 1000;

pub const Screen = struct {
    alloc: *std.mem.Allocator,
    camera: Camera,
    voxel_batch: VoxelBatch,
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
            .camera = Camera.init(camerapos, std.math.tau * 1.0 / 4.0, 640 / 480, 0.01, 100),
            .voxel_batch = undefined,
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
        try self.voxel_batch.init();

        _ = c.SDL_SetRelativeMouseMode(.SDL_TRUE);
        var i: i32 = 0;
        var controller = while (i < c.SDL_NumJoysticks()) : (i += 1) {
            if (c.SDL_IsGameController(i) == .SDL_TRUE) {
                break c.SDL_GameControllerOpen(i);
            }
        } else null;
    }

    pub fn deinit(self: *@This(), ctx: platform.Context) void {}

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

        self.voxel_batch.camera = self.camera;
        self.voxel_batch.begin();
        self.voxel_batch.drawVoxel(Vec3f.new(.{ 0, 0, 0 }), 1, .{ 255, 0, 0 });
        self.voxel_batch.drawVoxel(Vec3f.new(.{ 1, 0, 0 }), 1, .{ 0, 255, 0 });
        self.voxel_batch.drawVoxel(Vec3f.new(.{ 0, 0, 1 }), 1, .{ 0, 0, 255 });
        self.voxel_batch.drawVoxel(Vec3f.new(.{ -1, 0, 0 }), 1, .{ 0, 0, 255 });
        self.voxel_batch.drawVoxel(Vec3f.new(.{ 0, 0, -1 }), 1, .{ 0, 255, 0 });
        self.voxel_batch.end();

        c.SDL_GL_SwapWindow(ctx.window);
    }
};
