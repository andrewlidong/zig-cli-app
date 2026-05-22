const std = @import("std");

pub const Error = error{
    InvalidKey,
    MalformedConfig,
    HomeNotFound,
};

pub const default_section = "general";
const max_file_size: usize = 1024 * 1024;

pub const KeyParts = struct {
    section: []const u8,
    name: []const u8,
};

pub fn splitKey(key: []const u8) Error!KeyParts {
    if (key.len == 0) return Error.InvalidKey;

    var dot_count: usize = 0;
    var dot_idx: usize = 0;
    for (key, 0..) |c, i| {
        if (c == '.') {
            dot_count += 1;
            dot_idx = i;
        }
    }
    if (dot_count > 1) return Error.InvalidKey;

    const section = if (dot_count == 0) default_section else key[0..dot_idx];
    const name = if (dot_count == 0) key else key[dot_idx + 1 ..];

    if (section.len == 0 or name.len == 0) return Error.InvalidKey;
    if (!isValidIdent(section)) return Error.InvalidKey;
    if (!isValidIdent(name)) return Error.InvalidKey;

    return .{ .section = section, .name = name };
}

fn isValidIdent(s: []const u8) bool {
    if (s.len == 0) return false;
    const first = s[0];
    if (!std.ascii.isAlphabetic(first) and first != '_') return false;
    for (s[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') return false;
    }
    return true;
}

pub const Section = std.StringHashMap([]const u8);

pub const Config = struct {
    allocator: std.mem.Allocator,
    sections: std.StringHashMap(Section),

    pub fn init(allocator: std.mem.Allocator) Config {
        return .{
            .allocator = allocator,
            .sections = std.StringHashMap(Section).init(allocator),
        };
    }

    pub fn deinit(self: *Config) void {
        var it = self.sections.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var inner_it = entry.value_ptr.iterator();
            while (inner_it.next()) |kv| {
                self.allocator.free(kv.key_ptr.*);
                self.allocator.free(kv.value_ptr.*);
            }
            entry.value_ptr.deinit();
        }
        self.sections.deinit();
    }

    pub fn get(self: *const Config, key: []const u8) Error!?[]const u8 {
        const parts = try splitKey(key);
        const section_ptr = self.sections.getPtr(parts.section) orelse return null;
        return section_ptr.get(parts.name);
    }

    pub fn set(self: *Config, key: []const u8, value: []const u8) !void {
        const parts = try splitKey(key);

        const value_dup = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_dup);

        var section_res = try self.sections.getOrPut(parts.section);
        if (!section_res.found_existing) {
            const section_dup = self.allocator.dupe(u8, parts.section) catch |err| {
                _ = self.sections.remove(parts.section);
                return err;
            };
            section_res.key_ptr.* = section_dup;
            section_res.value_ptr.* = Section.init(self.allocator);
        }

        const kv_res = try section_res.value_ptr.getOrPut(parts.name);
        if (kv_res.found_existing) {
            self.allocator.free(kv_res.value_ptr.*);
            kv_res.value_ptr.* = value_dup;
        } else {
            const name_dup = self.allocator.dupe(u8, parts.name) catch |err| {
                _ = section_res.value_ptr.remove(parts.name);
                return err;
            };
            kv_res.key_ptr.* = name_dup;
            kv_res.value_ptr.* = value_dup;
        }
    }

    pub fn delete(self: *Config, key: []const u8) !bool {
        const parts = try splitKey(key);
        const section_ptr = self.sections.getPtr(parts.section) orelse return false;
        const removed = section_ptr.fetchRemove(parts.name) orelse return false;
        self.allocator.free(removed.key);
        self.allocator.free(removed.value);

        if (section_ptr.count() == 0) {
            const outer = self.sections.fetchRemove(parts.section).?;
            self.allocator.free(outer.key);
            var sec = outer.value;
            sec.deinit();
        }
        return true;
    }

    pub fn isEmpty(self: *const Config) bool {
        return self.sections.count() == 0;
    }

    pub fn load(allocator: std.mem.Allocator) !Config {
        const path = try configPath(allocator);
        defer allocator.free(path);

        const file = std.fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
            error.FileNotFound => return Config.init(allocator),
            else => return err,
        };
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, max_file_size);
        defer allocator.free(contents);

        return parse(allocator, contents);
    }

    pub fn save(self: *const Config) !void {
        const path = try configPath(self.allocator);
        defer self.allocator.free(path);

        var buf: std.ArrayList(u8) = .{};
        defer buf.deinit(self.allocator);

        try buf.appendSlice(self.allocator, "# auto-managed by cli\n");

        var section_it = self.sections.iterator();
        while (section_it.next()) |entry| {
            try buf.append(self.allocator, '\n');
            try buf.append(self.allocator, '[');
            try buf.appendSlice(self.allocator, entry.key_ptr.*);
            try buf.appendSlice(self.allocator, "]\n");

            var kv_it = entry.value_ptr.iterator();
            while (kv_it.next()) |kv| {
                try buf.appendSlice(self.allocator, kv.key_ptr.*);
                try buf.appendSlice(self.allocator, " = ");
                try appendQuoted(&buf, self.allocator, kv.value_ptr.*);
                try buf.append(self.allocator, '\n');
            }
        }

        if (std.fs.path.dirname(path)) |dir| {
            try std.fs.cwd().makePath(dir);
        }

        const tmp_path = try std.fmt.allocPrint(self.allocator, "{s}.tmp", .{path});
        defer self.allocator.free(tmp_path);

        {
            const tmp_file = try std.fs.createFileAbsolute(tmp_path, .{ .truncate = true });
            defer tmp_file.close();
            try tmp_file.writeAll(buf.items);
        }

        try std.fs.renameAbsolute(tmp_path, path);
    }
};

pub fn configPath(allocator: std.mem.Allocator) ![]u8 {
    if (std.process.getEnvVarOwned(allocator, "XDG_CONFIG_HOME")) |xdg| {
        defer allocator.free(xdg);
        if (xdg.len > 0) {
            return try std.fs.path.join(allocator, &.{ xdg, "cli", "config" });
        }
    } else |err| switch (err) {
        error.EnvironmentVariableNotFound => {},
        else => return err,
    }

    const home = std.process.getEnvVarOwned(allocator, "HOME") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return Error.HomeNotFound,
        else => return err,
    };
    defer allocator.free(home);

    return try std.fs.path.join(allocator, &.{ home, ".config", "cli", "config" });
}

fn parse(allocator: std.mem.Allocator, source: []const u8) !Config {
    var cfg = Config.init(allocator);
    errdefer cfg.deinit();

    var current_section: []const u8 = default_section;

    var line_iter = std.mem.splitScalar(u8, source, '\n');
    while (line_iter.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;
        if (line[0] == '#') continue;

        if (line[0] == '[') {
            if (line.len < 2 or line[line.len - 1] != ']') return Error.MalformedConfig;
            const section_name = std.mem.trim(u8, line[1 .. line.len - 1], " \t");
            if (!isValidIdent(section_name)) return Error.MalformedConfig;
            current_section = section_name;
            continue;
        }

        const eq_idx = std.mem.indexOfScalar(u8, line, '=') orelse return Error.MalformedConfig;
        const key = std.mem.trim(u8, line[0..eq_idx], " \t");
        const val_raw = std.mem.trim(u8, line[eq_idx + 1 ..], " \t");
        if (!isValidIdent(key)) return Error.MalformedConfig;

        const value = try readQuoted(allocator, val_raw);
        defer allocator.free(value);

        const full_key = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ current_section, key });
        defer allocator.free(full_key);
        try cfg.set(full_key, value);
    }

    return cfg;
}

fn appendQuoted(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try buf.append(allocator, '"');
    for (value) |c| {
        switch (c) {
            '\\' => try buf.appendSlice(allocator, "\\\\"),
            '"' => try buf.appendSlice(allocator, "\\\""),
            '\n' => try buf.appendSlice(allocator, "\\n"),
            else => try buf.append(allocator, c),
        }
    }
    try buf.append(allocator, '"');
}

fn readQuoted(allocator: std.mem.Allocator, src: []const u8) ![]u8 {
    if (src.len < 2 or src[0] != '"' or src[src.len - 1] != '"') return Error.MalformedConfig;
    const inner = src[1 .. src.len - 1];

    var result: std.ArrayList(u8) = .{};
    defer result.deinit(allocator);

    var i: usize = 0;
    while (i < inner.len) : (i += 1) {
        const c = inner[i];
        if (c == '\\') {
            if (i + 1 >= inner.len) return Error.MalformedConfig;
            const next = inner[i + 1];
            switch (next) {
                '\\' => try result.append(allocator, '\\'),
                '"' => try result.append(allocator, '"'),
                'n' => try result.append(allocator, '\n'),
                else => return Error.MalformedConfig,
            }
            i += 1;
        } else {
            try result.append(allocator, c);
        }
    }

    return try result.toOwnedSlice(allocator);
}

// --- tests ---

test "splitKey: bare key uses default section" {
    const parts = try splitKey("foo");
    try std.testing.expectEqualStrings("general", parts.section);
    try std.testing.expectEqualStrings("foo", parts.name);
}

test "splitKey: dotted key splits" {
    const parts = try splitKey("editor.theme");
    try std.testing.expectEqualStrings("editor", parts.section);
    try std.testing.expectEqualStrings("theme", parts.name);
}

test "splitKey: rejects multiple dots" {
    try std.testing.expectError(Error.InvalidKey, splitKey("a.b.c"));
}

test "splitKey: rejects empty parts" {
    try std.testing.expectError(Error.InvalidKey, splitKey(".foo"));
    try std.testing.expectError(Error.InvalidKey, splitKey("foo."));
    try std.testing.expectError(Error.InvalidKey, splitKey(""));
}

test "splitKey: rejects invalid chars" {
    try std.testing.expectError(Error.InvalidKey, splitKey("foo-bar"));
    try std.testing.expectError(Error.InvalidKey, splitKey("1foo"));
}

test "Config: set/get roundtrip" {
    var cfg = Config.init(std.testing.allocator);
    defer cfg.deinit();

    try cfg.set("editor.theme", "dark");
    try std.testing.expectEqualStrings("dark", (try cfg.get("editor.theme")).?);

    try cfg.set("editor.theme", "light");
    try std.testing.expectEqualStrings("light", (try cfg.get("editor.theme")).?);

    try std.testing.expect((try cfg.get("missing")) == null);
}

test "Config: bare key uses general section" {
    var cfg = Config.init(std.testing.allocator);
    defer cfg.deinit();

    try cfg.set("username", "andrew");
    try std.testing.expectEqualStrings("andrew", (try cfg.get("username")).?);
    try std.testing.expectEqualStrings("andrew", (try cfg.get("general.username")).?);
}

test "Config: delete removes key and empty sections" {
    var cfg = Config.init(std.testing.allocator);
    defer cfg.deinit();

    try cfg.set("editor.theme", "dark");
    try std.testing.expect(try cfg.delete("editor.theme"));
    try std.testing.expect((try cfg.get("editor.theme")) == null);
    try std.testing.expect(!(try cfg.delete("editor.theme")));
    try std.testing.expect(cfg.isEmpty());
}

test "parse: roundtrip with escapes" {
    const source =
        "[general]\n" ++
        "name = \"hello \\\"world\\\"\\nbye\"\n";
    var cfg = try parse(std.testing.allocator, source);
    defer cfg.deinit();

    try std.testing.expectEqualStrings("hello \"world\"\nbye", (try cfg.get("name")).?);
}

test "parse: comments and blank lines ignored" {
    const source =
        "# this is a comment\n" ++
        "\n" ++
        "[editor]\n" ++
        "  theme = \"dark\"\n" ++
        "  # another comment\n";
    var cfg = try parse(std.testing.allocator, source);
    defer cfg.deinit();

    try std.testing.expectEqualStrings("dark", (try cfg.get("editor.theme")).?);
}

test "parse: malformed input rejected" {
    try std.testing.expectError(Error.MalformedConfig, parse(std.testing.allocator, "[bad\n"));
    try std.testing.expectError(Error.MalformedConfig, parse(std.testing.allocator, "key = unquoted\n"));
    try std.testing.expectError(Error.MalformedConfig, parse(std.testing.allocator, "noequals\n"));
}

test "appendQuoted/readQuoted: roundtrip" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(std.testing.allocator);

    const input = "hello \"world\"\nand\\backslash";
    try appendQuoted(&buf, std.testing.allocator, input);

    const decoded = try readQuoted(std.testing.allocator, buf.items);
    defer std.testing.allocator.free(decoded);

    try std.testing.expectEqualStrings(input, decoded);
}
