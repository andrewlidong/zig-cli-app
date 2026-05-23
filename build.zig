const Build = @import("std").Build;

pub fn build(b: *Build) void {
    const exe_mod           = b.createModule(.{
        .root_source_file   = b.path("src/main.zig"),
        .target             = b.standardTargetOptions(.{}),
        .optimize           = b.standardOptimizeOption(.{}),
    });

    const exe               = b.addExecutable(.{
        .name               = "babyline",
        .root_module        = exe_mod,
    });

    b.installArtifact(exe);

    const exe_tests         = b.addTest(.{
        .root_module        = exe_mod,
    });

    const run_exe_tests     = b.addRunArtifact(exe_tests);

    const test_step         = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_tests.step);

    const run_docs          = b.addRunArtifact(exe);
    run_docs.addArgs(&.{ "docs", "all" });
    // The docs subcommand writes to ./docs/ relative to the cwd, so run it
    // from the project root rather than the build cache directory.
    run_docs.setCwd(b.path("."));

    const docs_step         = b.step("docs", "Regenerate docs/cli.{md,1,txt}");
    docs_step.dependOn(&run_docs.step);
}
