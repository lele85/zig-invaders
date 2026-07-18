const std = @import("std");
const panic = std.debug.panic;
pub const max_entries = 10;

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
    /// descending and at most `max_entries` lines. Reading a hand-edited
    /// or corrupted file may silently drop legitimate high scores past
    /// the 10th line.
    pub fn initFromContents(self: *HighScore, contents: []const u8) !void {
        var lines = std.mem.splitScalar(
            u8,
            contents,
            '\n',
        );
        while (lines.next()) |line| {
            if (self.count >= max_entries) break;
            self.add(try parseLine(line));
        }
        return;
    }

    pub fn save(_: *const HighScore, _: std.Io) void {
        // TODO: Implement
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
