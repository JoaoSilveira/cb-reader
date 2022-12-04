const std = @import("std");
const rl = @import("raylib");
const pi = std.math.pi;

// got from https://easings.net
pub const easings = struct {
    fn simplePow(comptime power: comptime_int, value: f32) f32 {
        comptime var it = power;
        var result = value;

        inline while (it > 0) : (it -= 1) {
            result *= value;
        }

        return result;
    }

    fn powerEasingInOut(comptime power: comptime_int, value: f32) f32 {
        if (value < 0.5) {
            return (1 << (power - 1)) * simplePow(power, value);
        }

        return 1 - simplePow(-2 * value + 2, power) / 2;
    }

    pub fn linear(value: f32) f32 {
        return value;
    }

    pub fn sineIn(value: f32) f32 {
        return 1 - @cos(value * pi / 2);
    }

    pub fn sineOut(value: f32) f32 {
        return @sin(value * pi / 2);
    }

    pub fn sineInOut(value: f32) f32 {
        return -(@cos(value * pi) - 1) / 2;
    }

    pub fn quadIn(value: f32) f32 {
        return simplePow(2, value);
    }

    pub fn quadOut(value: f32) f32 {
        return 1 - simplePow(2, 1 - value);
    }

    pub fn quadInOut(value: f32) f32 {
        return powerEasingInOut(2, value);
    }

    pub fn cubicIn(value: f32) f32 {
        return simplePow(3, value);
    }

    pub fn cubicOut(value: f32) f32 {
        return 1 - simplePow(3, 1 - value);
    }

    pub fn cubicInOut(value: f32) f32 {
        return powerEasingInOut(3, value);
    }

    pub fn quartIn(value: f32) f32 {
        return simplePow(4, value);
    }

    pub fn quartOut(value: f32) f32 {
        return 1 - simplePow(4, 1 - value);
    }

    pub fn quartInOut(value: f32) f32 {
        return powerEasingInOut(4, value);
    }

    pub fn quintIn(value: f32) f32 {
        return simplePow(5, value);
    }

    pub fn quintOut(value: f32) f32 {
        return 1 - simplePow(5, 1 - value);
    }

    pub fn quintInOut(value: f32) f32 {
        return powerEasingInOut(5, value);
    }

    pub fn expoIn(value: f32) f32 {
        return if (value == 0) 0 else std.math.pow(f32, 2, 10 * value - 10);
    }

    pub fn expoOut(value: f32) f32 {
        return if (value == 1) 1 else 1 - std.math.pow(f32, 2, -10 * value);
    }

    pub fn expoInOut(value: f32) f32 {
        return switch (value) {
            0 => 0,
            1 => 1,
            _ => if (value < 0.5) std.math.pow(f32, 2, 20 * value - 10) / 2 else (2 - std.math.pow(f32, 2, -20 * value + 10)) / 2,
        };
    }

    pub fn circIn(value: f32) f32 {
        return 1 - std.math.sqrt(1 - simplePow(2, value));
    }

    pub fn circOut(value: f32) f32 {
        return std.math.sqrt(1 - simplePow(2, value - 1));
    }

    pub fn circInOut(value: f32) f32 {
        return if (value < 0.5) (1 - std.math.sqrt(1 - simplePow(2, 2 * value))) / 2 else (std.math.sqrt(1 - simplePow(2, -2 * value + 2)) + 1) / 2;
    }

    pub fn backIn(value: f32) f32 {
        const c1 = 1.70158;
        const c3 = c1 + 1;

        return c3 * simplePow(3, value) - c1 * simplePow(2, value);
    }

    pub fn backOut(value: f32) f32 {
        const c1 = 1.70158;
        const c3 = c1 + 1;

        return 1 + c3 * simplePow(3, value - 1) + c1 * simplePow(2, value - 1);
    }

    pub fn backInOut(value: f32) f32 {
        const c1 = 1.70158;
        const c2 = c1 * 1.525;

        if (value < 0.5) {
            return (simplePow(2, 2 * value) * ((c2 + 1) * 2 * value - c2)) / 2;
        }

        return (simplePow(2, 2 * value - 2) * ((c2 + 1) * (value * 2 - 2) + c2) + 2) / 2;
    }

    pub fn elasticIn(value: f32) f32 {
        const c4 = 2 * std.math.pi / 3;

        return switch (value) {
            0 => 0,
            1 => 1,
            _ => -std.math.pow(f32, 2, 10 * value - 10) * @sin((value * 10 - 10.75) * c4),
        };
    }

    pub fn elasticOut(value: f32) f32 {
        const c4 = 2 * std.math.pi / 3;

        return switch (value) {
            0 => 0,
            1 => 1,
            _ => std.math.pow(f32, 2, -10 * value) * @sin((value * 10 - 0.75) * c4) + 1,
        };
    }

    pub fn elasticInOut(value: f32) f32 {
        const c5 = 2 * std.math.pi / 4.5;

        return switch (value) {
            0 => 0,
            1 => 1,
            _ => result: {
                if (value < 0.5)
                    break :result -(std.math.pow(f32, 2, 20 * value - 10) * @sin((20 * value - 11.125) * c5)) / 2;

                break :result (std.math.pow(f32, 2, -20 * value + 10) * @sin((20 * value - 11.125) * c5)) / 2 + 1;
            },
        };
    }

    pub fn bounceIn(value: f32) f32 {
        return 1 - bounceOut(1 - value);
    }

    pub fn bounceOut(value: f32) f32 {
        const n1 = 7.5625;
        const d1 = 2.75;

        if (value < 1 / d1) {
            return n1 * value * value;
        }

        if (value < 2 / d1) {
            return n1 * simplePow(2, value - 1.5 / d1) + 0.75;
        }

        if (value < 2.5 / d1) {
            return n1 * simplePow(2, value - 2.25 / d1) + 0.9375;
        }

        return n1 * simplePow(2, value - 2.625 / d1) + 0.984375;
    }

    pub fn bounceInOut(value: f32) f32 {
        return (if (value < 0.5) 1 - bounceOut(1 - 2 * value) else 1 + bounceOut(2 * value - 1)) / 2;
    }
};

const interpolations = struct {
    pub fn @"f32"(start: f32, end: f32, f: f32) f32 {
        return start + (end - start) * f;
    }

    pub fn @"f64"(start: f64, end: f64, f: f32) f64 {
        return start + (end - start) * f;
    }

    pub fn vector2(start: rl.Vector2, end: rl.Vector2, f: f32) rl.Vector2 {
        return .{
            .x = @"f32"(start.x, end.x, f),
            .y = @"f32"(start.y, end.y, f),
        };
    }
};

fn interpolationForType(comptime Type: type) ?fn (Type, Type, f32) Type {
    if (Type == f32) return interpolations.@"f32";
    if (Type == f64) return interpolations.@"f32";
    if (Type == rl.Vector2) return interpolations.vector2;

    return null;
}

pub fn AnimatedValue(
    comptime Type: type,
    comptime args: struct {
        interpolate: ?fn (Type, Type, f32) Type = null,
        easing: fn (f32) f32 = easings.linear,
        duration: f32 = 0.2,
    },
) type {
    const progress_time_scale: f32 = 1 / args.duration;
    const interpolate = if (args.interpolate) |func|
        func
    else
        (interpolationForType(Type) orelse @compileError("There's no default interpolator for " ++ @typeName(Type)));

    return struct {
        const Self = @This();

        progress: f32,
        start: Type,
        end: Type,
        current: Type,

        pub fn init(value: Type) Self {
            return .{
                .progress = 1,
                .start = value,
                .end = value,
                .current = value,
            };
        }

        pub fn advance(self: *Self, seconds: f32) void {
            if (self.progress == 1) return;

            self.progress = std.math.min(1, seconds * progress_time_scale);
            self.current = interpolate(self.start, self.end, args.easing(self.progress));
        }

        pub fn setValue(self: *Self, value: Type) void {
            self.start = self.current;
            self.end = value;
            self.progress = 0;
        }

        pub fn setValueSkip(self: *Self, value: Type) void {
            self.progress = 1;
            self.start = value;
            self.end = value;
            self.current = value;
        }
    };
}
