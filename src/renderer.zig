const rl = @import("raylib");

pub const Screen = struct {
    pub const w: f32 = 800;
    pub const h: f32 = 600;
    pub const padding: f32 = 8;
};

const Monitor = struct {
    const x: f32 = 190;
    const y: f32 = 70;
    const w: f32 = 420;
    const h: f32 = 305;
};

pub const Renderer = struct {
    render_target: rl.RenderTexture,
    bg_texture: rl.Texture,
    crt_shader: rl.Shader,
    time_loc: i32,

    pub fn init() !Renderer {
        const crt_shader = try rl.loadShader(null, "assets/crt.frag");
        errdefer rl.unloadShader(crt_shader);

        const res_loc = rl.getShaderLocation(crt_shader, "resolution");
        const time_loc = rl.getShaderLocation(crt_shader, "time");

        const res_val = [2]f32{ Screen.w, Screen.h }; // 800, 600 — the actual render target size
        rl.setShaderValue(crt_shader, res_loc, &res_val, rl.ShaderUniformDataType.vec2);
        const render_target = try rl.loadRenderTexture(
            @intFromFloat(Screen.w),
            @intFromFloat(Screen.h),
        );
        errdefer rl.unloadRenderTexture(render_target);

        rl.setTextureFilter(render_target.texture, rl.TextureFilter.point);
        return Renderer{
            .render_target = render_target,
            .bg_texture = try rl.loadTexture("assets/monitor.png"),
            .crt_shader = crt_shader,
            .time_loc = time_loc,
        };
    }

    pub fn deinit(self: *Renderer) void {
        rl.unloadRenderTexture(self.render_target);
        rl.unloadTexture(self.bg_texture);
        rl.unloadShader(self.crt_shader);
    }

    pub fn beginScene(self: *Renderer) void {
        rl.beginTextureMode(self.render_target);
        rl.clearBackground(rl.Color{
            .r = 0,
            .g = 0,
            .b = 0,
            .a = 0,
        });
    }

    pub fn endScene(_: *Renderer) void {
        rl.endTextureMode();
    }

    pub fn composite(self: *Renderer) void {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        // background
        rl.drawTexturePro(
            self.bg_texture,
            rl.Rectangle{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(self.bg_texture.width),
                .height = @floatFromInt(self.bg_texture.height),
            },
            rl.Rectangle{
                .x = 0,
                .y = 0,
                .width = Screen.w,
                .height = Screen.h,
            },
            rl.Vector2{ .x = 0, .y = 0 },
            0,
            rl.Color.white,
        );

        // CRT pass
        const t = @as(f32, @floatCast(rl.getTime()));
        rl.setShaderValue(
            self.crt_shader,
            self.time_loc,
            &t,
            rl.ShaderUniformDataType.float,
        );

        rl.beginBlendMode(rl.BlendMode.alpha);
        rl.beginShaderMode(self.crt_shader);
        rl.drawTexturePro(
            self.render_target.texture,
            rl.Rectangle{
                .x = 0,
                .y = Screen.h,
                .width = Screen.w,
                .height = -Screen.h,
            },
            rl.Rectangle{
                .x = Monitor.x,
                .y = Monitor.y,
                .width = Monitor.w,
                .height = Monitor.h,
            },
            rl.Vector2{
                .x = 0,
                .y = 0,
            },
            0,
            rl.Color.white,
        );
        rl.endShaderMode();
        rl.endBlendMode();
    }
};
