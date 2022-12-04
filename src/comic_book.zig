const std = @import("std");
const la = @cImport({
    @cInclude("archive.h");
    @cInclude("archive_entry.h");
});
const util = @import("util.zig");

const Self = @This();

path: [:0]const u16,
pages: [][:0]u8,
allocator: std.mem.Allocator,

pub fn init(path: [:0]const u16, allocator: std.mem.Allocator) !Self {
    var archive = try openArchive(path);
    defer _ = la.archive_read_free(archive);

    const pages = try readPages(allocator, archive);

    return .{
        .allocator = allocator,
        .path = path,
        .pages = pages,
    };
}

pub fn deinit(self: Self) void {
    for (self.pages) |page| {
        self.allocator.free(page);
    }

    self.allocator.free(self.pages);
}

pub fn readPageAt(self: Self, index: usize, allocator: std.mem.Allocator) ![]u8 {
    if (index >= self.pages.len) return error.PageNotFound;
    const page = self.pages[index];

    var archive = try openArchive(self.path);
    defer _ = la.archive_read_free(archive);

    var entry: ?*la.archive_entry = null;
    while (la.archive_read_next_header(archive, &entry) == la.ARCHIVE_OK) {
        const name: [*c]const u8 = la.archive_entry_pathname(entry) orelse continue;
        const len = std.mem.len(name);

        if (!std.mem.eql(u8, name[0..len], page)) {
            _ = la.archive_read_data_skip(archive);
            continue;
        }

        const entry_size = @intCast(usize, la.archive_entry_size(entry));
        var buffer = try allocator.alloc(u8, entry_size);
        buffer.len = 0;

        while (true) {
            const read_size = la.archive_read_data(archive, buffer.ptr, entry_size - buffer.len);
            if (read_size < 0) return error.ReadError;
            if (read_size == 0) break;

            buffer.len += @intCast(usize, read_size);
        }

        return buffer;
    }

    return error.PageNotFound;
}

fn openArchive(path: [:0]const u16) !*la.archive {
    var archive = la.archive_read_new() orelse return error.NewArchiveFailed;

    _ = la.archive_read_support_filter_all(archive);
    _ = la.archive_read_support_format_all(archive);

    const r = la.archive_read_open_filename_w(archive, path.ptr, 10240);
    if (r != la.ARCHIVE_OK) return error.OpenArchiveFailed;

    return archive;
}

fn readPages(allocator: std.mem.Allocator, archive: *la.archive) ![][:0]u8 {
    var pages = std.ArrayList([:0]u8).init(allocator);
    var entry: ?*la.archive_entry = null;
    while (la.archive_read_next_header(archive, &entry) == la.ARCHIVE_OK) {
        defer _ = la.archive_read_data_skip(archive);

        const name: [*c]const u8 = la.archive_entry_pathname(entry) orelse continue;
        const len = std.mem.len(name);

        if (!util.isImageFilename(name[0..len :0])) continue;
        const cpy = try allocator.dupeZ(u8, name[0..len]);
        try pages.append(cpy);
    }

    try sortPages(pages.items, allocator);

    return pages.toOwnedSlice();
}

fn numberAtIndex(text: []const u8, index: usize) u32 {
    var start = start_index: {
        var i = index;
        while (true) {
            if (@subWithOverflow(usize, i, 1, &i)) break :start_index 0;
            if (!std.ascii.isDigit(text[i])) break :start_index i + 1;

            i -= 1;
        }
    };
    var end = end_index: {
        var i = index + 1;
        while (true) {
            if (i >= text.len) break :end_index text.len;
            if (!std.ascii.isDigit(text[i])) break :end_index i;

            i += 1;
        }
    };

    return std.fmt.parseUnsigned(u32, text[start..end], 10) catch unreachable;
}

const PageSortMetadata = struct {
    page: [:0]u8,
    number: u32,

    pub fn lessThan(_: void, a: PageSortMetadata, b: PageSortMetadata) bool {
        return a.number < b.number;
    }
};

fn attempSortPages(
    pages: [][:0]u8,
    pagesMeta: []PageSortMetadata,
    numbers: *std.DynamicBitSet,
    comptime reverse_index: bool,
) bool {
    var lastSet: usize = 0;
    var iter = numbers.iterator(.{});

    ltr_sort: while (iter.next()) |index| {
        defer lastSet = index;

        if (index - lastSet == 1) {
            if (index - lastSet == 1) numbers.unset(index);
            continue;
        }

        for (pagesMeta) |*meta, i| {
            meta.page = pages[i];
            meta.number = numberAtIndex(
                meta.page,
                if (reverse_index) meta.page.len - index - 1 else index,
            );
        }

        std.sort.sort(PageSortMetadata, pagesMeta, {}, PageSortMetadata.lessThan);
        for (pagesMeta[1..]) |meta, i| {
            if (meta.number - pagesMeta[i].number != 1) continue :ltr_sort;
        }

        for (pagesMeta) |meta, i| {
            pages[i] = meta.page;
        }

        return true;
    }

    return false;
}

fn sortPages(pages: [][:0]u8, allocator: std.mem.Allocator) !void {
    var pagesMeta = try allocator.alloc(PageSortMetadata, pages.len);
    defer allocator.free(pagesMeta);

    var minLength: usize = std.math.maxInt(usize);
    var maxLength: usize = 0;
    for (pages) |page| {
        if (page.len < minLength) minLength = page.len;
        if (page.len > maxLength) maxLength = page.len;
    }

    var ltrNumbers = try std.DynamicBitSet.initFull(allocator, maxLength);
    defer ltrNumbers.deinit();

    var rtlNumbers = try std.DynamicBitSet.initFull(allocator, minLength);
    defer rtlNumbers.deinit();

    for (pages) |page| {
        for (page) |c, i| {
            if (!std.ascii.isDigit(c)) ltrNumbers.unset(i);

            if (i < minLength and !std.ascii.isDigit(page[page.len - i - 1]))
                rtlNumbers.unset(i);
        }
    }

    if (!attempSortPages(pages, pagesMeta, &ltrNumbers, false)) {
        _ = attempSortPages(pages, pagesMeta, &rtlNumbers, true);
    }
}
