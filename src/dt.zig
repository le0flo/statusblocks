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

const DaySeconds = std.time.epoch.DaySeconds;
const EpochDay = std.time.epoch.EpochDay;
const EpochSeconds = std.time.epoch.EpochSeconds;
const Month = std.time.epoch.Month;
const MonthAndDay = std.time.epoch.MonthAndDay;
const YearAndDay = std.time.epoch.YearAndDay;

const getDaysInMonth = std.time.epoch.getDaysInMonth;

const Timestamp = std.Io.Timestamp;
const Writer = std.Io.Writer;

// Using italian day names and order
const WeekDay = enum(u3) {
    Lun,
    Mar,
    Mer,
    Gio,
    Ven,
    Sab,
    Dom,

    pub fn numeric(self: WeekDay) u3 {
        return @backingInt(self);
    }

    pub fn fromTimestamp(epoch_s: *EpochSeconds) WeekDay {
        const days = @divFloor(epoch_s.*.secs, std.time.s_per_day);
        return @fromBackingInt(@intCast(@mod(days + 3, 7)));
    }
};

pub fn fmtDateTime(now: *Timestamp, time_writer: *Writer, date_writer: *Writer) !void {
    var epoch_s: EpochSeconds = .{ .secs = @intCast(now.toSeconds() + utcDstSeconds(now)) };
    var ds: DaySeconds = epoch_s.getDaySeconds();

    var epoch_d: EpochDay = epoch_s.getEpochDay();
    var year: YearAndDay = epoch_d.calculateYearDay();
    var month: MonthAndDay = year.calculateMonthDay();

    const week_d: WeekDay = .fromTimestamp(&epoch_s);

    _ = time_writer.consumeAll();
    try time_writer.print("{d:0>2}:{d:0>2}:{d:0>2}", .{
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
        ds.getSecondsIntoMinute(),
    });

    _ = date_writer.consumeAll();
    try date_writer.print("{t} {d:0>4}-{d:0>2}-{d:0>2}", .{
        week_d,
        year.year,
        month.month.numeric(),
        month.day_index,
    });
}

// Using italian (Europe/Rome) utc distance law
pub fn utcDstSeconds(now: *Timestamp) u16 {
    var utc_s: EpochSeconds = .{ .secs = @intCast(now.toSeconds()) };
    var utc_day = utc_s.getEpochDay();
    var utc_year = utc_day.calculateYearDay();
    const utc_year_n = utc_year.year;
    var utc_month = utc_year.calculateMonthDay();
    const utc_month_n = utc_month.month.numeric();

    var dst_h: u16 = 1;
    if (utc_month_n > 3 and utc_month_n < 10) {
        dst_h += 1;
    } else if (utc_month_n == 3 or utc_month_n == 10) {
        const day_last = getDaysInMonth(utc_year_n, utc_month.month);
        const epoch_day_first = utc_day.day - utc_month.day_index;
        const epoch_day_last = epoch_day_first + day_last - 1;
        const weekday: u64 = (epoch_day_last + 3) % 7;
        const sunday = epoch_day_last - epoch_day_first - weekday;

        std.debug.print("{d}\n", .{sunday});

        if (utc_month_n == 3 and utc_month.day_index > sunday) {
            dst_h += 1;
        } else if (utc_month.day_index < sunday) {
            dst_h += 1;
        }
    }

    return dst_h * 3600;
}
