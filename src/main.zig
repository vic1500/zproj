const std = @import("std");

pub fn write(io: std.Io, buf: []u8, text: []const u8, text_args: anytype) !void {
    const std_out = std.Io.File.stdout().writer(io, buf);
    const std_writer = &std_out.interface;

    try std_writer.print(text, text_args);
    try std_writer.flush();
}

pub fn setProjectHome(io: std.Io, env: *std.process.Environ.Map, gpa: std.mem.Allocator, proj_name: []const u8) !void {
    const home_env = env.get("HOME") orelse return error.NoHomeDirectory;
    const home_dir = try std.Io.Dir.openDirAbsolute(io, home_env, .{});
    defer home_dir.close(io);

    const zproj_dir = try home_dir.createDirPathOpen(io, ".config/zproj", .{});
    defer zproj_dir.close(io);

    const zproj_config_file = zproj_dir.openFile(io, "config.txt", .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => try zproj_dir.createFile(io, "config.txt", .{ .read = true }),
        else => return err,
    };
    defer zproj_config_file.close(io);

    const text = try std.mem.concat(gpa, u8, &.{ "project home = ", proj_name });
    defer _ = gpa.free(text);

    try zproj_config_file.setLength(io, 0);
    try zproj_config_file.writePositionalAll(io, text, 0);
}

pub fn openProjectDir(io: std.Io, env: *std.process.Environ.Map, gpa: std.mem.Allocator, proj_name: []const u8) !void {
    const home_env = env.get("HOME") orelse return error.NoHomeDirectory;
    const home_dir = try std.Io.Dir.openDirAbsolute(io, home_env, .{});
    defer home_dir.close(io);

    const zproj_config_file = home_dir.openFile(io, ".config/zproj/config.txt", .{ .mode = .read_only }) catch return error.NoConfigFileFound;
    defer zproj_config_file.close(io);

    var buffer: [1024]u8 = undefined;
    const bytes_read = try zproj_config_file.readPositionalAll(io, &buffer, 0);

    if (bytes_read == 0) return error.EmptyConfigFile;

    const proj_dir = buffer[15..bytes_read];

    const proj_path = try std.mem.concat(gpa, u8, &.{home_env, proj_dir, "/", proj_name });
    defer gpa.free(proj_path);

    try launchNvim(io, proj_path);
}

pub fn launchNvim(io: std.Io, proj_path: []const u8) !void {
    var nvim_process = try std.process.spawn(io, .{
        .argv = &.{ "nvim", proj_path },
        .stdin = .inherit,
        .stderr = .inherit,
        .stdout = .inherit,
        .cwd = .{ .path = proj_path },
    });
    defer nvim_process.kill(io);

    _ = try nvim_process.wait(io);
}

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    const env = init.environ_map;
    const io = init.io;
    const gpa = init.gpa;

    const ArgOptions = union(enum) {
        start: []const u8,
        set_proj_home: []const u8,
    };
    if (args.len < 1) return error.NoArgumentProvided; 

    const arg1 = if (std.mem.eql(u8, args[1], "start")) ArgOptions{ .start = args[1] } else ArgOptions{ .set_proj_home = args[1] };

    switch (arg1) {
        .start => {
            if (args.len < 3) return error.InvalidOption;
            try openProjectDir(io, env, gpa, args[2]);
        },
        .set_proj_home => |val| {
            if (!std.mem.eql(u8, "set-proj-home", val)) return error.InvalidArgumentType;
            if (args.len < 3) return error.InvalidOption;
            try setProjectHome(io, env, gpa, args[2]);
        },
    }

}
