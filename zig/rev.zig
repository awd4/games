const warn = @import("std").debug.warn;
const DirectAllocator = @import("std").heap.DirectAllocator;
const SegmentedList = @import("std").SegmentedList;

const side_mark = "|";
const top_bot_mark = "-----------------\n";
const empty_mark = " ";
const black_mark = "#";
const white_mark = "o";

const opening_blacks: u64 = 34628173824;
const opening_whites: u64 = 68853694464;

const right_col: u64 = 72340172838076673; 
const left_col: u64 = 9259542123273814144;
const not_right_col: u64 = 18374403900871474942;
const not_left_col: u64 = 9187201950435737471;

const Player = enum(u1) {
    Black,
    White,
};

const Board = struct {
    blacks: u64,
    whites: u64,
    pub fn empties(self: Board) u64 {
        return ~(self.blacks | self.whites);
    }
    pub fn print(self: Board) void {
        warn(top_bot_mark);
        var i: u6 = 0;
        var c: u6 = 0;
        while (true) {
            c = i % 8;
            if (c == 0) {
                warn(side_mark);
            }
            if ((self.blacks >> i) % 2 == 1) {
                warn(black_mark);
            }
            else if ((self.whites >> i) % 2 == 1) {
                warn(white_mark);
            }
            else {
                warn(empty_mark);
            }
            if (c == 7) {
                warn("|\n");
            }
            else {
                warn(empty_mark);
            }
            if (i == 63) {
                break;
            }
            i += 1;
        }
        warn(top_bot_mark);
    }
};

const BoardList = SegmentedList(Board, 1024);
const TurnList = SegmentedList(Player, 1024);

const States = struct {
    boards: BoardList,
    turns: TurnList,
};

pub fn addChildBoards(states: *States, index: u32) u32 {
    var board = states.boards.at(index);
    var turn = states.turns.at(index);

    var e: u64 = board.empties();
    var b: u64 = board.blacks;
    var w: u64 = board.whites;

    //TODO

    var next_board = states.boards.addOne();
    var next_turn = states.turns.addOne();

    return index;
}


pub fn main() !void {
    const opening_board = Board {
        .blacks = opening_blacks,
        .whites = opening_whites,
    };

    var da = DirectAllocator.init();
    defer da.deinit();

    var states = States {
        .boards = BoardList.init(&da.allocator),
        .turns = TurnList.init(&da.allocator),
    };
    defer states.boards.deinit();
    defer states.turns.deinit();

    try states.boards.push(opening_board);
    try states.turns.push(Player.White);

    var index: u32 = 0;
    var next = addChildBoards(&states, index);

    states.boards.at(0).print();
    warn("{}\n", next);
}


