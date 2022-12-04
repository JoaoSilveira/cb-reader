const std = @import("std");

const ValidMethods = [_][]u8{
    "OPTIONS",
    "GET",
    "HEAD",
    "POST",
    "PUT",
    "DELETE",
    "TRACE",
    "CONNECT",
    "PATCH",
};

const HttpRequest = struct {
    data: []const u8,

    method: []const u8,
    path: []const u8,

    header: std.StringHashMap([]const u8),

    pub fn fromRequest(alloc: *std.mem.Allocator, data: []const u8) !HttpRequest {
        if (!std.mem.startsWith(u8, data, "GET / HTTP/1.1")) {
            return error.RequestNotSupported;
        }

        var header = std.StringHashMap([]const u8).init(alloc);
        var iter = std.mem.split(u8, data, "\r\n");
        _ = iter.next(); // throw away the first line

        while (iter.next()) |line| {
            const comma = std.mem.indexOf(u8, line, ":") orelse continue;

            try header.put(line[0..comma], line[comma + 2 ..]);
        }

        return HttpRequest{
            .data = data,
            .method = data[0..3],
            .path = data[4..5],
            .header = header,
        };
    }

    pub fn isWebsocketUpgrade(self: HttpRequest) bool {
        return std.mem.eql(u8, self.header.get("Upgrade") orelse return false, "websocket") and std.mem.eql(u8, self.header.get("Connection") orelse return false, "Upgrade") and self.header.get("Sec-WebSocket-Key") != null and self.header.get("Sec-WebSocket-Version") != null;
    }

    pub fn deinit(self: *HttpRequest) void {
        self.header.deinit();
    }
};

const BAD_REQUEST = "HTTP/1.1 400 Bad Request\r\nConnection: Closed\r\n\r\n";

pub fn main() void {
    var buff: [1 << 16]u8 = undefined;
    const addr = std.net.Address.initIp4([_]u8{ 127, 0, 0, 1 }, 53924);
    var server = std.net.StreamServer.init(.{
        .kernel_backlog = 1,
        .reuse_address = true,
    });
    defer server.deinit();

    server.listen(addr) catch |e| {
        std.log.err("Failed to listen to localhost:53924 due to error: {}\n", .{e});
    };
    std.log.debug("Listening to {}\n", .{addr});

    read_loop: while (true) {
        var conn = server.accept() catch |e| {
            std.log.err("Could not accept connection due to error: {}\n", .{e});
            continue;
        };
        defer conn.stream.close();

        std.log.debug("accepted connection\n", .{});

        var bytes = content: {
            var arr = std.ArrayList(u8).init(std.heap.page_allocator);

            while (true) {
                const read_size = conn.stream.read(&buff) catch |e| {
                    std.log.err("Failed to read from localhost:53924 due to error: {}\n", .{e});
                    arr.deinit();

                    continue :read_loop;
                };

                arr.appendSlice(buff[0..read_size]) catch |e| {
                    std.log.err("Failed to read from localhost:53924 due to error: {}\n", .{e});
                    arr.deinit();

                    continue :read_loop;
                };

                if (std.mem.endsWith(u8, arr.items, "\r\n\r\n")) {
                    break :content arr.toOwnedSlice();
                }
            }
        };
        defer std.heap.page_allocator.free(bytes);
        
        std.log.debug("read request\n", .{});

        var req = HttpRequest.fromRequest(std.heap.page_allocator, bytes) catch |e| {
            std.log.err("Failed to parse request due to error: {}\n", .{e});
            _ = conn.stream.write(BAD_REQUEST) catch {};
            continue;
        };
        defer req.deinit();

        if (!req.isWebsocketUpgrade()) {
            std.log.err("Not a websocket upgrade connection\n", .{});
            _ = conn.stream.write(BAD_REQUEST) catch {};
            continue;
        }
        _ = conn.stream.write("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n") catch |e| {
            std.log.err("Failed to write response due to error: {}\n", .{e});
        };
    }
}
