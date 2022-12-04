const std = @import("std");
const rl = @import("raylib");

const images_extensions = std.ComptimeStringMap([:0]const u8, .{
    .{ ".apng", "image/apng" },
    .{ ".avif", "image/avif" },
    .{ ".gif", "image/gif" },
    .{ ".jpg", "image/jpeg" },
    .{ ".jpeg", "image/jpeg" },
    .{ ".jfif", "image/jpeg" },
    .{ ".pjpeg", "image/jpeg" },
    .{ ".pjp", "image/jpeg" },
    .{ ".png", "image/png" },
    .{ ".svg", "image/svg+xml" },
    .{ ".webp", "image/webp" },
    .{ ".bmp", "image/bmp" },
    .{ ".ico", "image/x-icon" },
    .{ ".cur", "image/x-icon" },
    .{ ".tif", "image/tiff" },
    .{ ".tiff", "image/tiff" },
});

const cb_extensions = std.ComptimeStringMap([:0]const u8, .{
    .{ ".cbz", "Comic Book Zip" },
    .{ ".cb7", "Comic Book 7zip" },
    .{ ".cbr", "Comic Book Rar" },
    .{ ".zip", "Zip Archive" },
    .{ ".7z", "7zip Archive" },
    .{ ".rar", "Rar Archive" },
});

pub fn safeClamp(value: anytype, min: anytype, max: anytype) @TypeOf(value, min, max) {
    return std.math.clamp(value, std.math.min(min, max), std.math.max(min, max));
}

pub fn scaleRect(rect: rl.Rectangle, scale: f32) rl.Rectangle {
    return .{
        .x = rect.x,
        .y = rect.y,
        .width = rect.width * scale,
        .height = rect.height * scale,
    };
}

pub fn clampRect(rect: rl.Rectangle, bounds: rl.Rectangle) rl.Rectangle {
    return .{
        .x = rect.x,
        .y = rect.y,
        .width = std.math.clamp(rect.width, 0, bounds.width),
        .height = std.math.clamp(rect.height, 0, bounds.height),
    };
}

pub fn clampVector2(vector: rl.Vector2, min: rl.Vector2, max: rl.Vector2) rl.Vector2 {
    return .{
        .x = std.math.clamp(vector.x, min.x, max.x),
        .y = std.math.clamp(vector.y, min.y, max.y),
    };
}

pub fn isArchiveFile(filepath: [:0]const u8) bool {
    if (getFileExtension(filepath)) |ext| {
        return cb_extensions.has(ext);
    }

    return false;
}

pub fn getImageMime(filename: [:0]const u8) ![]const u8 {
    if (getFileExtension(filename)) |ext| {
        var buff = [1]u8{0} ** 10;

        for (ext) |char, i| {
            buff[i] = std.ascii.toLower(char);
        }

        return images_extensions.get(buff[0..ext.len]) orelse error.MimeNotFound;
    }

    return error.MimeNotFound;
}

pub fn isImageFilename(filename: [:0]const u8) bool {
    return if (getImageMime(filename)) |_| true else |_| false;
}

pub fn getFileExtension(filepath: [:0]const u8) ?[:0]const u8 {
    return if (std.mem.indexOfScalar(u8, filepath, '.')) |index| filepath[index..] else null;
}
