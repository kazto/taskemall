const std = @import("std");
const db = @import("../db.zig");
const util = @import("../util.zig");

pub fn execute(allocator: std.mem.Allocator, args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: log <seq|sum>\n", .{});
        return;
    }

    const subcmd = args[0];

    const data_dir = try util.getDataDir(allocator);
    defer allocator.free(data_dir);
    const db_path = try std.fs.path.join(allocator, &[_][]const u8{ data_dir, "data.db" });
    defer allocator.free(db_path);

    var database = db.DB.init(allocator);
    try database.open(db_path);
    defer database.close();

    if (std.mem.eql(u8, subcmd, "seq")) {
        try database.logSequential();
    } else if (std.mem.eql(u8, subcmd, "sum")) {
        try database.logSummary();
    } else {
        std.debug.print("Unknown log command: {s}\n", .{subcmd});
        std.debug.print("Usage: log <seq|sum>\n", .{});
    }
}
