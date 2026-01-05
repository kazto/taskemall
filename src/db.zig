const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const DB = struct {
    db: ?*c.sqlite3 = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) DB {
        return DB{ .allocator = allocator };
    }

    pub fn open(self: *DB, path: []const u8) !void {
        const path_z = try self.allocator.dupeZ(u8, path);
        defer self.allocator.free(path_z);

        if (c.sqlite3_open(path_z, &self.db) != c.SQLITE_OK) {
            const err_msg = c.sqlite3_errmsg(self.db);
            std.debug.print("DB Open Error: {s}\n", .{err_msg});
            return error.DbOpenFailed;
        }
    }

    pub fn close(self: *DB) void {
        if (self.db) |db| {
            _ = c.sqlite3_close(db);
            self.db = null;
        }
    }

    pub fn initSchema(self: *DB) !void {
        const sql =
            \\CREATE TABLE IF NOT EXISTS entries (
            \\    id INTEGER PRIMARY KEY,
            \\    task_name TEXT NOT NULL,
            \\    timestamp INTEGER NOT NULL,
            \\    type TEXT NOT NULL,
            \\    is_recurring INTEGER DEFAULT 0,
            \\    created_at INTEGER DEFAULT (unixepoch('now'))
            \\);
        ;
        try self.exec(sql);
    }

    pub fn exec(self: *DB, sql: []const u8) !void {
        const sql_z = try self.allocator.dupeZ(u8, sql);
        defer self.allocator.free(sql_z);

        var err_msg: [*c]u8 = null;
        if (c.sqlite3_exec(self.db, sql_z, null, null, &err_msg) != c.SQLITE_OK) {
            if (err_msg) |msg| {
                std.debug.print("SQL error: {s}\n", .{msg});
                c.sqlite3_free(msg);
            }
            return error.DbExecFailed;
        }
    }

    pub fn checkIn(self: *DB, task_name: []const u8, timestamp: i64) !void {
        const sql = "INSERT INTO entries (task_name, timestamp, type, is_recurring) VALUES (?, ?, 'CHECK', 0)";
        var stmt: ?*c.sqlite3_stmt = null;

        if (c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null) != c.SQLITE_OK) {
            std.debug.print("Prepare error: {s}\n", .{c.sqlite3_errmsg(self.db)});
            return error.DbPrepareFailed;
        }
        defer _ = c.sqlite3_finalize(stmt);

        // Bind task_name
        // SQLITE_TRANSIENT is -1. Zig cImport might treat it weirdly.
        // We use SQLITE_STATIC (0) because task_name is valid for the duration of this call.
        if (c.sqlite3_bind_text(stmt, 1, task_name.ptr, @intCast(task_name.len), null) != c.SQLITE_OK) return error.DbBindFailed;
        if (c.sqlite3_bind_int64(stmt, 2, timestamp) != c.SQLITE_OK) return error.DbBindFailed;
        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.DbStepFailed;
    }

    pub fn logSequential(self: *DB) !void {
        const sql = "SELECT datetime(timestamp, 'unixepoch', 'localtime'), type, task_name FROM entries ORDER BY timestamp ASC";
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null) != c.SQLITE_OK) return error.DbPrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            const date_str = c.sqlite3_column_text(stmt, 0);
            const type_str = c.sqlite3_column_text(stmt, 1);
            const task_name = c.sqlite3_column_text(stmt, 2);

            std.debug.print("{s} [{s}] {s}\n", .{ date_str, type_str, task_name });
        }
    }

    pub fn logSummary(self: *DB) !void {
        const sql = "SELECT date(timestamp, 'unixepoch', 'localtime'), COUNT(*) FROM entries GROUP BY 1 ORDER BY 1 DESC";
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null) != c.SQLITE_OK) return error.DbPrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        std.debug.print("Date\t\tCount\n", .{});
        std.debug.print("--------------------\n", .{});

        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            const date_str = c.sqlite3_column_text(stmt, 0);
            const count = c.sqlite3_column_int(stmt, 1);

            std.debug.print("{s}\t{}\n", .{ date_str, count });
        }
    }
    pub fn planTask(self: *DB, task_name: []const u8, timestamp: i64, is_recurring: bool) !void {
        const sql = "INSERT INTO entries (task_name, timestamp, type, is_recurring) VALUES (?, ?, 'PLAN', ?)";
        var stmt: ?*c.sqlite3_stmt = null;
        if (c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null) != c.SQLITE_OK) return error.DbPrepareFailed;
        defer _ = c.sqlite3_finalize(stmt);

        if (c.sqlite3_bind_text(stmt, 1, task_name.ptr, @intCast(task_name.len), null) != c.SQLITE_OK) return error.DbBindFailed;
        if (c.sqlite3_bind_int64(stmt, 2, timestamp) != c.SQLITE_OK) return error.DbBindFailed;
        if (c.sqlite3_bind_int(stmt, 3, if (is_recurring) 1 else 0) != c.SQLITE_OK) return error.DbBindFailed;

        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) return error.DbStepFailed;
    }
};
