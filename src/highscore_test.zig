const std = @import("std");
const highscore = @import("highscore.zig");

const HighScore = highscore.HighScore;
const HighScoreEntry = highscore.HighScoreEntry;
const parseLine = highscore.parseLine;
const max_entries = highscore.max_entries;

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

test "parseLine()" {
    const hse = parseLine("100,1,12");
    try std.testing.expectEqual(HighScoreEntry{
        .score = 100,
        .level = 1,
        .lives = 12,
    }, hse);
}

test "Higscore.add() adds a frst entry" {
    var hs = HighScore.init(std.testing.io);
    addScores(&hs, &.{10});
    try expectScores(&hs, &.{10});
}

test "Highscore.add() adds a second entry with lower score" {
    var hs = HighScore.init(std.testing.io);
    addScores(&hs, &.{ 10, 5 });
    try expectScores(&hs, &.{ 10, 5 });
}

test "Highscore.add() adds a second entry with higher score" {
    var hs = HighScore.init(std.testing.io);
    addScores(&hs, &.{ 10, 20 });
    try expectScores(&hs, &.{ 20, 10 });
}

test "Highscore.add() adds several entries" {
    var hs = HighScore.init(std.testing.io);
    addScores(&hs, &.{ 10, 20, 5, 100 });
    try expectScores(&hs, &.{ 100, 20, 10, 5 });
}

test "Highscore.add() push down" {
    var hs = HighScore.init(std.testing.io);
    addScores(&hs, &.{ 100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 75 });
    try expectScores(&hs, &.{ 100, 90, 80, 75, 70, 60, 50, 40, 30, 20 });
}

test "HighScore.add() maintains invariants under random input" {
    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();

    // Run many independent random sequences.
    for (0..500) |_| {
        var hs = HighScore.init(std.testing.io);
        var prev_count: usize = 0;

        // Each sequence adds a random number of random scores.
        const n = random.intRangeAtMost(usize, 0, 30);
        for (0..n) |_| {
            const score = random.intRangeAtMost(usize, 0, 1000);
            hs.add(createScore(score));

            // count only ever grows by 0 or 1, and never exceeds max_entries.
            try std.testing.expect(hs.count <= max_entries);
            try std.testing.expect(hs.count == prev_count or hs.count == prev_count + 1);
            prev_count = hs.count;

            // scores[0..count] must always stay sorted, highest first.
            for (1..hs.count) |i| {
                try std.testing.expect(hs.scores[i - 1].score >= hs.scores[i].score);
            }
        }
    }
}
