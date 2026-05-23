const std = @import("std");

pub var io: std.Io = undefined;
pub var gpa: std.mem.Allocator = undefined;
pub var arena: *std.heap.ArenaAllocator = undefined;
pub var environ: std.process.Environ = undefined;

pub fn init(values: std.process.Init) void {
    io = values.io;
    gpa = values.gpa;
    arena = values.arena;
    environ = values.minimal.environ;
}
