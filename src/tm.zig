const std = @import("std");

pub fn TuringMachine(n: comptime_int) type {
    return struct {
        const symbol_count = 2;
        const state_count = n + 1;
        const input_count = symbol_count * state_count;
        const initial_tape_size = 256;

        const Direction = enum(u1) {
            left,
            right,
        };

        const Symbol = Storage(symbol_count);
        const State = Storage(state_count);

        const Input = packed struct {
            symbol: Symbol,
            state: State,
        };

        const Output = packed struct {
            direction: Direction,
            symbol: Symbol,
            state: State,
        };

        const Transitions = [8 * @bitSizeOf(Input)]Output;
        const Tape = std.ArrayList(Symbol);

        const Self = @This();

        transitions: Transitions,
        forward_tape: Tape,
        backward_tape: Tape,
        current_input: Input,
        current_index: i64,
        steps: usize,

        pub fn init(ally: std.mem.Allocator, transitions: Transitions) !Self {
            var self = Self{
                .transitions = transitions,
                .forward_tape = try std.ArrayList(Symbol).initCapacity(ally, initial_tape_size / 2),
                .backward_tape = try std.ArrayList(Symbol).initCapacity(ally, initial_tape_size / 2),
                .current_input = Input{
                    .state = 0,
                    .symbol = 0,
                },
                .current_index = 0,
                .steps = 0,
            };

            try self.forward_tape.appendNTimes(0, 2);
            try self.backward_tape.appendNTimes(0, 2);

            return self;
        }

        pub fn from_encoding(ally: std.mem.Allocator, encoding: []const u8) !Self {
            var transitions: Transitions = undefined;
            var index: usize = 0;

            for (0..state_count - 1) |input_state| {
                for (0..symbol_count) |input_symbol| {
                    const symbol: Symbol = switch (encoding[index]) {
                        '0', '_' => 0,
                        '1' => 1,
                        else => return error.InvalidEncoding,
                    };
                    index += 1;

                    const direction: Direction = switch (encoding[index]) {
                        'L', '_' => .left,
                        'R' => .right,
                        else => return error.InvalidEncoding,
                    };
                    index += 1;

                    const state: State = switch (encoding[index]) {
                        'Z', '_' => state_count - 1,
                        'A' => 0,
                        'B' => 1,
                        'C' => 2,
                        'D' => 3,
                        'E' => 4,
                        'F' => 5,
                        'G' => 6,
                        else => return error.InvalidEncoding,
                    };
                    index += 1;

                    const input = Input{
                        .state = @intCast(input_state),
                        .symbol = @intCast(input_symbol),
                    };
                    const output = Output{
                        .direction = direction,
                        .state = state,
                        .symbol = symbol,
                    };

                    const input_index: u8 = @bitCast(input);
                    transitions[@as(usize, input_index)] = output;
                }

                index += 1;
            }

            return try init(ally, transitions);
        }

        pub fn deinit(self: *Self) void {
            self.forward_tape.deinit();
            self.backward_tape.deinit();
        }

        pub fn run(self: *Self) !usize {
            while (try self.step()) {}

            return self.steps;
        }

        pub fn step(self: *Self) !bool {
            if (self.current_input.state == state_count - 1) {
                std.debug.print("Halting after {} steps.\n", .{self.steps});
                return false;
            }

            const input_index: u8 = @bitCast(self.current_input);
            const output = self.transitions[@as(usize, input_index)];

            self.current_input.state = output.state;

            if (self.current_index >= 0) {
                const i: usize = @intCast(self.current_index);
                if (i >= self.forward_tape.items.len) {
                    try self.forward_tape.append(0);
                    try self.forward_tape.append(0);
                }
                self.forward_tape.items[i] = output.symbol;
            } else {
                const i: usize = @intCast(@abs(self.current_index) - 1);
                if (i >= self.backward_tape.items.len) {
                    try self.backward_tape.append(0);
                    try self.backward_tape.append(0);
                }
                self.backward_tape.items[i] = output.symbol;
            }

            if (output.direction == .left) {
                self.current_index -= 1;
            } else {
                self.current_index += 1;
            }

            self.current_index += ((2 * @as(i64, @intFromEnum(output.direction))) - 1);

            if (self.current_index >= 0) {
                const i: usize = @intCast(self.current_index);
                if (i >= self.forward_tape.items.len) {
                    try self.forward_tape.append(0);
                    try self.forward_tape.append(0);
                }
                self.current_input.symbol = self.forward_tape.items[i];
            } else {
                const i: usize = @intCast(@abs(self.current_index) - 1);
                if (i >= self.backward_tape.items.len) {
                    try self.backward_tape.append(0);
                    try self.backward_tape.append(0);
                }
                self.current_input.symbol = self.backward_tape.items[i];
            }

            self.steps += 1;

            return true;
        }
    };
}

pub fn Storage(state_count: comptime_int) type {
    return switch (state_count) {
        @bitSizeOf(u0) => u0,
        (@bitSizeOf(u0) + 1)...@bitSizeOf(u1) => u1,
        (@bitSizeOf(u1) + 1)...@bitSizeOf(u2) => u2,
        (@bitSizeOf(u2) + 1)...@bitSizeOf(u3) => u3,
        (@bitSizeOf(u3) + 1)...@bitSizeOf(u4) => u4,
        (@bitSizeOf(u4) + 1)...@bitSizeOf(u5) => u5,
        (@bitSizeOf(u5) + 1)...@bitSizeOf(u6) => u6,
        (@bitSizeOf(u6) + 1)...@bitSizeOf(u7) => u7,
        (@bitSizeOf(u7) + 1)...@bitSizeOf(u8) => u8,
        else => @compileError("Invalid state count to represent:" ++ state_count),
    };
}

test "BB(5) champion" {
    const t = std.testing;
    const n = 5;
    const encoding = "1RB1LC_1RC1RB_1RD0LE_1LA1LD_1RZ0LA";

    var m = try TuringMachine(n).from_encoding(t.allocator, encoding);
    defer {
        m.deinit();
    }

    const steps = m.run();
    try t.expectEqual(47176870, steps);
}
