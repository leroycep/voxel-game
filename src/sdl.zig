const std = @import("std");

usingnamespace @import("./c.zig");
const Error = @import("./error.zig").Error;

pub fn assertZero(ret: c_int) void {
    if (ret == 0) return;
    std.debug.panic("sdl function returned an error: {s}\n", .{SDL_GetError()});
}

pub fn glErrCallback(src: c_uint, errType: c_uint, id: c_uint, severity: c_uint, length: c_int, message: ?[*:0]const u8, userParam: ?*const c_void) callconv(.C) void {
    const severityStr = severityToString(severity);
    std.debug.warn("[{}] GL {} {}: {s}\n", .{ severityStr, errSrcToString(src), errTypeToString(errType), message });
}

fn severityToString(severity: c_uint) []const u8 {
    switch (severity) {
        GL_DEBUG_SEVERITY_HIGH => return "HIGH",
        GL_DEBUG_SEVERITY_MEDIUM => return "MEDIUM",
        GL_DEBUG_SEVERITY_LOW => return "LOW",
        GL_DEBUG_SEVERITY_NOTIFICATION => return "NOTIFICATION",
        else => return "Uknown Severity",
    }
}

fn errSrcToString(src: c_uint) []const u8 {
    switch (src) {
        GL_DEBUG_SOURCE_API => return "API",
        GL_DEBUG_SOURCE_WINDOW_SYSTEM => return "Window System",
        GL_DEBUG_SOURCE_SHADER_COMPILER => return "Shader Compiler",
        GL_DEBUG_SOURCE_THIRD_PARTY => return "Third Party",
        GL_DEBUG_SOURCE_APPLICATION => return "Application",
        GL_DEBUG_SOURCE_OTHER => return "Other",
        else => return "Unknown Source",
    }
}

fn errTypeToString(errType: c_uint) []const u8 {
    switch (errType) {
        GL_DEBUG_TYPE_ERROR => return "Error",
        GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR => return "Deprecated",
        GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR => return "Undefined Behavior",
        GL_DEBUG_TYPE_PORTABILITY => return "Not Portable",
        GL_DEBUG_TYPE_PERFORMANCE => return "Performance",
        GL_DEBUG_TYPE_MARKER => return "Marker",
        GL_DEBUG_TYPE_PUSH_GROUP => return "Group Pushed",
        GL_DEBUG_TYPE_POP_GROUP => return "Group Popped",
        GL_DEBUG_TYPE_OTHER => return "Other",
        else => return "Uknown Type",
    }
}

pub fn logErr(err: Error) Error {
    std.debug.warn("{}: {}\n", .{ err, @as([*:0]const u8, SDL_GetError()) });
    return err;
}

