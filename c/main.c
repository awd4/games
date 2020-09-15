#include "board.h"

#include <stdio.h>

int main(int argc, char** argv) {
  printf("Hello, world!\n");

  Board board;
  board.blacks = OPENING_BLACKS;
  board.whites = OPENING_WHITES;
  board.blacks |= 1;
  board.whites |= 4;
  PrintBoard(&board);

  board.blacks = RotatePiecesCCW(board.blacks);
  board.whites = RotatePiecesCCW(board.whites);
  PrintBoard(&board);

  board.blacks = FlipPiecesTB(board.blacks);
  board.whites = FlipPiecesTB(board.whites);
  PrintBoard(&board);

  MakeBoardCanonical(&board);
  PrintBoard(&board);
}
