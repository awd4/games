#include "board.h"
#include "mtwister.h"
#include "bucket_list.h"

#include <stdio.h>

int main(int argc, char** argv) {

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

  BoardList list = MakeBoardList();
  AddBoard(&list, &current);

  ChildBoards children;
  GenerateCanonicalChildBoards(&current, BLACKS_TURN, &children);
  AddChildBoards(&list, &children);

  current = children.boards[0];
  GenerateCanonicalChildBoards(&current, WHITES_TURN, &children);
  AddChildBoards(&list, &children);

  Board* next;
  while(next = NextBoard(&list)) {
    PrintBoard(next);
  }
  //PrintBoardList(&list);
}
