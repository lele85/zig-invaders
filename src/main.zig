const rl = @import("raylib");
const std = @import("std");
const Sounds = @import("sounds.zig").Sounds;
const Renderer = @import("renderer.zig").Renderer;
const Screen = @import("renderer.zig").Screen;
const Pool = @import("utils.zig").Pool;
const boundedArray = @import("utils.zig").boundedArray;

// Level
const level_count = 5;

// Player
const player_w: f32 = 60;
const player_h: f32 = 30;
const player_speed: f32 = 200;

// Bullet
const bullet_w: f32 = 4;
const bullet_h: f32 = 20;
const bullet_speed: f32 = 500;

// Player Bullets
const player_bullet_max = 10;
const player_bullet_max_level = boundedArray(
    usize,
    player_bullet_max,
    [level_count]usize{ 10, 6, 3, 2, 1 },
);

// Enemy
const enemy_w: f32 = 32;
const enemy_h: f32 = 32;
const enemy_start_y: f32 = 80;
const enemy_padding: f32 = 12;
const enemy_cols = 11;
const enemy_rows = 5;
const enemy_max = enemy_cols * enemy_rows;
const enemy_bullet_max = 6;
const enemy_bullet_speed: f32 = 250;
const enemy_shoot_min: f32 = 0.3;
const enemy_shoot_max: f32 = 1;
const enemy_step_size: f32 = 24;
const enemy_step_down: f32 = enemy_h + enemy_padding; // how much they drop when hitting a wall

// Enemy movement
const heartbeat_min: f32 = 0.2; // fastest speed, late game
const heartbeat_range: f32 = 0.8; // how much slower at start

const Typography = struct {
    size: f32,
    line: f32,
};

const typo = struct {
    const base = Typography{ .size = 28, .line = 36 };
    const xxl = Typography{ .size = 56, .line = 64 };
};

const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

const Player = struct {
    rect: Rect,
    speed: f32,
    lives: usize,
    bullets: Pool(Bullet, player_bullet_max),
};

const Bullet = struct {
    rect: Rect,
    speed: f32,
};

const Enemies = struct {
    x: [enemy_max]f32 = undefined,
    y: [enemy_max]f32 = undefined,
    col: [enemy_max]u8 = undefined,
    count: usize = 0,
    direction: f32 = 1.0,
    bullets: Pool(Bullet, enemy_bullet_max) = .{},
    shoot_timer: f32 = 0,
    heartbeat_index: usize = 0,
    heartbeat_timer: f32 = 0,

    fn kill(self: *Enemies, i: usize) void {
        self.x[i] = self.x[self.count - 1];
        self.y[i] = self.y[self.count - 1];
        self.col[i] = self.col[self.count - 1];
        self.count -= 1;
    }

    fn init(rand: std.Random) Enemies {
        var g: Enemies = .{};
        g.shoot_timer = enemy_shoot_min + rand.float(f32) * (enemy_shoot_max - enemy_shoot_min);
        for (0..enemy_max) |i| {
            const c: u8 = @intCast(i % enemy_cols);
            const r: u8 = @intCast(i / enemy_cols);
            g.x[i] = Screen.padding + @as(f32, @floatFromInt(c)) * (enemy_padding + enemy_w);
            g.y[i] = enemy_start_y + @as(f32, @floatFromInt(r)) * (enemy_padding + enemy_h);
            g.col[i] = c;
            g.count += 1;
        }
        return g;
    }
};

const PlayingState = struct {
    player: Player,
    enemies: Enemies,
    score: usize,
    level: usize,
    fn init(rand: std.Random, level: usize, score: usize, lives: usize) PlayingState {
        return PlayingState{
            .level = level,
            .player = Player{
                .rect = Rect{
                    .x = (Screen.w - player_w) / 2,
                    .y = Screen.h - (player_h + Screen.padding),
                    .width = player_w,
                    .height = player_h,
                },
                .speed = player_speed,
                .lives = lives,
                .bullets = .{},
            },
            .enemies = Enemies.init(rand),
            .score = score,
        };
    }
};

const LevelData = struct {
    level: usize,
    score: usize,
    lives: usize,
};

const Scene = union(enum) {
    menu,
    level: LevelData,
    playing: PlayingState,
    game_over,
    win,
    high_score,
};

fn pointsForY(y: f32) usize {
    if (y < enemy_start_y + (enemy_h + enemy_padding) * 1) return 30;
    if (y < enemy_start_y + (enemy_h + enemy_padding) * 3) return 20;
    return 10;
}

fn updatePlayer(state: *PlayingState, dt: f32) void {
    // Player Movement
    if (rl.isKeyDown(rl.KeyboardKey.right)) {
        state.player.rect.x += state.player.speed * dt;
    }
    if (rl.isKeyDown(rl.KeyboardKey.left)) {
        state.player.rect.x -= state.player.speed * dt;
    }

    // Player Level Bounds
    state.player.rect.x = std.math.clamp(
        state.player.rect.x,
        Screen.padding,
        Screen.w - Screen.padding - state.player.rect.width,
    );
}

fn updatePlayerBullets(state: *PlayingState, dt: f32, sounds: Sounds) void {
    // Bullet spawn
    if (state.player.bullets.hasLessThan(player_bullet_max_level[state.level])) {
        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            _ = state.player.bullets.add(Bullet{
                .rect = Rect{
                    .x = state.player.rect.x + (state.player.rect.width / 2) - (bullet_w / 2),
                    .y = state.player.rect.y - (bullet_h / 2),
                    .width = bullet_w,
                    .height = bullet_h,
                },
                .speed = bullet_speed,
            });
            rl.playSound(sounds.shoot);
        }
    }

    // Bullet move and despawn
    var i: usize = 0;
    while (i < state.player.bullets.count) {
        state.player.bullets.items[i].rect.y -= state.player.bullets.items[i].speed * dt;
        if (state.player.bullets.items[i].rect.y < 0) {
            state.player.bullets.remove(i);
        } else {
            i += 1;
        }
    }
}

fn updateEnemyBullets(state: *PlayingState, dt: f32, rand: std.Random) void {
    state.enemies.shoot_timer -= dt;

    var i: usize = 0;
    while (i < state.enemies.bullets.count) {
        state.enemies.bullets.items[i].rect.y += state.enemies.bullets.items[i].speed * dt;
        if (state.enemies.bullets.items[i].rect.y > Screen.h - Screen.padding - bullet_h) {
            state.enemies.bullets.remove(i);
        } else {
            i += 1;
        }
    }

    if (state.enemies.shoot_timer > 0) return;

    const g = &state.enemies;

    // find bottommost enemy per column
    var bottom_y: [enemy_cols]f32 = [_]f32{-1} ** enemy_cols;
    var bottom_idx: [enemy_cols]usize = undefined;

    for (0..g.count) |idx| {
        const c = g.col[idx];
        if (g.y[idx] > bottom_y[c]) {
            bottom_y[c] = g.y[idx];
            bottom_idx[c] = idx;
        }
    }

    // collect valid columns
    var shooters: [enemy_cols]usize = undefined;
    var shooter_count: usize = 0;
    for (0..enemy_cols) |c| {
        if (bottom_y[c] >= 0) {
            shooters[shooter_count] = bottom_idx[c];
            shooter_count += 1;
        }
    }

    if (shooter_count == 0) return;

    // spawn enemy bullet
    const pick = shooters[rand.intRangeLessThan(usize, 0, shooter_count)];
    if (!state.enemies.bullets.isFull()) {
        _ = state.enemies.bullets.add(Bullet{
            .rect = .{
                .x = g.x[pick] + (enemy_w / 2) - (bullet_w / 2),
                .y = g.y[pick] + enemy_h,
                .width = bullet_w,
                .height = bullet_h,
            },
            .speed = enemy_bullet_speed,
        });
    }

    state.enemies.shoot_timer = enemy_shoot_min + rand.float(f32) * (enemy_shoot_max - enemy_shoot_min);
}

fn updateCollisions(state: *PlayingState, sounds: Sounds) void {
    const g = &state.enemies;

    // enemy hit by player bullet
    var i: usize = 0;
    while (i < state.player.bullets.count) {
        var hit = false;
        var e: usize = 0;
        while (e < g.count) {
            const enemy_rect = Rect{
                .x = g.x[e],
                .y = g.y[e],
                .width = enemy_w,
                .height = enemy_h,
            };
            if (checkCollision(&state.player.bullets.items[i].rect, &enemy_rect)) {
                state.score += pointsForY(g.y[e]);
                state.enemies.kill(e);
                state.player.bullets.remove(i);
                rl.playSound(sounds.enemy_die);
                hit = true;
                break;
            }
            e += 1;
        }
        if (!hit) i += 1;
    }

    // player hit by enemy bullet
    var j: usize = 0;
    while (j < state.enemies.bullets.count) {
        if (checkCollision(&state.player.rect, &state.enemies.bullets.items[j].rect)) {
            state.enemies.bullets.remove(j);
            rl.playSound(sounds.player_hit);
            if (state.player.lives > 0) state.player.lives -= 1;
        } else {
            j += 1;
        }
    }
}

fn updateEnemies(state: *PlayingState, stepped: bool) void {
    if (!stepped) return;
    const g = &state.enemies;

    var min_x: f32 = std.math.floatMax(f32);
    var max_x: f32 = 0;

    for (0..g.count) |i| {
        g.x[i] += enemy_step_size * state.enemies.direction;
        if (g.x[i] < min_x) min_x = g.x[i];
        if (g.x[i] + enemy_w > max_x) max_x = g.x[i] + enemy_w;
    }

    const right_boundary = Screen.w - Screen.padding;
    if (max_x > right_boundary) {
        for (0..g.count) |i| {
            g.x[i] -= max_x - right_boundary;
            g.y[i] += enemy_step_down;
        }
        state.enemies.direction = -1;
    } else if (min_x < Screen.padding) {
        for (0..g.count) |i| {
            g.x[i] += Screen.padding - min_x;
            g.y[i] += enemy_step_down;
        }
        state.enemies.direction = 1;
    }
}

fn updateHeartbeat(state: *PlayingState, dt: f32, sounds: Sounds) bool {
    state.enemies.heartbeat_timer -= dt;
    if (state.enemies.heartbeat_timer <= 0) {
        rl.playSound(sounds.heartbeat[state.enemies.heartbeat_index]);
        state.enemies.heartbeat_index = (state.enemies.heartbeat_index + 1) % 4;

        const t = @as(f32, @floatFromInt(state.enemies.count)) / @as(f32, @floatFromInt(enemy_max));
        const t_curved = t * t; // stays slow longer then ramps fast at the end
        state.enemies.heartbeat_timer = heartbeat_min + t_curved * heartbeat_range;
        return true;
    }
    return false;
}

fn drawPlayer(state: *const PlayingState) void {
    // Player Draw
    rl.drawRectangle(
        @intFromFloat(state.player.rect.x),
        @intFromFloat(state.player.rect.y),
        @intFromFloat(state.player.rect.width),
        @intFromFloat(state.player.rect.height),
        rl.Color.green,
    );
}

fn drawPlayerBullets(state: *const PlayingState) void {
    // Bullet Draw
    for (state.player.bullets.constSlice()) |bullet| {
        rl.drawRectangle(
            @intFromFloat(bullet.rect.x),
            @intFromFloat(bullet.rect.y),
            @intFromFloat(bullet.rect.width),
            @intFromFloat(bullet.rect.height),
            rl.Color.green,
        );
    }
}

fn drawEnemyBullets(state: *const PlayingState) void {
    // Bullet Draw
    for (state.enemies.bullets.constSlice()) |bullet| {
        rl.drawRectangle(
            @intFromFloat(bullet.rect.x),
            @intFromFloat(bullet.rect.y),
            @intFromFloat(bullet.rect.width),
            @intFromFloat(bullet.rect.height),
            rl.Color.green,
        );
    }
}

fn drawEnemies(state: *const PlayingState) void {
    const g = &state.enemies;
    for (0..g.count) |i| {
        rl.drawRectangle(
            @intFromFloat(g.x[i]),
            @intFromFloat(g.y[i]),
            @intFromFloat(enemy_w),
            @intFromFloat(enemy_h),
            rl.Color.green,
        );
    }
}

fn drawHUD(state: *const PlayingState, font: *const rl.Font) void {
    rl.drawTextEx(
        font.*,
        rl.textFormat("Score: %d", .{state.score}),
        rl.Vector2{ .x = Screen.padding, .y = Screen.padding },
        typo.base.size,
        4,
        rl.Color.green,
    );
    rl.drawTextEx(
        font.*,
        rl.textFormat("Lives: %d", .{state.player.lives}),
        rl.Vector2{ .x = Screen.padding, .y = Screen.padding + typo.base.line },
        typo.base.size,
        4,
        rl.Color.green,
    );
}

fn getCenter(text: [:0]const u8, font: *const rl.Font) rl.Vector2 {
    const measured = rl.measureTextEx(
        font.*,
        text,
        typo.base.size,
        4,
    );
    return .{
        .x = (Screen.w - measured.x) / 2,
        .y = (Screen.h - measured.y) / 2,
    };
}

fn drawHighScore(font: *const rl.Font) void {
    const text =
        \\+---------+-------+-------+
        \\| Level   | Score | Lives |
        \\+---------+-------+-------+
        \\| 1       |  9999 |     3 |
        \\| 2       |  8000 |     2 |
        \\| 3       |  7500 |     2 |
        \\| 4       |  6200 |     1 |
        \\| 5       |  5100 |     1 |
        \\| 6       |  4800 |     1 |
        \\| 7       |  3300 |     0 |
        \\| 8       |  2100 |     0 |
        \\| 9       |  1500 |     0 |
        \\| 10      |   900 |     0 |
        \\+---------+-------+-------+
    ;
    rl.drawTextEx(
        font.*,
        text,
        getCenter(text, font),
        typo.base.size,
        4,
        rl.Color.green,
    );
}

fn drawStaticScreen(
    title: [:0]const u8,
    subtitle: [:0]const u8,
    font: *const rl.Font,
) void {
    // center title
    const title_w = rl.measureTextEx(
        font.*,
        title,
        typo.xxl.size,
        4,
    ).x;
    const subtitle_w = rl.measureTextEx(
        font.*,
        subtitle,
        typo.base.size,
        4,
    ).x;

    const block_h = typo.xxl.line + typo.base.line;
    const block_y = (Screen.h - block_h) / 2;

    rl.drawTextEx(
        font.*,
        title,
        rl.Vector2{
            .x = (Screen.w - title_w) / 2,
            .y = block_y,
        },
        typo.xxl.size,
        4,
        rl.Color.green,
    );
    rl.drawTextEx(
        font.*,
        subtitle,
        rl.Vector2{
            .x = (Screen.w - subtitle_w) / 2,
            .y = block_y + typo.xxl.line,
        },
        typo.base.size,
        4,
        rl.Color.green,
    );
}

fn checkCollision(a: *const Rect, b: *const Rect) bool {
    // they don't overlap if any of these are true
    if (a.x > b.x + b.width) return false;
    if (a.x + a.width < b.x) return false;
    if (a.y > b.y + b.height) return false;
    if (a.y + a.height < b.y) return false;
    // none were true → they overlap
    return true;
}

pub fn main(init: std.process.Init) !void {
    var prng: std.Random.DefaultPrng = .init(blk: {
        var seed: u64 = undefined;
        init.io.random(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    var scene: Scene = .menu;

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    const sounds = Sounds.init();
    defer sounds.deinit();

    rl.setConfigFlags(rl.ConfigFlags{ .window_highdpi = false });
    rl.initWindow(
        Screen.w,
        Screen.h,
        "Zig Invaders",
    );
    defer rl.closeWindow();

    const font = try rl.loadFont("assets/font.ttf");
    defer rl.unloadFont(font);

    rl.setTargetFPS(60);

    var renderer = try Renderer.init();
    defer renderer.deinit();

    while (!rl.windowShouldClose()) {
        switch (scene) {
            .menu => {
                if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
                    scene = .{ .level = .{
                        .level = 0,
                        .score = 0,
                        .lives = 3,
                    } };
                }
            },
            .level => |level_data| {
                if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
                    scene = .{ .playing = PlayingState.init(
                        rand,
                        level_data.level,
                        level_data.score,
                        level_data.lives,
                    ) };
                }
            },
            .playing => |*ps| {
                var invaded = false;
                for (0..ps.enemies.count) |i| {
                    if (ps.enemies.y[i] + enemy_h >= ps.player.rect.y) {
                        invaded = true;
                        break;
                    }
                }
                if (invaded or ps.player.lives == 0) {
                    scene = .game_over;
                    continue;
                }

                if (ps.enemies.count == 0 and ps.level + 1 < level_count) {
                    const next_level = ps.level + 1;
                    const carry_score = ps.score;
                    const carry_lives = ps.player.lives;
                    scene = .{ .level = .{
                        .level = next_level,
                        .lives = carry_lives,
                        .score = carry_score,
                    } };
                    continue;
                }
                if (ps.enemies.count == 0) {
                    scene = .win;
                    continue;
                }
                const dt = rl.getFrameTime();
                updatePlayer(ps, dt);
                updatePlayerBullets(ps, dt, sounds);
                updateEnemyBullets(ps, dt, rand);
                updateCollisions(ps, sounds);
                const stepped = updateHeartbeat(ps, dt, sounds);
                updateEnemies(ps, stepped);
            },
            .game_over, .win => {
                if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
                    scene = .{ .level = .{
                        .level = 0,
                        .score = 0,
                        .lives = 3,
                    } };
                }
            },
            .high_score => {},
        }

        renderer.beginScene();
        switch (scene) {
            .menu => {
                drawStaticScreen(
                    "ZIG INVADERS",
                    "Press Enter to START",
                    &font,
                );
            },
            .level => |level_data| {
                const next_level = level_data.level + 1;
                drawStaticScreen(
                    rl.textFormat("Level %d", .{next_level}),
                    "Press Enter to START",
                    &font,
                );
            },
            .playing => |*ps| {
                drawPlayer(ps);
                drawPlayerBullets(ps);
                drawEnemies(ps);
                drawEnemyBullets(ps);
                drawHUD(ps, &font);
            },
            .game_over => {
                drawStaticScreen(
                    "GAME OVER",
                    "Press Enter to RESTART",
                    &font,
                );
            },
            .win => {
                drawStaticScreen(
                    "YOU WIN",
                    "Press Enter to RESTART",
                    &font,
                );
            },
            .high_score => {
                drawHighScore(&font);
            },
        }
        renderer.endScene();
        renderer.composite();
    }
}
