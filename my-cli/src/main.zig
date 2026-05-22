const std = @import("std");
const cli = @import("cli.zig");
const cmd = @import("commands.zig");

pub fn main() !void {
    // Define available commands
    const commands = [_]cli.command{
        cli.command{
            .name = "hello",
            .func = &cmd.methods.commands.helloFn,
            .req = &.{"greeting"},  // "greeting" is required
            .opt = &.{"name"},      // "name" remains optional
        },
        cli.command{
            .name = "help",
            .func = &cmd.methods.commands.helpFn,
        },
    };

    // Define available options
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
    };

    // Start the CLI application
    try cli.start(&commands, &options, true);
}
