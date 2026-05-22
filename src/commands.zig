const std = @import("std");
const cli = @import("cli.zig");
const interactive = @import("interactive.zig");

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
                "  process         Run a ~5s spinner demo\n" ++
                "  interactive     Launch arrow-key driven menu\n" ++
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

        // Handler for the "process" command (demonstrates the spinner)
        pub fn longRunningCommandFn(_: []const cli.option) bool {
            var spinner = cli.Spinner.init("Processing...") catch |err| {
                std.debug.print("Failed to initialize spinner: {}\n", .{err});
                return false;
            };

            // Simulate work
            var i: usize = 0;
            while (i < 50) : (i += 1) {
                spinner.tick();
                std.Thread.sleep(100 * std.time.ns_per_ms);
            }

            spinner.stop("Done processing!");
            return true;
        }

        // Handler for the "interactive" command — arrow-key driven menu.
        pub fn interactiveFn(_: []const cli.option) bool {
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            const allocator = gpa.allocator();

            cli.printColored(.Magenta, "\n=== Interactive Mode ===\n", .{});
            cli.printColored(.Yellow, "Use \xe2\x86\x91/\xe2\x86\x93 to navigate, Enter to select, Esc to cancel.\n\n", .{});

            const menu_items = [_][]const u8{
                "Say hello",
                "Create a user",
                "List users",
                "Set a config value",
                "Get a config value",
                "Run a long process (spinner)",
                "Show help",
                "Exit",
            };
            const exit_index: usize = menu_items.len - 1;

            while (true) {
                const choice = interactive.promptSelect("Pick a command:", &menu_items) catch |err| {
                    if (err == interactive.Error.Cancelled) {
                        cli.printColored(.Yellow, "Goodbye!\n", .{});
                        return true;
                    }
                    std.debug.print("Error: {s}\n", .{@errorName(err)});
                    return false;
                };

                if (choice == exit_index) {
                    cli.printColored(.Yellow, "Goodbye!\n", .{});
                    return true;
                }

                runSelected(allocator, choice) catch |err| {
                    if (err == interactive.Error.Cancelled) {
                        cli.printColored(.Yellow, "(cancelled)\n", .{});
                    } else {
                        std.debug.print("Error: {s}\n", .{@errorName(err)});
                    }
                };

                std.debug.print("\n", .{});
                const again = interactive.promptConfirm("Run another command?", true) catch false;
                if (!again) {
                    cli.printColored(.Yellow, "Goodbye!\n", .{});
                    return true;
                }
                std.debug.print("\n", .{});
            }
        }

        fn runSelected(allocator: std.mem.Allocator, choice: usize) !void {
            switch (choice) {
                0 => try runHello(allocator),
                1 => try runUserCreate(allocator),
                2 => _ = userListFn(&.{}),
                3 => try runConfigSet(allocator),
                4 => try runConfigGet(allocator),
                5 => _ = longRunningCommandFn(&.{}),
                6 => _ = helpFn(&.{}),
                else => {},
            }
        }

        fn runHello(allocator: std.mem.Allocator) !void {
            const greeting = try interactive.promptText(allocator, "Greeting");
            defer allocator.free(greeting);
            const name = try interactive.promptText(allocator, "Name (leave empty for 'World')");
            defer allocator.free(name);

            const opts = [_]cli.option{
                .{ .name = "greeting", .short = 'g', .long = "greeting", .value = greeting },
                .{ .name = "name", .short = 'n', .long = "name", .value = name },
            };
            _ = helloFn(&opts);
        }

        fn runUserCreate(allocator: std.mem.Allocator) !void {
            const username = try interactive.promptText(allocator, "Username");
            defer allocator.free(username);

            const opts = [_]cli.option{
                .{ .name = "username", .short = 'u', .long = "username", .value = username },
            };
            _ = userCreateFn(&opts);
        }

        fn runConfigSet(allocator: std.mem.Allocator) !void {
            const key = try interactive.promptText(allocator, "Key");
            defer allocator.free(key);
            const value = try interactive.promptText(allocator, "Value");
            defer allocator.free(value);

            const opts = [_]cli.option{
                .{ .name = "key", .short = 'k', .long = "key", .value = key },
                .{ .name = "value", .short = 'v', .long = "value", .value = value },
            };
            _ = configSetFn(&opts);
        }

        fn runConfigGet(allocator: std.mem.Allocator) !void {
            const key = try interactive.promptText(allocator, "Key");
            defer allocator.free(key);

            const opts = [_]cli.option{
                .{ .name = "key", .short = 'k', .long = "key", .value = key },
            };
            _ = configGetFn(&opts);
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
