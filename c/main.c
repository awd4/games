#include "board.h"
#include "mtwister.h"

#include <stdio.h>

int main(int argc, char** argv) {
  printf("Hello, world!\n");

  Board board = OpeningBoard();
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

  MTRand rng = seedRand(4);
  for (int i=0; i<10; ++i) {
    uint64_t sample = genRandUniform(&rng, 10);
    printf("%lu\n", sample);
  }

  Board current = OpeningBoard();

  printf("Opening board:\n");
  PrintBoard(&current);

  ChildBoards children;
  GenerateCanonicalChildBoards(&current, BLACKS_TURN, &children);

  printf("First generation:\n");
  PrintChildBoards(&children);

  current = children.boards[0];
  GenerateCanonicalChildBoards(&current, WHITES_TURN, &children);
  printf("Second generation:\n");
  PrintChildBoards(&children);

}
