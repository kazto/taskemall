const std = @import("std");
const init_cmd = @import("commands/init.zig");
const check_cmd = @import("commands/check.zig");
const log_cmd = @import("commands/log.zig");
const plan_cmd = @import("commands/plan.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "init")) {
        try init_cmd.execute(allocator);
    } else if (std.mem.eql(u8, command, "check")) {
        try check_cmd.execute(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "log")) {
        try log_cmd.execute(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "plan")) {
        try plan_cmd.execute(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "-h") or std.mem.eql(u8, command, "--help")) {
        printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        printUsage();
        std.process.exit(1);
    }
}

fn printUsage() void {
    const usage =
        \\Usage: taskemall <command> [args...]
        \\
        \\Commands:
        \\  init        Initialize the database
        \\  check       Check in/out a task
        \\  log         View task logs
        \\  plan        Plan a task
        \\
    ;
    std.debug.print("{s}\n", .{usage});
}
