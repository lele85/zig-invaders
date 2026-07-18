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
        try std.testing.expectEqual(
            createScore(score),
            hs.scores[idx],
        );
    }
}

test "parseLine() should parse a correct line" {
    const hse = try parseLine("100,1,12");
    try std.testing.expectEqual(HighScoreEntry{
        .score = 100,
        .level = 1,
        .lives = 12,
    }, hse);
}

test "parseLine() should throw an error when the line is not valid" {
    try std.testing.expectError(
        error.InvalidScoreLine,
        parseLine("1,3"),
    );
}

test "parseLine() should throw an error when the line is valid but a value is not" {
    try std.testing.expectError(
        error.InvalidCharacter,
        parseLine("1,valid,3"),
    );
}

test "parseLine() should throw an error when the line is valid but a value is overflowing" {
    try std.testing.expectError(
        error.Overflow,
        parseLine("1,18446744073709551616,3"),
    );
}

test "init() returns empty HighScore when file is missing" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const hs = try HighScore.init(std.testing.io, tmp.dir);
    try std.testing.expectEqual(0, hs.count);
}

test "init() loads and sorts scores from an existing file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(
        std.testing.io,
        .{
            .sub_path = "highscores.txt",
            .data = "100,1,1\n200,1,1",
        },
    );

    const hs = try HighScore.init(std.testing.io, tmp.dir);
    try std.testing.expectEqual(2, hs.count);
    try std.testing.expectEqual(try parseLine("200,1,1"), hs.scores[0]);
    try std.testing.expectEqual(try parseLine("100,1,1"), hs.scores[1]);
}

test "init() propagates an error when a line is corrupted" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(
        std.testing.io,
        .{
            .sub_path = "highscores.txt",
            .data = "100,1,1\nnot,a,valid,line",
        },
    );

    try std.testing.expectError(
        error.InvalidCharacter,
        HighScore.init(
            std.testing.io,
            tmp.dir,
        ),
    );
}

test "Highscore.initFromContents() should initialize scores correctly" {
    var hs = HighScore{
        .count = 0,
        .scores = undefined,
    };
    try hs.initFromContents(
        \\200,1,1
        \\100,1,1
    );
    try std.testing.expectEqual(2, hs.count);
    try std.testing.expectEqual(try parseLine("200,1,1"), hs.scores[0]);
    try std.testing.expectEqual(try parseLine("100,1,1"), hs.scores[1]);
}

test "Highscore.initFromContents() should keep scores in order" {
    var hs = HighScore{
        .count = 0,
        .scores = undefined,
    };
    try hs.initFromContents(
        \\200,1,1
        \\100,1,1
        \\150,1,1
        \\400,1,1
    );
    try std.testing.expectEqual(4, hs.count);
    try std.testing.expectEqual(try parseLine("400,1,1"), hs.scores[0]);
    try std.testing.expectEqual(try parseLine("200,1,1"), hs.scores[1]);
    try std.testing.expectEqual(try parseLine("150,1,1"), hs.scores[2]);
    try std.testing.expectEqual(try parseLine("100,1,1"), hs.scores[3]);
}

test "Highscore.initFromContents() should not parse anything after the 10th line" {
    var hs = HighScore{
        .count = 0,
        .scores = undefined,
    };
    try hs.initFromContents(
        \\100,1,1
        \\90,1,1
        \\80,1,1
        \\70,1,1
        \\60,1,1
        \\50,1,1
        \\40,1,1
        \\30,1,1
        \\20,1,1
        \\10,1,1
        \\5,1,1
        \\200,1,1
    );
    try std.testing.expectEqual(10, hs.count);
    try std.testing.expectEqual(try parseLine("100,1,1"), hs.scores[0]);
    try std.testing.expectEqual(try parseLine("90,1,1"), hs.scores[1]);
}

test "Higscore.add() adds a frst entry" {
    var hs = HighScore{
        .count = 0,
        .scores = undefined,
    };
    addScores(&hs, &.{10});
    try expectScores(&hs, &.{10});
}

test "Highscore.add() adds a second entry with lower score" {
    var hs = HighScore{
        .count = 0,
        .scores = undefined,
    };
    addScores(&hs, &.{ 10, 5 });
    try expectScores(&hs, &.{ 10, 5 });
}

test "Highscore.add() adds a second entry with higher score" {
    var hs = HighScore{
        .count = 0,
        .scores = undefined,
    };
    addScores(&hs, &.{ 10, 20 });
    try expectScores(&hs, &.{ 20, 10 });
}

test "Highscore.add() adds several entries" {
    var hs = HighScore{
        .count = 0,
        .scores = undefined,
    };
    addScores(&hs, &.{ 10, 20, 5, 100 });
    try expectScores(&hs, &.{ 100, 20, 10, 5 });
}

test "Highscore.add() push down" {
    var hs = HighScore{
        .count = 0,
        .scores = undefined,
    };
    addScores(&hs, &.{ 100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 75 });
    try expectScores(&hs, &.{ 100, 90, 80, 75, 70, 60, 50, 40, 30, 20 });
}

test "HighScore.add() maintains invariants under random input" {
    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();

    // Run many independent random sequences.
    for (0..500) |_| {
        var hs = HighScore{
            .count = 0,
            .scores = undefined,
        };
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
