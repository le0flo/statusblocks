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

const enums = std.enums;
const linux = std.os.linux;
const mem = std.mem;

const Writer = std.Io.Writer;

const ParserState = enum(i5) {
    LABEL = -1,
    USER,
    NICE,
    SYSTEM,
    IDLE,
    IOWAIT,
    IRQ,
    SOFTIRQ,
    STEAL,

    pub fn numeric(self: ParserState) usize {
        return @intCast(@backingInt(self));
    }
};

pub fn fmtCpuUsage(writer: *Writer, prev_total: *i64, prev_idle: *i64) !void {
    _ = writer.consumeAll();

    const fd: linux.fd_t = @intCast(linux.open("/proc/stat", .{}, 0));
    if (fd < 0) {
        try writer.print("cannot open /proc/stat", .{});
    } else {
        var state: ParserState = .LABEL;
        var values: [8]i64 = undefined;
        var startReading: bool = false;

        var c: [1]u8 = undefined;
        while (linux.read(@intCast(fd), &c, 1) > 0) {
            if (c[0] == ' ' and mem.eql(u8, "cpu", writer.buffered())) {
                startReading = true;
                _ = writer.consumeAll();
            } else if (c[0] >= 'a' and c[0] <= 'z') {
                _ = try writer.write(&c);
            } else if (c[0] == '\n') {
                _ = writer.consumeAll();
                if (startReading) break;
            } else if (startReading) {
                if (c[0] == ' ' and state != .LABEL and state != .STEAL) {
                    state = @fromBackingInt(@intCast(state.numeric() + 1));
                    values[state.numeric()] = 0;
                } else if (c[0] >= '0' and c[0] <= '9') {
                    switch (state) {
                        .LABEL => {
                            state = .USER;
                            values[state.numeric()] = 0;
                        },
                        else => {
                            values[state.numeric()] = (values[state.numeric()] * 10) + (c[0] - '0');
                        },
                    }
                }
            }
        }
        _ = linux.close(fd);

        var total: i64 = 0;
        var idle: i64 = 0;
        for (enums.values(ParserState)) |i| {
            total += switch (i) {
                .LABEL => 0,
                else => values[i.numeric()],
            };
            idle += switch (i) {
                .IDLE, .IOWAIT => values[i.numeric()],
                else => 0,
            };
        }

        const d_total: i64 = total - prev_total.*;
        const d_idle: i64 = idle - prev_idle.*;

        const f_num: f64 = @floatFromInt(d_total - d_idle);
        const f_den: f64 = @floatFromInt(d_total);

        _ = writer.consumeAll();
        try writer.print("{d:5.1} %", .{100 * (f_num / f_den)});

        prev_total.* = total;
        prev_idle.* = idle;
    }
}
