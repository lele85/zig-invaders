const std = @import("std");

pub const max_entries = 10;

pub const HighScoreEntry = struct {
    score: usize,
    level: usize,
    lives: usize,
};

fn parseField(field: []const u8) usize {
    return std.fmt.parseInt(usize, field, 10) catch |err| {
        std.debug.panic("[FATAL ERROR] - Invalid high score field - {}", .{err});
    };
}

pub fn parseLine(line: []const u8) HighScoreEntry {
    var parts = std.mem.splitScalar(u8, line, ',');
    const score_str = parts.next() orelse "";
    const level_str = parts.next() orelse "";
    const lives_str = parts.next() orelse "";

    const score = parseField(score_str);
    const level = parseField(level_str);
    const lives = parseField(lives_str);

    return HighScoreEntry{
        .score = score,
        .level = level,
        .lives = lives,
    };
}

pub const HighScore = struct {
    scores: [max_entries]HighScoreEntry,
    count: usize,

    pub fn init(_: std.Io) HighScore {
        // TODO: Real implementation reading from disk
        return HighScore{
            .scores = undefined,
            .count = 0,
        };
    }

    pub fn save(_: *const HighScore, _: std.Io) void {
        // TODO: Implement
        return;
    }

    pub fn add(hs: *HighScore, hse: HighScoreEntry) void {
        // Find where the new entry belongs among the *existing* entries only.
        // Defaults to hs.count (i.e. "goes at the end") if nothing beats it.
        var insert_idx: usize = hs.count;
        for (0..hs.count) |idx| {
            if (hse.score >= hs.scores[idx].score) {
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
        var i = @min(hs.count, max_entries - 1);
        while (i > insert_idx) : (i -= 1) {
            hs.scores[i] = hs.scores[i - 1];
        }

        hs.scores[insert_idx] = hse;
        hs.count = @min(hs.count + 1, max_entries);

        return;
    }
};
