const std = @import("std");

pub const EntryType = enum {
    CHECK,
    PLAN,
};

pub const Entry = struct {
    id: i64,
    task_name: []const u8,
    timestamp: i64,
    type: EntryType,
    is_recurring: bool,
    created_at: i64,
};
