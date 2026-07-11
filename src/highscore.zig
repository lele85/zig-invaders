const std = @import("std");

const max_entries = 10;

const HighScoreEntry = struct {
    score: usize,
    level: usize,
    lives: usize,
};

pub const HighScore = struct {
    scores: [max_entries]HighScoreEntry,
    count: usize,

    pub fn init() HighScore {
        // TODO: Real implementation reading from disk
        return HighScore{
            .scores = undefined,
            .count = 0,
        };
    }

    pub fn save(_: *const HighScore) void {
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

fn createScore(score: usize) HighScoreEntry {
    return HighScoreEntry{
        .level = 1,
        .lives = 0,
        .score = score,
    };
}

fn addScores(hs: *HighScore, scores: []const usize) void {
    for (scores) |score| {
        hs.add(createScore(score));
    }
}

fn expectScores(hs: *const HighScore, expected: []const usize) !void {
    try std.testing.expectEqual(expected.len, hs.count);
    for (expected, 0..) |score, idx| {
        try std.testing.expectEqual(createScore(score), hs.scores[idx]);
    }
}

test "Higscore.add() adds a frst entry" {
    var hs = HighScore.init();
    addScores(&hs, &.{10});
    try expectScores(&hs, &.{10});
}

test "Highscore.add() adds a second entry with lower score" {
    var hs = HighScore.init();
    addScores(&hs, &.{ 10, 5 });
    try expectScores(&hs, &.{ 10, 5 });
}

test "Highscore.add() adds a second entry with higher score" {
    var hs = HighScore.init();
    addScores(&hs, &.{ 10, 20 });
    try expectScores(&hs, &.{ 20, 10 });
}

test "Highscore.add() adds several entries" {
    var hs = HighScore.init();
    addScores(&hs, &.{ 10, 20, 5, 100 });
    try expectScores(&hs, &.{ 100, 20, 10, 5 });
}

test "Highscore.add() push down" {
    var hs = HighScore.init();
    addScores(&hs, &.{ 100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 75 });
    try expectScores(&hs, &.{ 100, 90, 80, 75, 70, 60, 50, 40, 30, 20 });
}
