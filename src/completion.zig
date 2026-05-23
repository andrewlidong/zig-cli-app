const std = @import("std");
const cli = @import("cli.zig");
const runtime = @import("runtime.zig");

fn findOption(options: []const cli.option, name: []const u8) ?cli.option {
    for (options) |opt| {
        if (std.mem.eql(u8, opt.name, name)) return opt;
    }
    return null;
}

fn printUsageErr() void {
    std.debug.print("Usage: cli completion <bash|zsh|fish>\n", .{});
}

pub fn run(commands: []const cli.command, options: []const cli.option, args: []const [:0]const u8) !void {
    if (args.len < 3) {
        printUsageErr();
        std.process.exit(1);
    }

    const shell = args[2];

    var buf: [8192]u8 = undefined;
    var fw = std.Io.File.stdout().writer(runtime.io, &buf);
    const w = &fw.interface;

    if (std.mem.eql(u8, shell, "bash")) {
        try writeBash(w, commands, options);
    } else if (std.mem.eql(u8, shell, "zsh")) {
        try writeZsh(w, commands, options);
    } else if (std.mem.eql(u8, shell, "fish")) {
        try writeFish(w, commands, options);
    } else {
        printUsageErr();
        std.process.exit(1);
    }

    try w.flush();
}

fn writeBash(w: *std.Io.Writer, commands: []const cli.command, options: []const cli.option) !void {
    try w.writeAll(
        \\# bash completion for cli
        \\_cli_complete() {
        \\    local cur cmd opts
        \\    COMP_WORDBREAKS="${COMP_WORDBREAKS//:/}"
        \\    cur="${COMP_WORDS[COMP_CWORD]}"
        \\    cmd="${COMP_WORDS[1]}"
        \\
        \\    local cmds="
    );
    for (commands) |c| {
        try w.print("{s} ", .{c.name});
    }
    try w.writeAll("completion\"\n");
    try w.writeAll(
        \\
        \\    if [ "$COMP_CWORD" -eq 1 ]; then
        \\        COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
        \\        return 0
        \\    fi
        \\
        \\    case "$cmd" in
        \\        completion)
        \\            if [ "$COMP_CWORD" -eq 2 ]; then
        \\                COMPREPLY=( $(compgen -W "bash zsh fish" -- "$cur") )
        \\            fi
        \\            return 0
        \\            ;;
        \\
    );

    for (commands) |c| {
        if (c.req.len == 0 and c.opt.len == 0) continue;
        try w.print("        {s})\n            opts=\"", .{c.name});
        var first = true;
        for (c.req) |opt_name| {
            if (findOption(options, opt_name)) |o| {
                if (!first) try w.writeAll(" ");
                try w.print("-{c} --{s}", .{ o.short, o.long });
                first = false;
            }
        }
        for (c.opt) |opt_name| {
            if (findOption(options, opt_name)) |o| {
                if (!first) try w.writeAll(" ");
                try w.print("-{c} --{s}", .{ o.short, o.long });
                first = false;
            }
        }
        try w.writeAll("\"\n            ;;\n");
    }

    try w.writeAll(
        \\        *)
        \\            opts=""
        \\            ;;
        \\    esac
        \\
        \\    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
        \\    return 0
        \\}
        \\complete -F _cli_complete cli
        \\
    );
}

fn writeZsh(w: *std.Io.Writer, commands: []const cli.command, options: []const cli.option) !void {
    try w.writeAll(
        \\#compdef cli
        \\
        \\_cli() {
        \\    local -a commands
        \\    commands=(
        \\
    );

    for (commands) |c| {
        try w.writeAll("        '");
        for (c.name) |ch| {
            if (ch == ':') try w.writeAll("\\");
            try w.print("{c}", .{ch});
        }
        try w.print(":{s}'\n", .{c.desc});
    }
    try w.writeAll("        'completion:Generate shell completion script'\n");
    try w.writeAll("        'docs:Generate usage documentation'\n");
    try w.writeAll("    )\n\n");

    try w.writeAll(
        \\    if (( CURRENT == 2 )); then
        \\        _describe 'command' commands
        \\        return
        \\    fi
        \\
        \\    case "$words[2]" in
        \\
    );

    for (commands) |c| {
        const total = c.req.len + c.opt.len;
        if (total == 0) continue;
        try w.print("        {s})\n            _arguments \\\n", .{c.name});
        var emitted: usize = 0;
        for (c.req) |opt_name| {
            if (findOption(options, opt_name)) |o| {
                emitted += 1;
                const sep: []const u8 = if (emitted < total) " \\" else "";
                try w.print(
                    "                '(-{c} --{s})'{{-{c},--{s}}}'[{s}]:{s}:'{s}\n",
                    .{ o.short, o.long, o.short, o.long, o.desc, o.name, sep },
                );
            }
        }
        for (c.opt) |opt_name| {
            if (findOption(options, opt_name)) |o| {
                emitted += 1;
                const sep: []const u8 = if (emitted < total) " \\" else "";
                try w.print(
                    "                '(-{c} --{s})'{{-{c},--{s}}}'[{s}]:{s}:'{s}\n",
                    .{ o.short, o.long, o.short, o.long, o.desc, o.name, sep },
                );
            }
        }
        try w.writeAll("            ;;\n");
    }

    try w.writeAll(
        \\        completion)
        \\            _values 'shell' bash zsh fish
        \\            ;;
        \\        docs)
        \\            _values 'format' markdown man text all
        \\            ;;
        \\    esac
        \\}
        \\
        \\_cli "$@"
        \\
    );
}

fn writeFish(w: *std.Io.Writer, commands: []const cli.command, options: []const cli.option) !void {
    try w.writeAll(
        \\# fish completion for cli
        \\complete -c cli -f
        \\
        \\
    );

    for (commands) |c| {
        try w.print(
            "complete -c cli -n '__fish_use_subcommand' -a '{s}' -d '{s}'\n",
            .{ c.name, c.desc },
        );
    }
    try w.writeAll("complete -c cli -n '__fish_use_subcommand' -a 'completion' -d 'Generate shell completion script'\n");
    try w.writeAll("complete -c cli -n '__fish_use_subcommand' -a 'docs' -d 'Generate usage documentation'\n\n");

    for (commands) |c| {
        for (c.req) |opt_name| {
            if (findOption(options, opt_name)) |o| {
                try w.print(
                    "complete -c cli -n '__fish_seen_subcommand_from {s}' -s {c} -l {s} -d '{s}' -r\n",
                    .{ c.name, o.short, o.long, o.desc },
                );
            }
        }
        for (c.opt) |opt_name| {
            if (findOption(options, opt_name)) |o| {
                try w.print(
                    "complete -c cli -n '__fish_seen_subcommand_from {s}' -s {c} -l {s} -d '{s}' -r\n",
                    .{ c.name, o.short, o.long, o.desc },
                );
            }
        }
    }

    try w.writeAll("\ncomplete -c cli -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish'\n");
    try w.writeAll("complete -c cli -n '__fish_seen_subcommand_from docs' -a 'markdown man text all'\n");
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

test "writeBash: emits command names and option flags" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    try writeBash(&aw.writer, &test_commands, &test_options);
    const out = aw.written();

    try testing.expect(std.mem.indexOf(u8, out, "_cli_complete") != null);
    try testing.expect(std.mem.indexOf(u8, out, "hello") != null);
    try testing.expect(std.mem.indexOf(u8, out, "user:list") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-g --greeting") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-n --name") != null);
    try testing.expect(std.mem.indexOf(u8, out, "complete -F _cli_complete cli") != null);
}

test "writeZsh: emits compdef header and escaped colon commands" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    try writeZsh(&aw.writer, &test_commands, &test_options);
    const out = aw.written();

    try testing.expect(std.mem.indexOf(u8, out, "#compdef cli") != null);
    try testing.expect(std.mem.indexOf(u8, out, "user\\:list") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-g --greeting") != null);
    try testing.expect(std.mem.indexOf(u8, out, "_values 'shell' bash zsh fish") != null);
}

test "writeFish: emits per-command complete lines and subcommand options" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    try writeFish(&aw.writer, &test_commands, &test_options);
    const out = aw.written();

    try testing.expect(std.mem.indexOf(u8, out, "complete -c cli -f") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-a 'hello'") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-a 'user:list'") != null);
    try testing.expect(std.mem.indexOf(u8, out, "__fish_seen_subcommand_from hello") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-s g -l greeting") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-s n -l name") != null);
}

test "writeZsh: emits docs subcommand and format completions" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    try writeZsh(&aw.writer, &test_commands, &test_options);
    const out = aw.written();

    try testing.expect(std.mem.indexOf(u8, out, "'docs:Generate usage documentation'") != null);
    try testing.expect(std.mem.indexOf(u8, out, "_values 'format' markdown man text all") != null);
}

test "writeBash: emits descriptions sourced from struct fields" {
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();

    try writeFish(&aw.writer, &test_commands, &test_options);
    const out = aw.written();

    try testing.expect(std.mem.indexOf(u8, out, "-d 'Greet someone'") != null);
    try testing.expect(std.mem.indexOf(u8, out, "-d 'Greeting word'") != null);
}

test "findOption: returns matching option or null" {
    const found = findOption(&test_options, "name");
    try testing.expect(found != null);
    try testing.expectEqual(@as(u8, 'n'), found.?.short);

    try testing.expect(findOption(&test_options, "missing") == null);
}

