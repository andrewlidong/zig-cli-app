const std = @import("std");
const cli = @import("cli.zig");
const cmd = @import("commands.zig");
const completion = @import("completion.zig");
const runtime = @import("runtime.zig");

const commands = [_]cli.command{
    cli.command{
        .name = "hello",
        .func = &cmd.methods.commands.helloFn,
        .req = &.{"greeting"},
        .opt = &.{"name"},
    },
    cli.command{
        .name = "help",
        .func = &cmd.methods.commands.helpFn,
    },
    // User commands
    cli.command{
        .name = "user:create",
        .func = &cmd.methods.commands.userCreateFn,
        .req = &.{"username"},
    },
    cli.command{
        .name = "user:list",
        .func = &cmd.methods.commands.userListFn,
    },
    // Config commands
    cli.command{
        .name = "config:set",
        .func = &cmd.methods.commands.configSetFn,
        .req = &.{ "key", "value" },
    },
    cli.command{
        .name = "config:get",
        .func = &cmd.methods.commands.configGetFn,
        .req = &.{"key"},
    },
    cli.command{
        .name = "config:list",
        .func = &cmd.methods.commands.configListFn,
    },
    cli.command{
        .name = "config:delete",
        .func = &cmd.methods.commands.configDeleteFn,
        .req = &.{"key"},
    },
    // Demo of the Spinner from cli.zig
    cli.command{
        .name = "process",
        .func = &cmd.methods.commands.longRunningCommandFn,
    },
    // Arrow-key driven menu
    cli.command{
        .name = "interactive",
        .func = &cmd.methods.commands.interactiveFn,
    },
};

const options = [_]cli.option{
    cli.option{
        .name = "name",
        .short = 'n',
        .long = "name",
        .func = &cmd.methods.options.nameFn,
    },
    cli.option{
        .name = "greeting",
        .short = 'g',
        .long = "greeting",
        .func = &cmd.methods.options.greetingFn,
    },
    cli.option{
        .name = "username",
        .short = 'u',
        .long = "username",
        .func = &cmd.methods.options.usernameFn,
    },
    cli.option{
        .name = "key",
        .short = 'k',
        .long = "key",
        .func = &cmd.methods.options.keyFn,
    },
    cli.option{
        .name = "value",
        .short = 'v',
        .long = "value",
        .func = &cmd.methods.options.valueFn,
    },
};

pub fn main(init: std.process.Init) !void {
    runtime.init(init);
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len >= 2 and std.mem.eql(u8, args[1], "completion")) {
        return completion.run(&commands, &options, args);
    }

    try cli.startWithArgs(&commands, &options, args, true);
}

test {
    _ = @import("config.zig");
    _ = @import("cli.zig");
    _ = @import("completion.zig");
}
