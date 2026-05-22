const std = @import("std");
const cli = @import("cli.zig");

pub const methods = struct {
    pub const commands = struct {
        // Handler for the "hello" command
        pub fn helloFn(_options: []const cli.option) bool {
            var greeting: []const u8 = undefined;
            var name: []const u8 = "World";

            // Extract options
            for (_options) |opt| {
                if (std.mem.eql(u8, opt.name, "greeting")) {
                    greeting = opt.value;
                } else if (std.mem.eql(u8, opt.name, "name")) {
                    if (opt.value.len > 0) {
                        name = opt.value;
                    }
                }
            }

            std.debug.print("{s}, {s}!\n", .{greeting, name});
            return true;
        }

        // Handler for the "help" command
        pub fn helpFn(_: []const cli.option) bool {
            std.debug.print(
                "Usage: my-cli <command> [options]\n" ++
                "Commands:\n" ++
                "  hello    Greet someone\n" ++
                "  help     Show this help message\n" ++
                "" ++
                "Options for hello:\n" ++
                "  -n, --name <value>    Name to greet\n"
                , .{}
            );
            return true;
        }
    };

    pub const options = struct {
        // Handler for the "name" option
        pub fn nameFn(_: []const u8) bool {
            // Option-specific logic could go here
            return true;
        }

        // Handler for the "greeting" option
        pub fn greetingFn(_: []const u8) bool {
            // Option-specific logic could go here
            return true;
        }
    };
};
