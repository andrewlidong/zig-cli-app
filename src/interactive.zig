const std = @import("std");
const cli = @import("cli.zig");

pub const Error = error{
    Cancelled,
    InputTooLong,
    NotATerminal,
    ReadFailed,
};

pub const Key = union(enum) {
    char: u8,
    enter,
    up,
    down,
    left,
    right,
    escape,
    ctrl_c,
    backspace,
};

pub const RawMode = struct {
    original: std.posix.termios,
    fd: std.posix.fd_t,

    pub fn enter() !RawMode {
        const fd = std.posix.STDIN_FILENO;
        if (!std.posix.isatty(fd)) return Error.NotATerminal;
        const original = std.posix.tcgetattr(fd) catch return Error.NotATerminal;

        var raw = original;
        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.ISIG = false;
        raw.lflag.IEXTEN = false;
        raw.iflag.IXON = false;
        raw.iflag.ICRNL = false;
        raw.iflag.BRKINT = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;
        raw.cc[@intFromEnum(std.c.V.MIN)] = 0;
        raw.cc[@intFromEnum(std.c.V.TIME)] = 1;

        try std.posix.tcsetattr(fd, .NOW, raw);
        return .{ .original = original, .fd = fd };
    }

    pub fn exit(self: RawMode) void {
        std.posix.tcsetattr(self.fd, .NOW, self.original) catch {};
    }
};

fn readByteTimeout() ?u8 {
    var buf: [1]u8 = undefined;
    const n = std.posix.read(std.posix.STDIN_FILENO, &buf) catch return null;
    if (n == 0) return null;
    return buf[0];
}

fn readByteBlocking() !u8 {
    while (true) {
        if (readByteTimeout()) |b| return b;
    }
}

pub fn readKey() !Key {
    const b = try readByteBlocking();
    switch (b) {
        '\n', '\r' => return .enter,
        3 => return .ctrl_c,
        127, 8 => return .backspace,
        0x1b => {
            const b2 = readByteTimeout() orelse return .escape;
            if (b2 != '[') return .escape;
            const b3 = readByteTimeout() orelse return .escape;
            return switch (b3) {
                'A' => .up,
                'B' => .down,
                'C' => .right,
                'D' => .left,
                else => .escape,
            };
        },
        else => return Key{ .char = b },
    }
}

pub fn hideCursor() void {
    std.debug.print("\x1b[?25l", .{});
}

pub fn showCursor() void {
    std.debug.print("\x1b[?25h", .{});
}

fn drawMenu(items: []const []const u8, selected: usize) void {
    for (items, 0..) |item, i| {
        std.debug.print("\x1b[2K\r", .{});
        if (i == selected) {
            cli.printColored(.Cyan, "> {s}\n", .{item});
        } else {
            std.debug.print("  {s}\n", .{item});
        }
    }
}

pub fn promptSelect(message: []const u8, items: []const []const u8) !usize {
    if (items.len == 0) return Error.Cancelled;

    cli.printColored(.Cyan, "? {s}\n", .{message});

    var raw = try RawMode.enter();
    defer raw.exit();
    hideCursor();
    defer showCursor();

    var selected: usize = 0;
    drawMenu(items, selected);

    while (true) {
        const key = try readKey();
        switch (key) {
            .up => selected = if (selected == 0) items.len - 1 else selected - 1,
            .down => selected = (selected + 1) % items.len,
            .enter => {
                std.debug.print("\x1b[{d}A", .{items.len});
                for (items) |_| std.debug.print("\x1b[2K\r\n", .{});
                std.debug.print("\x1b[{d}A", .{items.len});
                cli.printColored(.Green, "\xe2\x9c\x93 {s}\n", .{items[selected]});
                return selected;
            },
            .ctrl_c, .escape => {
                std.debug.print("\x1b[{d}A", .{items.len});
                for (items) |_| std.debug.print("\x1b[2K\r\n", .{});
                std.debug.print("\x1b[{d}A", .{items.len});
                cli.printColored(.Red, "(cancelled)\n", .{});
                return Error.Cancelled;
            },
            else => continue,
        }
        std.debug.print("\x1b[{d}A", .{items.len});
        drawMenu(items, selected);
    }
}

pub fn promptConfirm(message: []const u8, default_yes: bool) !bool {
    const hint = if (default_yes) "[Y/n]" else "[y/N]";
    cli.printColored(.Cyan, "? {s} {s} ", .{ message, hint });

    var raw = try RawMode.enter();
    defer raw.exit();

    while (true) {
        const key = try readKey();
        switch (key) {
            .enter => {
                const v = default_yes;
                std.debug.print("{s}\n", .{if (v) "yes" else "no"});
                return v;
            },
            .ctrl_c, .escape => {
                std.debug.print("\n", .{});
                return Error.Cancelled;
            },
            .char => |c| {
                if (c == 'y' or c == 'Y') {
                    std.debug.print("yes\n", .{});
                    return true;
                }
                if (c == 'n' or c == 'N') {
                    std.debug.print("no\n", .{});
                    return false;
                }
            },
            else => {},
        }
    }
}

pub fn promptText(allocator: std.mem.Allocator, message: []const u8) ![]u8 {
    cli.printColored(.Cyan, "? {s}: ", .{message});

    var buf: [1024]u8 = undefined;
    var len: usize = 0;
    while (len < buf.len) {
        var byte: [1]u8 = undefined;
        const n = try std.posix.read(std.posix.STDIN_FILENO, &byte);
        if (n == 0) return Error.ReadFailed;
        if (byte[0] == '\n') break;
        buf[len] = byte[0];
        len += 1;
    }
    if (len == buf.len) return Error.InputTooLong;

    var end = len;
    if (end > 0 and buf[end - 1] == '\r') end -= 1;

    const result = try allocator.alloc(u8, end);
    @memcpy(result, buf[0..end]);
    return result;
}
