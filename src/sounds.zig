const rl = @import("raylib");
const std = @import("std");

pub const Sounds = struct {
    shoot: rl.Sound,
    enemy_die: rl.Sound,
    player_hit: rl.Sound,
    heartbeat: [4]rl.Sound,
    pub fn init() Sounds {
        return Sounds{
            .shoot = generateShootSound(),
            .enemy_die = generateEnemyDieSound(),
            .player_hit = generatePlayerHitSound(),
            .heartbeat = .{
                generateHeartbeatSound(160),
                generateHeartbeatSound(130),
                generateHeartbeatSound(100),
                generateHeartbeatSound(80),
            },
        };
    }
    pub fn deinit(self: *const Sounds) void {
        rl.unloadSound(self.shoot);
        rl.unloadSound(self.enemy_die);
        rl.unloadSound(self.player_hit);
        for (self.heartbeat) |s| rl.unloadSound(s);
    }
    fn generateEnemyDieSound() rl.Sound {
        const sample_rate = 44100;
        const sample_count = 4410; // 0.1s

        var samples: [sample_count]f32 = undefined;
        var prng: std.Random.DefaultPrng = .init(12345);
        const rand = prng.random();

        for (0..sample_count) |i| {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, sample_rate);
            const envelope = 1.0 - (t / 0.1); // fade out
            samples[i] = (rand.float(f32) * 2.0 - 1.0) * envelope * 0.5;
        }

        const wave = rl.Wave{
            .frameCount = sample_count,
            .sampleRate = sample_rate,
            .sampleSize = 32,
            .channels = 1,
            .data = @ptrCast(&samples),
        };
        return rl.loadSoundFromWave(wave);
    }

    fn generatePlayerHitSound() rl.Sound {
        const sample_rate = 44100;
        const sample_count = 13230; // 0.3s

        var samples: [sample_count]f32 = undefined;
        var prng: std.Random.DefaultPrng = .init(12345);
        const rand = prng.random();

        for (0..sample_count) |i| {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, sample_rate);
            const envelope = 1.0 - (t / 0.3);
            const noise = (rand.float(f32) * 2.0 - 1.0) * envelope * 0.4;
            const freq = 150.0;
            const period = 1.0 / freq;
            const tone = if (@mod(t, period) < period / 2.0) @as(f32, 0.3) else @as(f32, -0.3);
            samples[i] = (noise + tone) * envelope;
        }

        const wave = rl.Wave{
            .frameCount = sample_count,
            .sampleRate = sample_rate,
            .sampleSize = 32,
            .channels = 1,
            .data = @ptrCast(&samples),
        };
        return rl.loadSoundFromWave(wave);
    }

    fn generateHeartbeatSound(freq: f32) rl.Sound {
        const sample_rate = 44100;
        const sample_count = 2205; // 0.05s, short click

        var samples: [2205]f32 = undefined;
        for (0..sample_count) |i| {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, sample_rate);
            const envelope = 1.0 - (t / 0.05);
            samples[i] = @sin(2.0 * std.math.pi * freq * t) * envelope * 0.8;
        }

        const wave = rl.Wave{
            .frameCount = sample_count,
            .sampleRate = sample_rate,
            .sampleSize = 32,
            .channels = 1,
            .data = @ptrCast(&samples),
        };
        return rl.loadSoundFromWave(wave);
    }

    fn generateShootSound() rl.Sound {
        const sample_rate = 44100;
        const duration = 0.1;
        const sample_count = @as(usize, @intFromFloat(sample_rate * duration));

        var samples: [4410]f32 = undefined;
        for (0..sample_count) |i| {
            const t = @as(f32, @floatFromInt(i)) / sample_rate;
            const freq = 800.0 - (t / duration) * 600.0; // descend from 800hz to 200hz
            const period = 1.0 / freq;
            const amplitude = 0.3;
            samples[i] = if (@mod(t, period) < period / 2.0) amplitude else -amplitude;
        }

        const wave = rl.Wave{
            .frameCount = sample_count,
            .sampleRate = sample_rate,
            .sampleSize = 32,
            .channels = 1,
            .data = @ptrCast(&samples),
        };
        return rl.loadSoundFromWave(wave);
    }
};
