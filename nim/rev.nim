import os

const
  side_mark = "|"
  top_bot_mark = "-----------------"
  empty_mark = " "
  black_mark = "#"
  white_mark = "o"

let
  opening_blacks = 34628173824'u64
  opening_whites = 68853694464'u64

  left_bit = 0x8000000000000000'u64
  right_col = 72340172838076673'u64
  left_col = 9259542123273814144'u64
  not_right_col = 18374403900871474942'u64
  not_left_col = 9187201950435737471'u64

type
  Turn = enum
    Black
    White

  Board = object
    blacks: uint64
    whites: uint64

  States = object
    boards: seq[Board]
    turns: seq[Turn]


proc printBoard(blacks: uint64, whites: uint64) =
  echo top_bot_mark
  for i in 0..<64:
    var c = i mod 8
    if c == 0:
      stdout.write(side_mark)
    if ((blacks shl i) and left_bit) != 0:
      stdout.write(black_mark)
    elif ((whites shl i) and left_bit) != 0:
      stdout.write(white_mark)
    else:
      stdout.write(empty_mark)
    if c == 7:
      echo "|"
    else:
      stdout.write(empty_mark)
  echo top_bot_mark

proc rotatePiecesCCW(pieces: uint64): uint64 =
  let lr: uint64 = 1;
  var rotated: uint64 = 0;

  for i in 0..<64:
    rotated = rotated shl 1;

    var dx: int = i mod 8;
    var dy: int = i div 8;
    var mask: uint64 = lr shl (56 - dx * 8 + dy);
    var set_piece: bool = (mask and pieces) != 0;

    if (set_piece):
      rotated = rotated xor 1;

  return rotated

proc flipPiecesTB(pieces: uint64): uint64 =
  let row: uint64 = 255;
  var flipped: uint64 = 0;

  for i in 0..<64:
    flipped = flipped shl 8

    var mask: uint64 = row shl (i * 8)
    mask = mask and pieces
    mask = mask shr (i * 8)

    flipped = flipped xor mask

  return flipped

proc canonicalPieces(blacks: uint64, whites: uint64, canon_blacks: var uint64, canon_whites: var uint64) =
  var blacks_tfm: array[0..7, uint64]
  var whites_tfm: array[0..7, uint64]
  blacks_tfm[0] = blacks
  blacks_tfm[1] = rotatePiecesCCW(blacks_tfm[0])
  blacks_tfm[2] = rotatePiecesCCW(blacks_tfm[1])
  blacks_tfm[3] = rotatePiecesCCW(blacks_tfm[2])
  blacks_tfm[4] = flipPiecesTB(blacks_tfm[0])
  blacks_tfm[5] = flipPiecesTB(blacks_tfm[1])
  blacks_tfm[6] = flipPiecesTB(blacks_tfm[2])
  blacks_tfm[7] = flipPiecesTB(blacks_tfm[3])
  whites_tfm[0] = whites
  whites_tfm[1] = rotatePiecesCCW(whites_tfm[0])
  whites_tfm[2] = rotatePiecesCCW(whites_tfm[1])
  whites_tfm[3] = rotatePiecesCCW(whites_tfm[2])
  whites_tfm[4] = flipPiecesTB(whites_tfm[0])
  whites_tfm[5] = flipPiecesTB(whites_tfm[1])
  whites_tfm[6] = flipPiecesTB(whites_tfm[2])
  whites_tfm[7] = flipPiecesTB(whites_tfm[3])
  var min_index = 0
  for i in 0..<8:
    var blacks_lower: bool = blacks_tfm[i] < blacks_tfm[min_index]
    var blacks_equal: bool = blacks_tfm[i] == blacks_tfm[min_index]
    var whites_lower: bool = whites_tfm[i] < whites_tfm[min_index]
    if blacks_lower or (blacks_equal and whites_lower):
      min_index = i

  canon_blacks = blacks_tfm[min_index]
  canon_whites = whites_tfm[min_index]

proc print(board: Board) =
  printBoard(board.blacks, board.whites)

proc empties(board: Board): uint64 =
  return not(board.blacks or board.whites)

proc rotateCCW(board: var Board) =
  board.blacks = rotatePiecesCCW(board.blacks)
  board.whites = rotatePiecesCCW(board.whites)

proc flipTB(board: var Board) =
  board.blacks = flipPiecesTB(board.blacks)
  board.whites = flipPiecesTB(board.whites)

proc canonical(board: var Board) =
  canonicalPieces(board.blacks, board.whites, board.blacks, board.whites)




var states: States;
states.boards.add(Board(blacks: opening_blacks, whites: opening_whites))

printBoard(17, 64)
states.boards[0].print()
states.boards[0].rotateCCW()
states.boards[0].print()
states.boards[0].flipTB()
states.boards[0].print()
states.boards[0].canonical()
states.boards[0].print()


