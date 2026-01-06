const std = @import("std");
const db = @import("../db.zig");
const util = @import("../util.zig");

pub fn execute(allocator: std.mem.Allocator) !void {
    const data_dir = try util.getDataDir(allocator);
    defer allocator.free(data_dir);
    const db_path = try std.fs.path.join(allocator, &[_][]const u8{ data_dir, "data.db" });
    defer allocator.free(db_path);

    var database = db.DB.init(allocator);
    try database.open(db_path);
    defer database.close();

    const last_entry = try database.getLastCheckEntry();

    if (last_entry) |entry| {
        defer allocator.free(entry.task_name);

        if (isFreeTime(entry.task_name)) {
            std.debug.print("Free\n", .{});
        } else {
            const current_time = std.time.timestamp();
            const duration = current_time - entry.timestamp;
            const duration_str = try formatDuration(allocator, duration);
            defer allocator.free(duration_str);

            std.debug.print("Working on {s} ({s})\n", .{ entry.task_name, duration_str });
        }
    } else {
        std.debug.print("No status (Free)\n", .{});
    }
}

fn isFreeTime(task_name: []const u8) bool {
    const keywords = [_][]const u8{ "break", "stop", "off" };
    for (keywords) |keyword| {
        if (std.mem.eql(u8, task_name, keyword)) {
            return true;
        }
    }
    return false;
}

fn formatDuration(allocator: std.mem.Allocator, seconds: i64) ![]u8 {
    const hours = @divTrunc(seconds, 3600);
    const minutes = @divTrunc(@rem(seconds, 3600), 60);
    const secs = @rem(seconds, 60);
    return std.fmt.allocPrint(allocator, "{d}h {d}m {d}s", .{ hours, minutes, secs });
}
