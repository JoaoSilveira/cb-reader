const std = @import("std");
const la = @cImport({
    @cInclude("archive.h");
    @cInclude("archive_entry.h");
});
const rl = @import("raylib");
const Image = @import("image.zig");
const ComicBook = @import("comic_book.zig");
const ReadingManager = @import("reading_manager.zig");
const util = @import("util.zig");

const Tuple = std.meta.Tuple;

fn Rect(comptime number_type: type) type {
    return struct {
        x: number_type,
        y: number_type,
        w: number_type,
        h: number_type,
    };
}

fn Size(comptime number_type: type) type {
    return struct {
        w: number_type,
        h: number_type,
    };
}

const RectF32 = Rect(f32);
const RectI32 = Rect(i32);
const SizeF32 = Size(f32);
const SizeI32 = Size(i32);

const Alignment = enum {
    start,
    center,
    end,
};

const Application = struct {
    const Self = @This();

    const reading_manager_path = "reading_cache.json";

    page: Page,
    resources: Resources,
    reading_manager: ReadingManager,
    next_page: ?Page = null,

    pub fn deinit(self: *Self) void {
        self.reading_manager.deinit(self.allocator());
        self.page.deinit(self.allocator());
        self.resources.deinit();

        self.* = undefined;
    }

    pub fn allocator(self: Self) std.mem.Allocator {
        return self.resources.allocator();
    }

    pub fn transitionToPage(self: *Self, new_page: Page) void {
        self.next_page = new_page;
    }

    pub fn update(self: *Self) void {
        if (self.next_page) |next_page| {
            self.next_page = null;
            self.page.deinit(self.allocator());
            self.page = next_page;
        }
    }
};

const Resources = struct {
    const Self = @This();
    const font_bytes = @embedFile("assets/fonts/Lato-Regular.ttf");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    pub fn init() Self {
        return .{};
    }

    pub fn deinit(self: Self) void {
        _ = self;

        if (gpa.deinit()) {
            std.log.err("There were leaks during the execution of this program", .{});
        }
    }

    pub fn allocator(self: Self) std.mem.Allocator {
        _ = self;
        return gpa.allocator();
    }

    pub fn createFont(self: Self, font_size: c_int, font_chars: [*c]c_int, glyph_count: c_int) rl.Font {
        _ = self;
        return rl.LoadFontFromMemory(".ttf", font_bytes, font_bytes.len, font_size, font_chars, glyph_count);
    }
};

const Page = union(enum) {
    Home: *HomePage,
    Reading: *ReadingPage,

    pub fn deinit(self: Page, allocator: std.mem.Allocator) void {
        switch (self) {
            .Home => |home| {
                home.deinit();
                allocator.destroy(home);
            },
            .Reading => |reading| {
                reading.deinit();
                allocator.destroy(reading);
            },
        }
    }

    pub fn update(self: Page) void {
        switch (self) {
            .Home => |home| home.update(),
            .Reading => |reading| reading.update(),
        }
    }

    pub fn view(self: Page) void {
        switch (self) {
            .Home => |home| home.view(),
            .Reading => |reading| reading.view(),
        }
    }
};

const HomePage = struct {
    const Self = @This();

    const font_size = 40;
    const spacing = 0;

    application: *Application,
    font: rl.Font,
    error_message: ?[:0]const u8 = null,

    pub fn init(application: *Application) Self {
        return .{
            .application = application,
            .font = application.resources.createFont(font_size, null, 0),
        };
    }

    pub fn deinit(self: Self) void {
        rl.UnloadFont(self.font);
    }

    pub fn update(self: *Self) void {
        if (rl.IsFileDropped()) {
            const files = rl.LoadDroppedFiles();
            defer rl.UnloadDroppedFiles(files);

            if (files.count > 1) {
                self.error_message = "You should only drop a file at a time";
            } else {
                self.error_message = null;

                const file_path = files.paths[0];
                const path_len = std.mem.len(file_path);

                if (util.isArchiveFile(file_path[0..path_len :0])) {
                    const reading_page = self.application.allocator().create(ReadingPage) catch {
                        self.error_message = "Could not open the archive due to no memory";
                        return;
                    };

                    reading_page.* = ReadingPage.init(self.application, file_path[0..path_len]) catch {
                        self.error_message = "Could not open the archive due an error";
                        return;
                    };

                    self.application.transitionToPage(.{ .Reading = reading_page });
                } else {
                    self.error_message = "The dropped file is not supported";
                }
            }
        }
    }

    pub fn view(self: Self) void {
        const width = std.math.lossyCast(f32, rl.GetRenderWidth());
        const height = std.math.lossyCast(f32, rl.GetRenderHeight());

        rl.ClearBackground(rl.DARKGRAY);

        const text = "Drag and drop a file here";
        const text_size = rl.MeasureTextEx(self.font, text, font_size, spacing);

        rl.DrawTextEx(
            self.font,
            text,
            util.centerOnContainer(.{ .x = width, .y = height }, text_size),
            font_size,
            spacing,
            rl.SKYBLUE,
        );
    }
};

const ReadingPage = struct {
    const Self = @This();

    application: *Application,
    comic_book: ComicBook,
    error_message: ?[]const u8 = null,
    current_page_index: usize,
    page_map: []?rl.Texture2D,
    current_image: ?Image = null,
    cache_control: ReadingManager.CacheEntryControl,
    offset: rl.Vector2,

    pub fn init(application: *Application, path: []const u8) !Self {
        const w_path = try std.unicode.utf8ToUtf16LeWithNull(application.allocator(), path);
        const comic_book = try ComicBook.init(w_path, application.allocator());
        const cache = try application.reading_manager.getEntryControl(path);

        var self = Self{
            .application = application,
            .comic_book = comic_book,
            .current_page_index = std.math.min(comic_book.pages.len, cache.entry.last_page),
            .page_map = try application.allocator().alloc(?rl.Texture2D, comic_book.pages.len),
            .cache_control = cache,
            .offset = .{ .x = 0, .y = 0 },
        };

        std.mem.set(?rl.Texture2D, self.page_map, null);

        if (self.readPage(self.current_page_index)) |tex| {
            self.current_image = Image.init(
                tex,
                .{ .x = 0, .y = 0, .width = @intToFloat(f32, rl.GetScreenWidth()), .height = @intToFloat(f32, rl.GetScreenHeight()) },
            );
        } else |_| {
            self.error_message = "nbanasdhjkflasdf";
        }

        return self;
    }

    pub fn deinit(self: Self) void {
        for (self.page_map) |maybe_page| {
            if (maybe_page) |page| {
                rl.UnloadTexture(page);
            }
        }
        self.application.allocator().free(self.page_map);
        self.application.allocator().free(self.comic_book.path);
        self.comic_book.deinit();
    }

    fn bytesToTexture(image_type: [:0]const u8, bytes: []const u8) !rl.Texture2D {
        const img = rl.LoadImageFromMemory(image_type.ptr, bytes.ptr, @intCast(c_int, bytes.len));
        defer rl.UnloadImage(img);

        return if (img.data) |_| rl.LoadTextureFromImage(img) else error.InvalidImage;
    }

    fn readPage(self: *Self, page_index: usize) !rl.Texture2D {
        if (self.page_map[page_index]) |buffer| return buffer;

        const data = try self.comic_book.readPageAt(page_index, self.application.allocator());
        defer self.application.allocator().free(data);

        self.page_map[page_index] = try bytesToTexture(util.getFileExtension(self.comic_book.pages[page_index]).?, data);

        return self.page_map[page_index].?;
    }

    pub fn update(self: *Self) void {
        const width = rl.GetRenderWidth();

        if (self.current_image) |*image| {
            image.setOffset(.{
                .x = 0,
                .y = image.offset.end.y + rl.GetMouseWheelMove() * std.math.lossyCast(f32, rl.GetRenderHeight()) * -0.075,
            });

            if (rl.IsWindowResized()) {
                image.setBounds(.{ .x = 0, .y = 0, .width = @intToFloat(f32, rl.GetRenderWidth()), .height = @intToFloat(f32, rl.GetRenderHeight()) });
            }
        }

        const before_index = self.current_page_index;
        defer if (before_index != self.current_page_index) {
            if (self.readPage(self.current_page_index)) |texture| {
                self.current_image = Image.init(
                    texture,
                    .{ .x = 0, .y = 0, .width = @intToFloat(f32, rl.GetRenderWidth()), .height = @intToFloat(f32, rl.GetRenderHeight()) },
                );
            } else |_| {
                self.current_image = null;
                self.error_message = "Failed to load page";
            }
        };

        if (rl.IsMouseButtonPressed(.MOUSE_BUTTON_LEFT)) {
            if (rl.GetMouseX() > @divTrunc(width, 2)) { // next page
                const new_index = self.current_page_index + 1;

                if (new_index == self.comic_book.pages.len) {
                    self.cache_control.setRead(true);
                    self.cache_control.setReadingAgain(false);
                } else {
                    self.current_page_index = new_index;
                }
            } else { // previous page
                self.current_page_index = std.math.sub(usize, self.current_page_index, 1) catch 0;
            }
        } else if (rl.IsKeyPressed(.KEY_RIGHT)) { // next page
            const new_index = self.current_page_index + 1;

            if (new_index == self.comic_book.pages.len) {
                self.cache_control.setRead(true);
                self.cache_control.setReadingAgain(false);
            } else {
                self.current_page_index = new_index;
            }
        } else if (rl.IsKeyPressed(.KEY_LEFT)) { // previous page
            self.current_page_index = std.math.sub(usize, self.current_page_index, 1) catch 0;
        }

        self.cache_control.setLastPage(self.current_page_index);

        if (rl.IsKeyPressed(.KEY_ESCAPE)) {
            const home = self.application.allocator().create(HomePage) catch {
                self.error_message = "Could not open the archive due to no memory";
                return;
            };

            home.* = HomePage.init(self.application);
            self.application.transitionToPage(.{ .Home = home });
        }
    }

    pub fn view(self: *Self) void {
        rl.ClearBackground(rl.DARKGRAY);

        if (self.current_image) |*image| {
            image.draw();
        }
    }
};

pub fn tryOpenArgFile(application: *Application) !Page {
    const args = try std.process.argsAlloc(application.allocator());
    defer std.process.argsFree(application.allocator(), args);

    if (args.len < 2) return error.NoArgProvided;
    if (!util.isArchiveFile(args[1])) return error.NotArchiveFile;

    const reading_page = try application.allocator().create(ReadingPage);
    errdefer application.allocator().destroy(reading_page);

    reading_page.* = try ReadingPage.init(application, args[1]);
    return Page{ .Reading = reading_page };
}

pub fn main() void {
    rl.SetConfigFlags(.{ .Flags = .{
        .window_resizable = true,
        .vsync_hint = true,
    } });
    rl.InitWindow(800, 800, "Comic Book Reader");
    rl.SetTargetFPS(60);
    rl.SetExitKey(.KEY_NULL);

    defer rl.CloseWindow();

    var application: Application = undefined;
    defer application.deinit();

    application.next_page = null;
    application.resources = Resources.init();
    application.reading_manager = ReadingManager.init(Application.reading_manager_path, application.resources.allocator()) catch |err| {
        std.log.err("Failed to create reading manager.Error: {s}", .{@errorName(err)});
        return;
    };
    defer application.reading_manager.persist() catch |err| std.log.err("Failed to persist reading manager. Error: {s}", .{@errorName(err)});
    application.page = Page{
        .Home = create_home: {
            var page = application.allocator().create(HomePage) catch |err| {
                std.log.err("Failed to create home page: {s}", .{@errorName(err)});
                std.os.exit(1);
            };

            page.* = HomePage.init(&application);
            break :create_home page;
        },
    };

    if (tryOpenArgFile(&application)) |page| {
        application.transitionToPage(page);
    } else |_| {}

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();

        application.page.update();
        application.page.view();

        application.update();
    }
}

// fn isImageFilename(filename: []const u8) bool {
//     return if (getImageMime(filename)) |_| true else |_| false;
// }

// fn getImageMime(filename: []const u8) ![]const u8 {
//     if (std.mem.lastIndexOf(u8, filename, ".")) |idx| {
//         var buff: [10]u8 = undefined;

//         for (filename[idx..]) |char, i| {
//             buff[i] = std.ascii.toLower(char);
//         }

//         return images_extensions.get(buff[0 .. filename.len - idx]) orelse error.MimeNotFound;
//     }

//     return error.MimeNotFound;
// }

// fn listImagesInArchive(seq: [*c]const u8, req: [*c]const u8, arg: ?*anyopaque) callconv(.C) void {
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();

//     var files = std.ArrayList([]u8).init(arena.allocator());

//     var a = la.archive_read_new();
//     defer _ = la.archive_read_free(a);

//     _ = la.archive_read_support_filter_all(a);
//     _ = la.archive_read_support_format_all(a);

//     var stream = std.json.TokenStream.init(req[0..std.mem.len(req)]);
//     const args = std.json.parse(std.meta.Tuple(&.{[:0]u8}), &stream, .{ .allocator = arena.allocator() }) catch |err| {
//         webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, @errorName(err).ptr);
//         return;
//     };

//     var r = la.archive_read_open_filename(a, args[0].ptr, 10240);
//     if (r != la.ARCHIVE_OK) {
//         std.log.err("Failed to open file: {}", .{r});
//         webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, "ArchiveOpenFailed");
//         return;
//     }

//     var entry: ?*la.archive_entry = null;
//     while (la.archive_read_next_header(a, &entry) == la.ARCHIVE_OK) {
//         defer _ = la.archive_read_data_skip(a);

//         const name: [*c]const u8 = la.archive_entry_pathname(entry) orelse continue;
//         const len = std.mem.len(name);

//         if (!isImageFilename(name[0..len])) continue;

//         const cpy = arena.allocator().dupe(u8, name[0..len]) catch |err| {
//             webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, @errorName(err).ptr);
//             return;
//         };

//         files.append(cpy) catch |err| {
//             webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, @errorName(err).ptr);
//             return;
//         };
//     }

//     const return_json = stringify(arena.allocator(), files.items) catch |err| {
//         webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, @errorName(err).ptr);
//         return;
//     };

//     webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 0, return_json.ptr);
// }

// fn readImage(seq: [*c]const u8, req: [*c]const u8, arg: ?*anyopaque) callconv(.C) void {
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();

//     var imageDataUrl = std.ArrayList(u8).init(arena.allocator());

//     var stream = std.json.TokenStream.init(req[0..std.mem.len(req)]);
//     const args = std.json.parse(std.meta.Tuple(&.{ [:0]u8, [:0]u8 }), &stream, .{ .allocator = arena.allocator() }) catch |err| {
//         webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, @errorName(err).ptr);
//         return;
//     };

//     var a = la.archive_read_new();
//     defer _ = la.archive_read_free(a);

//     _ = la.archive_read_support_filter_all(a);
//     _ = la.archive_read_support_format_all(a);

//     var r = la.archive_read_open_filename(a, args[0].ptr, 10240);
//     if (r != la.ARCHIVE_OK) {
//         std.log.err("Failed to open file: {}", .{r});
//         webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, "ArchiveOpenFailed");
//         return;
//     }

//     var entry: ?*la.archive_entry = null;
//     while (la.archive_read_next_header(a, &entry) == la.ARCHIVE_OK) {
//         const name: [*c]const u8 = la.archive_entry_pathname(entry) orelse continue;
//         const len = std.mem.len(name);

//         if (!std.mem.eql(u8, name[0..len], args[1])) {
//             _ = la.archive_read_data_skip(a);
//             continue;
//         }

//         imageDataUrl.appendSlice("\"data:") catch |err| {
//             std.log.err("Failed to create URI: {s}", .{@errorName(err)});
//             webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, @errorName(err).ptr);
//             return;
//         };
//         imageDataUrl.appendSlice(getImageMime(name[0..len]) catch {
//             std.log.err("Entry is not a supported image", .{});
//             webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, "UnsuportedImageFormat");
//             return;
//         }) catch |err| {
//             std.log.err("Failed to create URI: {s}", .{@errorName(err)});
//             webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, @errorName(err).ptr);
//             return;
//         };
//         imageDataUrl.appendSlice(";base64,") catch |err| {
//             std.log.err("Failed to create URI: {s}", .{@errorName(err)});
//             webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, @errorName(err).ptr);
//             return;
//         };

//         const entrySize = la.archive_entry_size(entry);
//         var buffer = arena.allocator().alloc(u8, @intCast(usize, entrySize)) catch |err| {
//             std.log.err("Failed to create buffer: {s}", .{@errorName(err)});
//             webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, @errorName(err).ptr);
//             return;
//         };
//         const encoder = std.base64.standard.Encoder;
//         while (true) {
//             const readSize = la.archive_read_data(a, buffer.ptr, buffer.len);

//             if (readSize < 0) {
//                 webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, "ReadFailed");
//                 return;
//             }

//             if (readSize == 0) {
//                 break;
//             }

//             imageDataUrl.ensureUnusedCapacity(encoder.calcSize(@intCast(usize, readSize))) catch |err| {
//                 std.log.err("Failed to create URI: {s}", .{@errorName(err)});
//                 webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, @errorName(err).ptr);
//                 return;
//             };
//             imageDataUrl.items.len += encoder.encode(imageDataUrl.unusedCapacitySlice(), buffer[0..@intCast(usize, readSize)]).len;
//         }
//         break;
//     }

//     imageDataUrl.append('"') catch |err| {
//         std.log.err("Failed to create URI: {s}", .{@errorName(err)});
//         webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, @errorName(err).ptr);
//         return;
//     };

//     webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 0, (imageDataUrl.toOwnedSliceSentinel(0) catch |err| {
//         std.log.err("Failed to create URI: {s}", .{@errorName(err)});
//         webview.ffi.webview_return(@ptrCast(webview.WebViewHandle, arg), seq, 1, @errorName(err).ptr);
//         return;
//     }).ptr);
// }
