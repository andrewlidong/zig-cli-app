const std = @import("std");
const cli = @import("cli.zig");
const cmd = @import("commands.zig");
const completion = @import("completion.zig");
const docs = @import("docs.zig");
const runtime = @import("runtime.zig");

const commands = [_]cli.command{
    cli.command{
        .name = "hello",
        .func = &cmd.methods.commands.helloFn,
        .req = &.{"greeting"},
        .opt = &.{"name"},
        .desc = "Greet someone",
    },
    cli.command{
        .name = "help",
        .func = &cmd.methods.commands.helpFn,
        .desc = "Show this help message",
    },
    // User commands
    cli.command{
        .name = "user:create",
        .func = &cmd.methods.commands.userCreateFn,
        .req = &.{"username"},
        .desc = "Create a user",
    },
    cli.command{
        .name = "user:list",
        .func = &cmd.methods.commands.userListFn,
        .desc = "List users",
    },
    // Config commands
    cli.command{
        .name = "config:set",
        .func = &cmd.methods.commands.configSetFn,
        .req = &.{ "key", "value" },
        .desc = "Set a config value",
    },
    cli.command{
        .name = "config:get",
        .func = &cmd.methods.commands.configGetFn,
        .req = &.{"key"},
        .desc = "Get a config value",
    },
    cli.command{
        .name = "config:list",
        .func = &cmd.methods.commands.configListFn,
        .desc = "List all config values",
    },
    cli.command{
        .name = "config:delete",
        .func = &cmd.methods.commands.configDeleteFn,
        .req = &.{"key"},
        .desc = "Delete a config value",
    },
    // Demo of the Spinner from cli.zig
    cli.command{
        .name = "process",
        .func = &cmd.methods.commands.longRunningCommandFn,
        .desc = "Run a ~5s spinner demo",
    },
    // Arrow-key driven menu
    cli.command{
        .name = "interactive",
        .func = &cmd.methods.commands.interactiveFn,
        .desc = "Launch arrow-key driven menu",
    },
};

const options = [_]cli.option{
    cli.option{
        .name = "name",
        .short = 'n',
        .long = "name",
        .func = &cmd.methods.options.nameFn,
        .desc = "Name to greet",
    },
    cli.option{
        .name = "greeting",
        .short = 'g',
        .long = "greeting",
        .func = &cmd.methods.options.greetingFn,
        .desc = "Greeting word",
    },
    cli.option{
        .name = "username",
        .short = 'u',
        .long = "username",
        .func = &cmd.methods.options.usernameFn,
        .desc = "Username",
    },
    cli.option{
        .name = "key",
        .short = 'k',
        .long = "key",
        .func = &cmd.methods.options.keyFn,
        .desc = "Config key",
    },
    cli.option{
        .name = "value",
        .short = 'v',
        .long = "value",
        .func = &cmd.methods.options.valueFn,
        .desc = "Config value",
    },
};

pub fn main(init: std.process.Init) !void {
    runtime.init(init);
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len >= 2 and std.mem.eql(u8, args[1], "completion")) {
        return completion.run(&commands, &options, args);
    }
    if (args.len >= 2 and std.mem.eql(u8, args[1], "docs")) {
        return docs.run(&commands, &options, args);
    }

    try cli.startWithArgs(&commands, &options, args, true);
}

test {
    _ = @import("config.zig");
    _ = @import("cli.zig");
    _ = @import("completion.zig");
    _ = @import("commands.zig");
    _ = @import("docs.zig");
}
