const std = @import("std");
const cli = @import("cli.zig");
const runtime = @import("runtime.zig");

const Description = struct {
    name: []const u8,
    desc: []const u8,
};

const command_descriptions = [_]Description{
    .{ .name = "hello",         .desc = "Greet someone" },
    .{ .name = "help",          .desc = "Show help message" },
    .{ .name = "user:create",   .desc = "Create a user" },
    .{ .name = "user:list",     .desc = "List users" },
    .{ .name = "config:set",    .desc = "Set a config value" },
    .{ .name = "config:get",    .desc = "Get a config value" },
    .{ .name = "config:list",   .desc = "List all config values" },
    .{ .name = "config:delete", .desc = "Delete a config value" },
    .{ .name = "process",       .desc = "Run a spinner demo" },
    .{ .name = "interactive",   .desc = "Launch interactive menu" },
    .{ .name = "completion",    .desc = "Generate shell completion script" },
};

const option_descriptions = [_]Description{
    .{ .name = "name",     .desc = "Name to greet" },
    .{ .name = "greeting", .desc = "Greeting word" },
    .{ .name = "username", .desc = "Username" },
    .{ .name = "key",      .desc = "Config key" },
    .{ .name = "value",    .desc = "Config value" },
};

fn descFor(table: []const Description, name: []const u8) []const u8 {
    for (table) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry.desc;
    }
    return "";
}

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
        const desc = descFor(&command_descriptions, c.name);
        try w.writeAll("        '");
        for (c.name) |ch| {
            if (ch == ':') try w.writeAll("\\");
            try w.print("{c}", .{ch});
        }
        try w.print(":{s}'\n", .{desc});
    }
    try w.writeAll("        'completion:Generate shell completion script'\n");
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
                const o_desc = descFor(&option_descriptions, o.name);
                const sep: []const u8 = if (emitted < total) " \\" else "";
                try w.print(
                    "                '(-{c} --{s})'{{-{c},--{s}}}'[{s}]:{s}:'{s}\n",
                    .{ o.short, o.long, o.short, o.long, o_desc, o.name, sep },
                );
            }
        }
        for (c.opt) |opt_name| {
            if (findOption(options, opt_name)) |o| {
                emitted += 1;
                const o_desc = descFor(&option_descriptions, o.name);
                const sep: []const u8 = if (emitted < total) " \\" else "";
                try w.print(
                    "                '(-{c} --{s})'{{-{c},--{s}}}'[{s}]:{s}:'{s}\n",
                    .{ o.short, o.long, o.short, o.long, o_desc, o.name, sep },
                );
            }
        }
        try w.writeAll("            ;;\n");
    }

    try w.writeAll(
        \\        completion)
        \\            _values 'shell' bash zsh fish
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
        const desc = descFor(&command_descriptions, c.name);
        try w.print(
            "complete -c cli -n '__fish_use_subcommand' -a '{s}' -d '{s}'\n",
            .{ c.name, desc },
        );
    }
    try w.writeAll("complete -c cli -n '__fish_use_subcommand' -a 'completion' -d 'Generate shell completion script'\n\n");

    for (commands) |c| {
        for (c.req) |opt_name| {
            if (findOption(options, opt_name)) |o| {
                const o_desc = descFor(&option_descriptions, o.name);
                try w.print(
                    "complete -c cli -n '__fish_seen_subcommand_from {s}' -s {c} -l {s} -d '{s}' -r\n",
                    .{ c.name, o.short, o.long, o_desc },
                );
            }
        }
        for (c.opt) |opt_name| {
            if (findOption(options, opt_name)) |o| {
                const o_desc = descFor(&option_descriptions, o.name);
                try w.print(
                    "complete -c cli -n '__fish_seen_subcommand_from {s}' -s {c} -l {s} -d '{s}' -r\n",
                    .{ c.name, o.short, o.long, o_desc },
                );
            }
        }
    }

    try w.writeAll("\ncomplete -c cli -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish'\n");
}
