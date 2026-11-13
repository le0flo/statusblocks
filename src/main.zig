// Copyright (C) 2026 leoflo
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");

const cpu = @import("cpu.zig");
const mem = @import("mem.zig");
const dt = @import("dt.zig");

const Init = std.process.Init;

const Clock = std.Io.Clock;
const File = std.Io.File;
const Timestamp = std.Io.Timestamp;
const Writer = std.Io.Writer;

var running: bool = true;

pub fn main(init: Init) !void {
    // Init
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    // CPU usage
    var total: i64 = 0;
    var idle: i64 = 0;
    var cpu_buffer: [256]u8 = undefined;
    var cpu_writer: Writer = .fixed(&cpu_buffer);

    // Memory Usage
    var mem_buffer: [256]u8 = undefined;
    var mem_writer: Writer = .fixed(&mem_buffer);

    // Date & Time
    const clock_real = Clock.real;
    var now: Timestamp = undefined;

    var time_buffer: [256]u8 = undefined;
    var time_writer: Writer = .fixed(&time_buffer);
    var date_buffer: [256]u8 = undefined;
    var date_writer: Writer = .fixed(&date_buffer);

    while (running) {
        now = clock_real.now(io);

        try cpu.fmtCpuUsage(&cpu_writer, &total, &idle);
        try mem.fmtMemUsage(&mem_writer);
        try dt.fmtDateTime(&now, &time_writer, &date_writer);

        try stdout_writer.print("cpu: {s} | ram: {s} | {s}, {s}\n", .{
            cpu_writer.buffered(),
            mem_writer.buffered(),
            date_writer.buffered(),
            time_writer.buffered(),
        });
        try stdout_writer.flush();

        try io.sleep(.fromMilliseconds(100), .awake);
    }
}
