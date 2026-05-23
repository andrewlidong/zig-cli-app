const std = @import("std");
const cli = @import("cli.zig");
const interactive = @import("interactive.zig");
const config = @import("config.zig");
const runtime = @import("runtime.zig");

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
                "  config:list     List all config values\n" ++
                "  config:delete   Delete a config value (requires --key)\n" ++
                "  process         Run a ~5s spinner demo\n" ++
                "  interactive     Launch arrow-key driven menu\n" ++
                "  completion      Generate shell completion script (bash|zsh|fish)\n" ++
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

            const allocator = runtime.gpa;

            var cfg = config.Config.load(allocator) catch |err| {
                cli.printColored(.Red, "Failed to load config: {s}\n", .{@errorName(err)});
                return false;
            };
            defer cfg.deinit();

            cfg.set(key, value) catch |err| {
                cli.printColored(.Red, "Failed to set: {s}\n", .{@errorName(err)});
                return false;
            };

            cfg.save() catch |err| {
                cli.printColored(.Red, "Failed to save config: {s}\n", .{@errorName(err)});
                return false;
            };

            cli.printColored(.Green, "Set {s} = {s}\n", .{ key, value });
            return true;
        }

        // Handler for the "config:get" command
        pub fn configGetFn(_options: []const cli.option) bool {
            var key: []const u8 = "";
            for (_options) |opt| {
                if (std.mem.eql(u8, opt.name, "key")) key = opt.value;
            }

            const allocator = runtime.gpa;

            var cfg = config.Config.load(allocator) catch |err| {
                cli.printColored(.Red, "Failed to load config: {s}\n", .{@errorName(err)});
                return false;
            };
            defer cfg.deinit();

            const value = cfg.get(key) catch |err| {
                cli.printColored(.Red, "Failed to get: {s}\n", .{@errorName(err)});
                return false;
            };

            if (value) |v| {
                cli.printColored(.Cyan, "{s}\n", .{v});
            } else {
                cli.printColored(.Yellow, "(not set)\n", .{});
            }
            return true;
        }

        // Handler for the "config:list" command
        pub fn configListFn(_: []const cli.option) bool {
            const allocator = runtime.gpa;

            var cfg = config.Config.load(allocator) catch |err| {
                cli.printColored(.Red, "Failed to load config: {s}\n", .{@errorName(err)});
                return false;
            };
            defer cfg.deinit();

            if (cfg.isEmpty()) {
                cli.printColored(.Yellow, "(no config set)\n", .{});
                return true;
            }

            var section_it = cfg.sections.iterator();
            while (section_it.next()) |entry| {
                cli.printColored(.Magenta, "[{s}]\n", .{entry.key_ptr.*});
                var kv_it = entry.value_ptr.iterator();
                while (kv_it.next()) |kv| {
                    cli.printColored(.Cyan, "  {s}", .{kv.key_ptr.*});
                    std.debug.print(" = ", .{});
                    cli.printColored(.Green, "{s}\n", .{kv.value_ptr.*});
                }
            }
            return true;
        }

        // Handler for the "config:delete" command
        pub fn configDeleteFn(_options: []const cli.option) bool {
            var key: []const u8 = "";
            for (_options) |opt| {
                if (std.mem.eql(u8, opt.name, "key")) key = opt.value;
            }

            const allocator = runtime.gpa;

            var cfg = config.Config.load(allocator) catch |err| {
                cli.printColored(.Red, "Failed to load config: {s}\n", .{@errorName(err)});
                return false;
            };
            defer cfg.deinit();

            const removed = cfg.delete(key) catch |err| {
                cli.printColored(.Red, "Failed to delete: {s}\n", .{@errorName(err)});
                return false;
            };

            if (!removed) {
                cli.printColored(.Yellow, "{s} was not set\n", .{key});
                return true;
            }

            cfg.save() catch |err| {
                cli.printColored(.Red, "Failed to save config: {s}\n", .{@errorName(err)});
                return false;
            };

            cli.printColored(.Green, "Deleted {s}\n", .{key});
            return true;
        }

        // Handler for the "process" command (demonstrates the spinner)
        pub fn longRunningCommandFn(_: []const cli.option) bool {
            var spinner = cli.Spinner.init("Processing...");

            // Simulate work
            var i: usize = 0;
            while (i < 50) : (i += 1) {
                spinner.tick();
                std.Io.sleep(runtime.io, .fromMilliseconds(100), .awake) catch {};
            }

            spinner.stop("Done processing!");
            return true;
        }

        // Handler for the "interactive" command — arrow-key driven menu.
        pub fn interactiveFn(_: []const cli.option) bool {
            const allocator = runtime.gpa;

            cli.printColored(.Magenta, "\n=== Interactive Mode ===\n", .{});
            cli.printColored(.Yellow, "Use \xe2\x86\x91/\xe2\x86\x93 to navigate, Enter to select, Esc to cancel.\n\n", .{});

            const menu_items = [_][]const u8{
                "Say hello",
                "Create a user",
                "List users",
                "Set a config value",
                "Get a config value",
                "List config values",
                "Delete a config value",
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
                5 => _ = configListFn(&.{}),
                6 => try runConfigDelete(allocator),
                7 => _ = longRunningCommandFn(&.{}),
                8 => _ = helpFn(&.{}),
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

        fn runConfigDelete(allocator: std.mem.Allocator) !void {
            const key = try interactive.promptText(allocator, "Key");
            defer allocator.free(key);

            const opts = [_]cli.option{
                .{ .name = "key", .short = 'k', .long = "key", .value = key },
            };
            _ = configDeleteFn(&opts);
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
