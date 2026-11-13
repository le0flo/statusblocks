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

const linux = std.os.linux;
const mem = std.mem;

const Writer = std.Io.Writer;

const ParserState = enum {
    LABEL,
    VALUE_TOTAL,
    VALUE_AVAILABLE,
    VALUE_IGNORE,
    UNIT,
};

pub fn fmtMemUsage(writer: *Writer) !void {
    _ = writer.consumeAll();

    const fd: linux.fd_t = @intCast(linux.open("/proc/meminfo", .{}, 0));
    if (fd < 0) {
        try writer.print("cannot open /proc/meminfo", .{});
    } else {
        var state: ParserState = .LABEL;
        var mem_total: u32 = 0;
        var mem_available: u32 = 0;
        var filled_total: bool = false;
        var filled_available: bool = false;

        var c: [1]u8 = undefined;
        while (linux.read(@intCast(fd), &c, 1) > 0) {
            switch (state) {
                .LABEL => blk: {
                    if (c[0] == ':') {
                        if (mem.eql(u8, "MemTotal", writer.buffered())) {
                            state = .VALUE_TOTAL;
                            mem_total = 0;
                        } else if (mem.eql(u8, "MemAvailable", writer.buffered())) {
                            state = .VALUE_AVAILABLE;
                            mem_available = 0;
                        } else {
                            state = .VALUE_IGNORE;
                        }

                        _ = writer.consumeAll();
                    } else {
                        _ = try writer.write(&c);
                    }
                    break :blk;
                },

                .VALUE_TOTAL, .VALUE_AVAILABLE, .VALUE_IGNORE => blk: {
                    if (c[0] >= '0' and c[0] <= '9') {
                        _ = try writer.write(&c);
                        if (state == .VALUE_TOTAL) {
                            mem_total = (mem_total * 10) + (c[0] - '0');
                        } else if (state == .VALUE_AVAILABLE) {
                            mem_available = (mem_available * 10) + (c[0] - '0');
                        }
                    } else if (writer.end > 0) {
                        filled_total = (state == .VALUE_TOTAL) or filled_total;
                        filled_available = (state == .VALUE_AVAILABLE) or filled_available;
                        state = .UNIT;
                        _ = writer.consumeAll();
                    }
                    break :blk;
                },

                .UNIT => blk: {
                    // TODO: for now we assume every /proc/meminfo measures memory in kB
                    if (c[0] == '\n') {
                        state = .LABEL;
                    }
                    break :blk;
                },
            }
            if (state == .LABEL and filled_total and filled_available) break;
        }
        _ = linux.close(fd);

        _ = writer.consumeAll();
        try writer.print("{d:6} / {d} MB", .{ mem_available / 1024, mem_total / 1024 });
    }
}
