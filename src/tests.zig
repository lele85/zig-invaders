// Main test entry point. Add one line per `*_test.zig` file so `zig build
// test` picks up its tests.
test {
    _ = @import("highscore_test.zig");
}
