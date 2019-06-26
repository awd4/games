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

const left_bit: u64 = 0x8000000000000000;
const right_col: u64 = 72340172838076673; 
const left_col: u64 = 9259542123273814144;
const not_right_col: u64 = 18374403900871474942;
const not_left_col: u64 = 9187201950435737471;

pub fn printBoard(blacks: u64, whites: u64) void {
    warn(top_bot_mark);
    var i: u6 = 0;
    var c: u6 = 0;
    while (true) {
        c = i % 8;
        if (c == 0) {
            warn(side_mark);
        }
        if ((blacks << i) & left_bit != 0) {
            warn(black_mark);
        }
        else if ((whites << i) & left_bit != 0) {
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
        printBoard(self.blacks, self.whites);
    }
};

const BoardList = SegmentedList(Board, 1024);
const TurnList = SegmentedList(Player, 1024);

const States = struct {
    boards: BoardList,
    turns: TurnList,
};

pub fn addChildBoards(states: *States, index: u32) u32 {
    var up_moves: u64 = undefined;
    var dn_moves: u64 = undefined;
    var lf_moves: u64 = undefined;
    var rt_moves: u64 = undefined;
    var ur_moves: u64 = undefined;
    var ul_moves: u64 = undefined;
    var dr_moves: u64 = undefined;
    var dl_moves: u64 = undefined;
    var moves: u64 = undefined;

    var mv: u64 = undefined;
    var flip: u64 = undefined;
    var tmp: u64 = undefined;
    var c1_mv: u64 = undefined;
    var c2_mv: u64 = undefined;
    var c2_run: u64 = undefined;

    var board: *Board = states.boards.at(index);
    var turn: Player = states.turns.at(index).*;

    var e: u64 = board.empties();
    var b: u64 = board.blacks;
    var w: u64 = board.whites;

    var c1: u64 = if (turn == Player.Black) b else w;
    var c2: u64 = if (turn == Player.Black) w else b;

    c1_mv = (c1 << 56);
    c2_mv = (c2 << 48);
    up_moves = c2_mv & c1_mv;
    for ([5]u6{5, 4, 3, 2, 1}) |i| {
        c1_mv = (c1 << (8 *% (i +% 1)));
        c2_mv = (c2 << (8 *% i ));
        up_moves = c2_mv & (c1_mv | up_moves);
    }
    up_moves = up_moves & e;

    c1_mv = (c1 << 56);
    c2_mv = (c2 << 48);
    dn_moves = c2_mv & c1_mv;
    for ([5]u6{5, 4, 3, 2, 1}) |i| {
        c1_mv = (c1 >> (8 *% (i +% 1)));
        c2_mv = (c2 >> (8 *% i ));
        dn_moves = c2_mv & (c1_mv | dn_moves);
    }
    dn_moves = dn_moves & e;

    warn("up moves:\n");
    printBoard(0, up_moves);
    warn("dn moves:\n");
    printBoard(0, dn_moves);

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


