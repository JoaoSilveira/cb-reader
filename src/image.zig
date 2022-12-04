const rl = @import("raylib");
const std = @import("std");
const util = @import("util.zig");
const animation = @import("animation.zig");
const Self = @This();

const OffsetValue = animation.AnimatedValue(rl.Vector2, .{ .duration = 0.1 });
const ScaleValue = animation.AnimatedValue(f32, .{});

bounds: rl.Rectangle,
source: rl.Texture2D,
offset: OffsetValue,
scale: ScaleValue,

pub fn init(source: rl.Texture2D, bounds: rl.Rectangle) Self {
    rl.SetTextureFilter(source, 1);

    return .{
        .bounds = bounds,
        .source = source,
        .offset = OffsetValue.init(.{ .x = 0, .y = 0 }),
        .scale = ScaleValue.init(bounds.width / std.math.lossyCast(f32, source.width)),
    };
}

pub fn setScale(self: *Self, scale: f32) void {
    self.scale.setValue(scale);
}

pub fn setOffset(self: *Self, offset: rl.Vector2) void {
    const rect = util.scaleRect(self.imageRect(), self.scale.current);
    var clampedOffset = rl.Vector2{ .x = 0, .y = 0 };

    if (rect.width > self.bounds.width) {
        clampedOffset.x = std.math.clamp(offset.x, 0, (rect.width - self.bounds.width) / self.scale.current);
    }

    if (rect.height > self.bounds.height) {
        clampedOffset.y = std.math.clamp(offset.y, 0, (rect.height - self.bounds.height) / self.scale.current);
    }

    self.offset.setValue(clampedOffset);
}

pub fn setBounds(self: *Self, bounds: rl.Rectangle) void {
    self.bounds = bounds;
    self.setOffset(self.offset.current);
    // TODO: maybe update scale
}

pub fn draw(self: *Self) void {
    const delta = rl.GetFrameTime();

    self.offset.advance(delta);
    self.scale.advance(delta);

    var source = util.scaleRect(self.bounds, 1 / self.scale.current);
    source = util.clampRect(source, self.imageRect());
    source.x = self.offset.current.x;
    source.y = self.offset.current.y;

    const dest = dest_rect: {
        const img = util.scaleRect(self.imageRect(), self.scale.current);
        var dest = util.clampRect(self.bounds, img);
        dest.x = std.math.max(0, (self.bounds.width - dest.width) / 2);
        dest.y = std.math.max(0, (self.bounds.height - dest.height) / 2);

        break :dest_rect dest;
    };

    rl.DrawTexturePro(
        self.source,
        source,
        dest,
        .{ .x = 0, .y = 0 },
        0,
        rl.WHITE,
    );
}

fn imageRect(self: Self) rl.Rectangle {
    return .{ .x = 0, .y = 0, .width = @intToFloat(f32, self.source.width), .height = @intToFloat(f32, self.source.height) };
}
