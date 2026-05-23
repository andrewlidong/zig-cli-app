const std = @import("std");
const cli = @import("cli.zig");
const runtime = @import("runtime.zig");

const docs_dir = "docs";

const Format = enum {
    markdown,
    man,
    text,

    fn fileName(self: Format) []const u8 {
        return switch (self) {
            .markdown => "babyline.md",
            .man => "babyline.1",
            .text => "babyline.txt",
        };
    }
};

fn findOption(options: []const cli.option, name: []const u8) ?cli.option {
    for (options) |opt| {
        if (std.mem.eql(u8, opt.name, name)) return opt;
    }
    return null;
}

fn printUsageErr() void {
    std.debug.print("Usage: babyline docs <markdown|man|text|all>\n", .{});
}

pub fn run(commands: []const cli.command, options: []const cli.option, args: []const [:0]const u8) !void {
    if (args.len < 3) {
        printUsageErr();
        std.process.exit(1);
    }

    const format_arg = args[2];

    if (std.mem.eql(u8, format_arg, "all")) {
        try writeFile(.markdown, commands, options);
        try writeFile(.man, commands, options);
        try writeFile(.text, commands, options);
        return;
    }

    const format: Format = if (std.mem.eql(u8, format_arg, "markdown"))
        .markdown
    else if (std.mem.eql(u8, format_arg, "man"))
        .man
    else if (std.mem.eql(u8, format_arg, "text"))
        .text
    else {
        printUsageErr();
        std.process.exit(1);
    };

    try writeFile(format, commands, options);
}

fn writeFile(format: Format, commands: []const cli.command, options: []const cli.option) !void {
    const io = runtime.io;
    const cwd = std.Io.Dir.cwd();
    cwd.createDirPath(io, docs_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const path = try std.fs.path.join(runtime.gpa, &.{ docs_dir, format.fileName() });
    defer runtime.gpa.free(path);

    const file = try cwd.createFile(io, path, .{ .truncate = true });
    defer file.close(io);

    var buf: [8192]u8 = undefined;
    var fw = file.writer(io, &buf);
    const w = &fw.interface;

    switch (format) {
        .markdown => try writeMarkdown(w, commands, options),
        .man => try writeMan(w, commands, options),
        .text => try writeText(w, commands, options),
    }
    try w.flush();

    std.debug.print("Wrote {s}\n", .{path});
}

fn writeMarkdown(w: *std.Io.Writer, commands: []const cli.command, options: []const cli.option) !void {
    try w.writeAll(
        \\# babyline
        \\
        \\A small Zig CLI demo with subcommands, persistent config, and shell completion.
        \\
        \\## Synopsis
        \\
        \\```
        \\babyline <command> [options]
        \\```
        \\
        \\## Commands
        \\
        \\
    );

    for (commands) |c| {
        try w.print("### `{s}`\n\n{s}.\n\n", .{ c.name, c.desc });

        if (c.req.len > 0) {
            try w.writeAll("**Required options:**\n\n");
            for (c.req) |opt_name| {
                if (findOption(options, opt_name)) |o| {
                    try w.print("- `-{c}, --{s} <value>` - {s}\n", .{ o.short, o.long, o.desc });
                }
            }
            try w.writeAll("\n");
        }

        if (c.opt.len > 0) {
            try w.writeAll("**Optional options:**\n\n");
            for (c.opt) |opt_name| {
                if (findOption(options, opt_name)) |o| {
                    try w.print("- `-{c}, --{s} <value>` - {s}\n", .{ o.short, o.long, o.desc });
                }
            }
            try w.writeAll("\n");
        }
    }

    try w.writeAll(
        \\## Built-in subcommands
        \\
        \\### `completion`
        \\
        \\Generate a shell completion script.
        \\
        \\```
        \\babyline completion <bash|zsh|fish>
        \\```
        \\
        \\### `docs`
        \\
        \\Generate usage documentation in the `docs/` directory.
        \\
        \\```
        \\babyline docs <markdown|man|text|all>
        \\```
        \\
        \\## All options
        \\
        \\| Short | Long | Description |
        \\|-------|------|-------------|
        \\
    );

    for (options) |o| {
        try w.print("| `-{c}` | `--{s}` | {s} |\n", .{ o.short, o.long, o.desc });
    }
}

fn writeMan(w: *std.Io.Writer, commands: []const cli.command, options: []const cli.option) !void {
    try w.writeAll(
        \\.TH BABYLINE 1 "" "" "babyline manual"
        \\.SH NAME
        \\babyline \- a small Zig CLI demo
        \\.SH SYNOPSIS
        \\.B babyline
        \\.I command
        \\.RI [ options ]
        \\.SH DESCRIPTION
        \\A small Zig CLI demo with subcommands, persistent config, and shell completion.
        \\.SH COMMANDS
        \\
    );

    for (commands) |c| {
        try w.print(".TP\n.B {s}\n{s}.\n", .{ c.name, c.desc });
        if (c.req.len > 0) {
            try w.writeAll("Required: ");
            var first = true;
            for (c.req) |opt_name| {
                if (findOption(options, opt_name)) |o| {
                    if (!first) try w.writeAll(", ");
                    try w.print("\\-{c}, \\-\\-{s}", .{ o.short, o.long });
                    first = false;
                }
            }
            try w.writeAll("\n");
        }
        if (c.opt.len > 0) {
            try w.writeAll("Optional: ");
            var first = true;
            for (c.opt) |opt_name| {
                if (findOption(options, opt_name)) |o| {
                    if (!first) try w.writeAll(", ");
                    try w.print("\\-{c}, \\-\\-{s}", .{ o.short, o.long });
                    first = false;
                }
            }
            try w.writeAll("\n");
        }
    }

    try w.writeAll(".TP\n.B completion <bash|zsh|fish>\nGenerate a shell completion script.\n");
    try w.writeAll(".TP\n.B docs <markdown|man|text|all>\nGenerate usage documentation.\n");

    try w.writeAll(".SH OPTIONS\n");
    for (options) |o| {
        try w.print(".TP\n.BR \\-{c} \", \" \\-\\-{s}\n{s}\n", .{ o.short, o.long, o.desc });
    }
}

fn writeText(w: *std.Io.Writer, commands: []const cli.command, options: []const cli.option) !void {
    try w.writeAll(
        \\babyline - a small Zig CLI demo with subcommands, persistent config, and shell completion.
        \\
        \\USAGE
        \\    babyline <command> [options]
        \\
        \\COMMANDS
        \\
    );

    for (commands) |c| {
        try w.print("    {s:<16} {s}\n", .{ c.name, c.desc });
        if (c.req.len > 0) {
            try w.writeAll("        required: ");
            var first = true;
            for (c.req) |opt_name| {
                if (findOption(options, opt_name)) |o| {
                    if (!first) try w.writeAll(", ");
                    try w.print("-{c}, --{s}", .{ o.short, o.long });
                    first = false;
                }
            }
            try w.writeAll("\n");
        }
        if (c.opt.len > 0) {
            try w.writeAll("        optional: ");
            var first = true;
            for (c.opt) |opt_name| {
                if (findOption(options, opt_name)) |o| {
                    if (!first) try w.writeAll(", ");
                    try w.print("-{c}, --{s}", .{ o.short, o.long });
                    first = false;
                }
            }
            try w.writeAll("\n");
        }
    }

    try w.writeAll("    completion       Generate shell completion script (bash|zsh|fish)\n");
    try w.writeAll("    docs             Generate usage documentation (markdown|man|text|all)\n");

    try w.writeAll("\nOPTIONS\n");
    for (options) |o| {
        try w.print("    -{c}, --{s:<12} {s}\n", .{ o.short, o.long, o.desc });
    }
}

// --- tests ---

const testing = std.testing;

fn noopCmdFn(_: []const cli.option) bool {
    return true;
}

const test_commands = [_]cli.command{
    .{ .name = "hello", .func = &noopCmdFn, .req = &.{"greeting"}, .opt = &.{"name"}, .desc = "Greet someone" },
    .{ .name = "user:list", .func = &noopCmdFn, .desc = "List users" },
};

const test_options = [_]cli.option{
    .{ .name = "name", .short = 'n', .long = "name", .desc = "Name to greet" },
    .{ .name = "greeting", .short = 'g', .long = "greeting", .desc = "Greeting word" },
};

test "writeMarkdown: emits headers, command sections, options table" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    try writeMarkdown(&aw.writer, &test_commands, &test_options);
    const out = aw.written();

    try testing.expect(std.mem.indexOf(u8, out, "# babyline") != null);
    try testing.expect(std.mem.indexOf(u8, out, "### `hello`") != null);
    try testing.expect(std.mem.indexOf(u8, out, "### `user:list`") != null);
    try testing.expect(std.mem.indexOf(u8, out, "Greet someone.") != null);
    try testing.expect(std.mem.indexOf(u8, out, "**Required options:**") != null);
    try testing.expect(std.mem.indexOf(u8, out, "`-g, --greeting <value>`") != null);
    try testing.expect(std.mem.indexOf(u8, out, "| `-n` | `--name` | Name to greet |") != null);
}

test "writeMan: emits troff headers and command/option sections" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    try writeMan(&aw.writer, &test_commands, &test_options);
    const out = aw.written();

    try testing.expect(std.mem.indexOf(u8, out, ".TH BABYLINE 1") != null);
    try testing.expect(std.mem.indexOf(u8, out, ".SH NAME") != null);
    try testing.expect(std.mem.indexOf(u8, out, ".SH SYNOPSIS") != null);
    try testing.expect(std.mem.indexOf(u8, out, ".SH COMMANDS") != null);
    try testing.expect(std.mem.indexOf(u8, out, ".B hello") != null);
    try testing.expect(std.mem.indexOf(u8, out, "Required: \\-g, \\-\\-greeting") != null);
    try testing.expect(std.mem.indexOf(u8, out, ".SH OPTIONS") != null);
}

test "writeText: emits USAGE, COMMANDS, OPTIONS sections" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    try writeText(&aw.writer, &test_commands, &test_options);
    const out = aw.written();

    try testing.expect(std.mem.indexOf(u8, out, "USAGE") != null);
    try testing.expect(std.mem.indexOf(u8, out, "COMMANDS") != null);
    try testing.expect(std.mem.indexOf(u8, out, "OPTIONS") != null);
    try testing.expect(std.mem.indexOf(u8, out, "hello") != null);
    try testing.expect(std.mem.indexOf(u8, out, "Greet someone") != null);
    try testing.expect(std.mem.indexOf(u8, out, "required: -g, --greeting") != null);
}

test "Format.fileName: maps each variant to its file" {
    try testing.expectEqualStrings("babyline.md", Format.markdown.fileName());
    try testing.expectEqualStrings("babyline.1", Format.man.fileName());
    try testing.expectEqualStrings("babyline.txt", Format.text.fileName());
}

test "findOption: returns matching option or null" {
    const found = findOption(&test_options, "greeting");
    try testing.expect(found != null);
    try testing.expectEqual(@as(u8, 'g'), found.?.short);

    try testing.expect(findOption(&test_options, "missing") == null);
}
