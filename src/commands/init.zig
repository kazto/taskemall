const std = @import("std");
const db = @import("../db.zig");
const util = @import("../util.zig");

pub fn execute(allocator: std.mem.Allocator) !void {
    const data_dir = try util.getDataDir(allocator);
    defer allocator.free(data_dir);

    // Create directory if it doesn't exist
    try std.fs.cwd().makePath(data_dir);

    const db_path = try std.fs.path.join(allocator, &[_][]const u8{ data_dir, "data.db" });
    defer allocator.free(db_path);

    var database = db.DB.init(allocator);
    try database.open(db_path);
    defer database.close();

    try database.initSchema();
    std.debug.print("Initialized database at {s}\n", .{db_path});
}
