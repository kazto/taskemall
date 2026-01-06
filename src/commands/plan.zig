const std = @import("std");
const db = @import("../db.zig");
const util = @import("../util.zig");

pub fn execute(allocator: std.mem.Allocator, args: []const [:0]u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: plan [rec] <TASK NAME> <PLAN DATETIME>\n", .{});
        return;
    }

    var is_recurring = false;
    var recurrence_pattern: ?[]const u8 = null;
    var arg_idx: usize = 0;

    if (std.mem.eql(u8, args[0], "rec") or std.mem.eql(u8, args[0], "daily")) {
        is_recurring = true;
        recurrence_pattern = "daily";
        arg_idx += 1;
    } else if (std.mem.eql(u8, args[0], "weekly")) {
        is_recurring = true;
        recurrence_pattern = "weekly";
        arg_idx += 1;
    } else if (std.mem.eql(u8, args[0], "workday")) {
        is_recurring = true;
        recurrence_pattern = "workday";
        arg_idx += 1;
    }

    if (args.len < arg_idx + 2) {
        std.debug.print("Usage: plan [daily|weekly|workday] <TASK NAME> <PLAN DATETIME>\n", .{});
        return;
    }

    const task_name = args[arg_idx];
    const time_arg = try std.mem.join(allocator, " ", args[arg_idx + 1 ..]);
    defer allocator.free(time_arg);

    const timestamp = try util.parseDateTime(time_arg);

    const data_dir = try util.getDataDir(allocator);
    defer allocator.free(data_dir);
    const db_path = try std.fs.path.join(allocator, &[_][]const u8{ data_dir, "data.db" });
    defer allocator.free(db_path);

    var database = db.DB.init(allocator);
    try database.open(db_path);
    defer database.close();

    try database.planTask(task_name, timestamp, is_recurring, recurrence_pattern);
    std.debug.print("Planned '{s}' at {}\n", .{ task_name, timestamp });
}
