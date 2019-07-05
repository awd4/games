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

pub fn rotatePiecesCCW(pieces: u64) u64 {
    const lr: u64 = 1;
    var rotated: u64 = 0;

    var i: u6 = 0;
    while (true) {
        rotated <<= 1;

        var dx: u6 = i % 8;
        var dy: u6 = i / 8;
        var mask: u64 = lr << (56 - dx * 8 + dy);
        var set_piece: bool = (mask & pieces) != 0;

        if (set_piece) {
            rotated ^= 1;
        }

        if (i == 63) {
            break;
        }
        i += 1;
    }
    return rotated;
}

pub fn flipPiecesTB(pieces: u64) u64 {
    const row: u64 = 255;
    var flipped: u64 = 0;

    var i: u6 = 0;
    while (true) {
        flipped <<= 8;

        var mask: u64 = row << (i * 8);
        mask = mask & pieces;
        mask = mask >> (i * 8);
        flipped ^= mask;

        if (i == 7) {
            break;
        }
        i += 1;
    }
    return flipped;
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
    pub fn rotateCCW(self: *Board) void {
        self.blacks = rotatePiecesCCW(self.blacks);
        self.whites = rotatePiecesCCW(self.whites);
    }
    pub fn flipTB(self: *Board) void {
        self.blacks = flipPiecesTB(self.blacks);
        self.whites = flipPiecesTB(self.whites);
    }
    pub fn canonicalize(self: *Board) void {
        var blacks: [8]u64 = undefined;
        var whites: [8]u64 = undefined;
        blacks[0] = self.blacks;
        whites[0] = self.whites;
        blacks[1] = rotatePiecesCCW(blacks[0]);
        whites[1] = rotatePiecesCCW(whites[0]);
        blacks[2] = rotatePiecesCCW(blacks[1]);
        whites[2] = rotatePiecesCCW(whites[1]);
        blacks[3] = rotatePiecesCCW(blacks[2]);
        whites[3] = rotatePiecesCCW(whites[2]);
        blacks[4] = flipPiecesTB(blacks[0]);
        whites[4] = flipPiecesTB(whites[0]);
        blacks[5] = flipPiecesTB(blacks[1]);
        whites[5] = flipPiecesTB(whites[1]);
        blacks[6] = flipPiecesTB(blacks[2]);
        whites[6] = flipPiecesTB(whites[2]);
        blacks[7] = flipPiecesTB(blacks[3]);
        whites[7] = flipPiecesTB(whites[3]);
        var min_index: u32 = 0;
        var i: u32 = 1;
        while (i < 8) {
            if (blacks[i] < blacks[min_index] or
                  (blacks[i] == blacks[min_index] and whites[i] < whites[min_index])) {
                min_index = i;
            }
            i += 1;
        }
        self.blacks = blacks[min_index];
        self.whites = whites[min_index];
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

    states.boards.at(0).blacks |= 7;
    states.boards.at(0).print();
    states.boards.at(0).rotateCCW();
    states.boards.at(0).print();
    states.boards.at(0).flipTB();
    states.boards.at(0).print();

    states.boards.at(0).canonicalize();
    states.boards.at(0).print();
}


