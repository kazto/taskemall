const std = @import("std");
const fs = std.fs;
const os = std.os;
const mem = std.mem;
const process = std.process;
const c = @cImport({
    @cInclude("time.h");
    @cInclude("stdlib.h");
});

pub fn parseDateTime(input: []const u8) !i64 {
    if (std.mem.eql(u8, input, "now")) return std.time.timestamp();

    // Try parsing as raw timestamp first
    if (std.fmt.parseInt(i64, input, 10)) |ts| {
        return ts;
    } else |_| {}

    // Prepare tm struct with current time
    var now_sec: c.time_t = c.time(null);
    const now_tm_ptr = c.localtime(&now_sec);
    if (now_tm_ptr == null) return error.TimeError;
    var tm: c.struct_tm = now_tm_ptr.*;

    // Reset seconds by default if we are parsing?
    // Actually if user inputs "12:00", we probably want 12:00:00.
    tm.tm_sec = 0;

    var date_part: ?[]const u8 = null;
    var time_part: ?[]const u8 = null;

    var it = mem.splitScalar(u8, input, ' ');
    const part1 = it.next();
    const part2 = it.next();

    if (part2) |p2| {
        date_part = part1;
        time_part = p2;
    } else {
        if (part1) |p1| {
            if (mem.indexOfScalar(u8, p1, ':') != null) {
                time_part = p1;
            } else {
                date_part = p1;
                // If only date provided, set time to 00:00:00?
                tm.tm_hour = 0;
                tm.tm_min = 0;
                tm.tm_sec = 0;
            }
        }
    }

    if (date_part) |d| {
        // Parse YYYY-MM-DD or YYYY/MM/DD
        // We handle both - and /
        const sep: u8 = if (mem.indexOfScalar(u8, d, '-') != null) '-' else '/';
        var d_it = mem.splitScalar(u8, d, sep);
        const y_str = d_it.next() orelse return error.InvalidDateFormat;
        const m_str = d_it.next() orelse return error.InvalidDateFormat;
        const d_str = d_it.next() orelse return error.InvalidDateFormat;

        const year = std.fmt.parseInt(c_int, y_str, 10) catch return error.InvalidDateFormat;
        const month = std.fmt.parseInt(c_int, m_str, 10) catch return error.InvalidDateFormat;
        const day = std.fmt.parseInt(c_int, d_str, 10) catch return error.InvalidDateFormat;

        tm.tm_year = year - 1900;
        tm.tm_mon = month - 1;
        tm.tm_mday = day;
    }

    if (time_part) |t| {
        // Parse HH:MM:SS or HH:MM
        var t_it = mem.splitScalar(u8, t, ':');
        const h_str = t_it.next() orelse return error.InvalidTimeFormat;
        const m_str = t_it.next() orelse return error.InvalidTimeFormat;
        // Seconds are optional, default to "00"
        const s_str = t_it.next() orelse "00";

        const hour = std.fmt.parseInt(c_int, h_str, 10) catch return error.InvalidTimeFormat;
        const min = std.fmt.parseInt(c_int, m_str, 10) catch return error.InvalidTimeFormat;
        const sec = std.fmt.parseInt(c_int, s_str, 10) catch return error.InvalidTimeFormat;

        tm.tm_hour = hour;
        tm.tm_min = min;
        tm.tm_sec = sec;
    }

    const ts = c.mktime(&tm);
    if (ts == -1) return error.TimeConversionFailed;
    return @intCast(ts);
}

pub fn getDataDir(allocator: mem.Allocator) ![]const u8 {
    var env_map = try process.getEnvMap(allocator);
    defer env_map.deinit();

    if (env_map.get("XDG_DATA_HOME")) |xdg_data_home| {
        return fs.path.join(allocator, &[_][]const u8{ xdg_data_home, "taskemall" });
    }

    if (env_map.get("HOME")) |home| {
        return fs.path.join(allocator, &[_][]const u8{ home, ".local", "share", "taskemall" });
    }

    if (env_map.get("LOCALAPPDATA")) |localappdata| {
        return fs.path.join(allocator, &[_][]const u8{ localappdata, "taskemall" });
    }

    return error.HomeNotFound;
}
