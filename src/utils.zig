const std = @import("std");

pub fn Pool(comptime T: type, comptime capacity: usize) type {
    return struct {
        items: [capacity]T = undefined,
        count: usize = 0,

        const Self = @This();

        pub fn add(self: *Self, item: T) bool {
            if (self.count >= capacity) return false;
            self.items[self.count] = item;
            self.count += 1;
            return true;
        }

        pub fn remove(self: *Self, i: usize) void {
            self.items[i] = self.items[self.count - 1];
            self.count -= 1;
        }

        pub fn constSlice(self: *const Self) []const T {
            return self.items[0..self.count];
        }

        pub fn hasLessThan(self: *const Self, c: usize) bool {
            return self.count < c;
        }

        pub fn isFull(self: *const Self) bool {
            return self.count >= capacity;
        }
    };
}

pub fn boundedArray(comptime T: type, comptime max: T, comptime values: anytype) @TypeOf(values) {
    for (values) |v| {
        std.debug.assert(v <= max);
    }
    return values;
}
