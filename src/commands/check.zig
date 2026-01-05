const std = @import("std");
const db = @import("../db.zig");
const util = @import("../util.zig");

pub fn execute(allocator: std.mem.Allocator, args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: check <TASK NAME> [CHECK TIME]\n", .{});
        return;
    }

    const task_name = args[0];
    var timestamp: i64 = std.time.timestamp();

    if (args.len >= 2) {
        // Join remaining arguments to form the time string
        const time_arg = try std.mem.join(allocator, " ", args[1..]);
        defer allocator.free(time_arg);

        timestamp = try util.parseDateTime(time_arg);
    }

    const data_dir = try util.getDataDir(allocator);
    defer allocator.free(data_dir);
    const db_path = try std.fs.path.join(allocator, &[_][]const u8{ data_dir, "data.db" });
    defer allocator.free(db_path);

    var database = db.DB.init(allocator);
    try database.open(db_path);
    defer database.close();

    try database.checkIn(task_name, timestamp);

    std.debug.print("Checked in '{s}' at {}\n", .{ task_name, timestamp });
}
