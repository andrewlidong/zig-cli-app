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

            cli.printColored(.Green, "{s}, ", .{greeting});
            cli.printColored(.Cyan, "{s}", .{name});
            cli.printColored(.Yellow, "!\n", .{});
            return true;
        }

        // Handler for the "help" command
        pub fn helpFn(_: []const cli.option) bool {
            std.debug.print(
                "Usage: my-cli <command> [options]\n" ++
                "Commands:\n" ++
                "  hello           Greet someone\n" ++
                "  help            Show this help message\n" ++
                "  user:create     Create a user (requires --username)\n" ++
                "  user:list       List users\n" ++
                "  config:set      Set a config value (requires --key and --value)\n" ++
                "  config:get      Get a config value (requires --key)\n" ++
                "\n" ++
                "Options:\n" ++
                "  -n, --name <value>       Name to greet\n" ++
                "  -g, --greeting <value>   Greeting word\n" ++
                "  -u, --username <value>   Username\n" ++
                "  -k, --key <value>        Config key\n" ++
                "  -v, --value <value>      Config value\n"
                , .{}
            );
            return true;
        }

        // Handler for the "user:create" command
        pub fn userCreateFn(_options: []const cli.option) bool {
            var username: []const u8 = "";
            for (_options) |opt| {
                if (std.mem.eql(u8, opt.name, "username")) username = opt.value;
            }
            std.debug.print("Creating user: {s}\n", .{username});
            return true;
        }

        // Handler for the "user:list" command
        pub fn userListFn(_: []const cli.option) bool {
            std.debug.print("Listing users...\n", .{});
            return true;
        }

        // Handler for the "config:set" command
        pub fn configSetFn(_options: []const cli.option) bool {
            var key: []const u8 = "";
            var value: []const u8 = "";
            for (_options) |opt| {
                if (std.mem.eql(u8, opt.name, "key")) key = opt.value;
                if (std.mem.eql(u8, opt.name, "value")) value = opt.value;
            }
            std.debug.print("Setting {s} = {s}\n", .{key, value});
            return true;
        }

        // Handler for the "config:get" command
        pub fn configGetFn(_options: []const cli.option) bool {
            var key: []const u8 = "";
            for (_options) |opt| {
                if (std.mem.eql(u8, opt.name, "key")) key = opt.value;
            }
            std.debug.print("Getting {s}...\n", .{key});
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

        // Handler for the "username" option
        pub fn usernameFn(_: []const u8) bool {
            return true;
        }

        // Handler for the "key" option
        pub fn keyFn(_: []const u8) bool {
            return true;
        }

        // Handler for the "value" option
        pub fn valueFn(_: []const u8) bool {
            return true;
        }
    };
};
