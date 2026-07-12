const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.
    const raylib_dep = b.dependency("raylib_zig", .{ .target = target, .optimize = optimize });
    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function. While we could add a main function
    // to the module defined above, it's sometimes preferable to split business
    // logic and the CLI into two separate modules.
    //
    // If your goal is to create a Zig library for others to use, consider if
    // it might benefit from also exposing a CLI tool. A parser library for a
    // data serialization format could also bundle a CLI syntax checker, for example.
    //
    // If instead your goal is to create an executable, consider if users might
    // be interested in also being able to embed the core functionality of your
    // program in their own executable in order to avoid the overhead involved in
    // subprocessing your CLI tool.
    //
    // If neither case applies to you, feel free to delete the declaration you
    // don't need and to put everything under a single module.
    const exe = b.addExecutable(.{
        .name = "zig_invaders",
        .root_module = b.createModule(.{
            // b.createModule defines a new module just like b.addModule but,
            // unlike b.addModule, it does not expose the module to consumers of
            // this package, which is why in this case we don't have to give it a name.
            .root_source_file = b.path("src/main.zig"),
            // Target and optimization levels must be explicitly wired in when
            // defining an executable or library (in the root module), and you
            // can also hardcode a specific target for an executable or library
            // definition if desireable (e.g. firmware for embedded devices).
            .target = target,
            .optimize = optimize,
            // List of modules available for import in source files part of the
            // root module.
            .imports = &.{
                // Here "zig_invaders" is the name you will use in your source code to
                // import this module (e.g. `@import("zig_invaders")`). The name is
                // repeated because you are allowed to rename your imports, which
                // can be extremely useful in case of collisions (which can happen
                // importing modules from different packages).
                .{
                    .name = "raylib",
                    .module = raylib,
                },
            },
        }),
    });

    exe.root_module.linkLibrary(raylib_artifact);
    exe.subsystem = .Windows;

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.

    // Unit tests. All test files are aggregated into src/tests.zig and built
    // as a single test executable, so `zig build test` (and the resulting
    // zig-out/bin/tests binary) runs everything in one place.
    const test_step = b.step("test", "Run unit tests");

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    // Installing the test binary means `zig build` also leaves a runnable
    // executable behind (zig-out/bin/tests) instead of only the ephemeral
    // cache artifact `addRunArtifact` would use.
    const install_tests = b.addInstallArtifact(tests, .{
        .dest_sub_path = "tests",
    });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&install_tests.step);

    // macOS .app bundle step
    const bundle_step = b.step("bundle", "Create macOS .app bundle");

    const make_bundle = b.addSystemCommand(&.{
        "sh", "-c",
        \\mkdir -p dist/ZigInvaders.app/Contents/MacOS &&
        \\cp zig-out/bin/zig_invaders dist/ZigInvaders.app/Contents/MacOS/ &&
        \\cp -r assets dist/ZigInvaders.app/Contents/MacOS/ &&
        \\mkdir -p dist/ZigInvaders.app/Contents/Resources &&
        \\cp assets/icon.icns dist/ZigInvaders.app/Contents/Resources/ &&
        \\cat > dist/ZigInvaders.app/Contents/MacOS/launch.sh << 'LAUNCH'
        \\#!/bin/bash
        \\cd "$(dirname "$0")"
        \\exec ./zig_invaders
        \\LAUNCH
        \\chmod +x dist/ZigInvaders.app/Contents/MacOS/launch.sh &&
        \\cat > dist/ZigInvaders.app/Contents/Info.plist << 'EOF'
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        \\<plist version="1.0">
        \\<dict>
        \\    <key>CFBundleExecutable</key>
        \\    <string>launch.sh</string>
        \\    <key>CFBundleName</key>
        \\    <string>Zig Invaders</string>
        \\    <key>CFBundleIdentifier</key>
        \\    <string>com.ziginvaders</string>
        \\    <key>CFBundleIconFile</key>
        \\    <string>icon</string>
        \\    <key>LSUIElement</key>
        \\    <false/>
        \\</dict>
        \\</plist>
        \\EOF
    });

    make_bundle.step.dependOn(b.getInstallStep());
    bundle_step.dependOn(&make_bundle.step);
}
