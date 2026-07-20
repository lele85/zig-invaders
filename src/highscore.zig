const std = @import("std");
const panic = std.debug.panic;
pub const max_entries = 10;
const max_line_len = 62; // "usize_max,usize_max,usize_max" worst case
const max_content_len = max_line_len * max_entries + (max_entries - 1);

pub const HighScoreEntry = struct {
    score: usize,
    level: usize,
    lives: usize,
};

pub fn parseLine(line: []const u8) !HighScoreEntry {
    var parts = std.mem.splitScalar(u8, line, ',');
    const score_str = parts.next() orelse return error.InvalidScoreLine;
    const level_str = parts.next() orelse return error.InvalidScoreLine;
    const lives_str = parts.next() orelse return error.InvalidScoreLine;

    const score = try std.fmt.parseInt(usize, score_str, 10);
    const level = try std.fmt.parseInt(usize, level_str, 10);
    const lives = try std.fmt.parseInt(usize, lives_str, 10);

    return HighScoreEntry{
        .score = score,
        .level = level,
        .lives = lives,
    };
}

pub fn formatEntry(hse: HighScoreEntry, buf: []u8) ![]u8 {
    return std.fmt.bufPrint(buf, "{},{},{}", .{
        hse.score,
        hse.level,
        hse.lives,
    });
}

pub fn formatAll(entries: []const HighScoreEntry, buf: []u8) ![]u8 {
    var offset: usize = 0;

    for (entries, 0..) |hse, idx| {
        if (idx > 0) {
            if (offset >= buf.len) return error.NoSpaceLeft;
            buf[offset] = '\n';
            offset += 1;
        }

        var entry_buf: [64]u8 = undefined;
        const line = try formatEntry(hse, &entry_buf);

        if (offset + line.len > buf.len) return error.NoSpaceLeft;
        std.mem.copyForwards(u8, buf[offset .. offset + line.len], line);
        offset += line.len;
    }

    return buf[0..offset];
}

pub const HighScore = struct {
    scores: [max_entries]HighScoreEntry,
    count: usize,

    pub fn init(io: std.Io, dir: std.Io.Dir) !HighScore {
        var buffer: [1024]u8 = undefined;
        const contents = dir.readFile(
            io,
            "highscores.txt",
            &buffer,
        ) catch |err| switch (err) {
            error.FileNotFound => return HighScore{
                .scores = undefined,
                .count = 0,
            },
            else => return err,
        };

        var hs = HighScore{
            .scores = undefined,
            .count = 0,
        };
        try hs.initFromContents(contents);
        return hs;
    }

    /// Assumes `contents` was produced by `save()` — i.e. already sorted
    /// descending and at most `max_entries` lines. Blank lines are skipped.
    /// Any other malformed line is a hard failure.
    pub fn initFromContents(self: *HighScore, contents: []const u8) !void {
        var lines = std.mem.splitScalar(
            u8,
            contents,
            '\n',
        );
        while (lines.next()) |line| {
            if (self.count >= max_entries) break;
            if (line.len == 0) continue;
            self.add(try parseLine(line));
        }
        return;
    }

    pub fn save(self: *const HighScore, io: std.Io, dir: std.Io.Dir) !void {
        const entries = self.scores[0..self.count];

        var content_buf: [max_content_len]u8 = undefined;
        const content = try formatAll(entries, &content_buf);

        try dir.writeFile(io, .{
            .sub_path = "highscores.txt",
            .data = content,
        });
        return;
    }

    pub fn add(self: *HighScore, hse: HighScoreEntry) void {
        // Find where the new entry belongs among the *existing* entries only.
        // Defaults to hs.count (i.e. "goes at the end") if nothing beats it.
        var insert_idx: usize = self.count;
        for (0..self.count) |idx| {
            if (hse.score >= self.scores[idx].score) {
                insert_idx = idx;
                break;
            }
        }

        // List is full and this score doesn't make the cut.
        if (insert_idx >= max_entries) {
            return;
        }

        // Shift everything from the last occupied slot down to insert_idx
        // one place to the right, dropping the last entry if we're full.
        var i = @min(self.count, max_entries - 1);
        while (i > insert_idx) : (i -= 1) {
            self.scores[i] = self.scores[i - 1];
        }

        self.scores[insert_idx] = hse;
        self.count = @min(self.count + 1, max_entries);

        return;
    }
};
