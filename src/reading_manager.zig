const std = @import("std");

const Self = @This();

const CacheEntry = struct {
    read: bool,
    reading_again: bool,
    last_page: usize,

    fn parseFromValue(value: std.json.Value) !CacheEntry {
        return switch (value) {
            .Object => |map| .{
                .read = try getBool(map.get("read") orelse return error.MissingCacheEntryField),
                .reading_again = try getBool(map.get("reading_again") orelse return error.MissingCacheEntryField),
                .last_page = try getUsize(map.get("last_page") orelse return error.MissingCacheEntryField),
            },
            else => error.InvalidCacheEntryJson,
        };
    }

    fn getBool(value: std.json.Value) !bool {
        return switch (value) {
            .Bool => |b| b,
            else => error.InvalidValue,
        };
    }

    fn getUsize(value: std.json.Value) !usize {
        return switch (value) {
            .Integer => |v| std.math.cast(usize, v) orelse error.InvalidValue,
            else => error.InvalidValue,
        };
    }
};

pub const CacheEntryControl = struct {
    manager: *Self,
    entry: *CacheEntry,

    pub fn setRead(self: *CacheEntryControl, read: bool) void {
        self.entry.read = read;
    }

    pub fn setReadingAgain(self: *CacheEntryControl, reading_again: bool) void {
        self.entry.reading_again = reading_again;
    }

    pub fn setLastPage(self: *CacheEntryControl, page: usize) void {
        self.entry.last_page = page;
    }

    pub fn persist(self: CacheEntryControl) !void {
        try self.manager.persist();
    }
};

path: []u8,
cache: std.StringArrayHashMap(CacheEntry),
keys: std.ArrayList([]u8),

pub fn init(path: []const u8, allocator: std.mem.Allocator) !Self {
    var cache = std.StringArrayHashMap(CacheEntry).init(allocator);
    var keys = std.ArrayList([]u8).init(allocator);
    var content = std.fs.cwd().readFileAlloc(allocator, path, 1 << 25) catch |err| {
        if (err == error.FileNotFound) {
            return .{
                .cache = cache,
                .path = try allocator.dupe(u8, path),
                .keys = keys,
            };
        }

        return err;
    };
    defer allocator.free(content);

    var parser = std.json.Parser.init(allocator, true);
    defer parser.deinit();

    var valueTree = try parser.parse(content);
    defer valueTree.deinit();

    switch (valueTree.root) {
        .Object => |map| {
            var iter = map.iterator();
            while (iter.next()) |entry| {
                const dupe_key = try std.ascii.allocLowerString(allocator, entry.key_ptr.*);

                try keys.append(dupe_key);
                try cache.put(dupe_key, try CacheEntry.parseFromValue(entry.value_ptr.*));
            }
        },
        else => return error.InvalidReadingManagerJson,
    }

    return .{
        .cache = cache,
        .path = try allocator.dupe(u8, path),
        .keys = keys,
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.path);
    self.cache.deinit();

    for (self.keys.items) |k| {
        allocator.free(k);
    }
    self.keys.deinit();

    self.* = undefined;
}

pub fn getEntryControl(self: *Self, path: []const u8) !CacheEntryControl {
    const lower_key = try std.ascii.allocLowerString(self.keys.allocator, path);
    errdefer self.keys.allocator.free(lower_key);

    const result = try self.cache.getOrPut(lower_key);

    if (!result.found_existing) {
        try self.keys.append(lower_key);

        result.value_ptr.* = CacheEntry{
            .read = false,
            .reading_again = false,
            .last_page = 0,
        };
    } else {
        self.keys.allocator.free(lower_key);
    }

    return CacheEntryControl{
        .manager = self,
        .entry = result.value_ptr,
    };
}

pub fn persist(self: Self) !void {
    var file = std.fs.cwd().openFile(self.path, .{ .mode = .write_only }) catch |err| new_file: {
        if (err == error.FileNotFound) {
            break :new_file try std.fs.cwd().createFile(self.path, .{});
        }

        return err;
    };
    defer file.close();

    var writer = file.writer();
    try writer.writeAll("{");

    var it = self.cache.iterator();
    while (it.next()) |entry| {
        if (it.index > 1) {
            try writer.writeByte(',');
        }

        try std.json.stringify(entry.key_ptr.*, .{}, writer);
        try writer.writeByte(':');
        try std.json.stringify(entry.value_ptr.*, .{}, writer);
    }

    try writer.writeAll("}");
    try file.sync();
}
