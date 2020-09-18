#include "board.h"
#include "mtwister.h"
#include "bucket_list.h"

#include <stdio.h>
#include <stdbool.h>

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

  BoardList list = MakeBoardList();
  Board opening_board = OpeningBoard();
  AddBoard(&list, &opening_board);

  Turn turn = BLACKS_TURN;
  for (int i=0; i< 7; ++i) {
    Board* last = LastBoard(&list);
    Board* next;
    while (next = NextBoard(&list)) {

      ChildBoards children;
      GenerateCanonicalChildBoards(next, turn, &children);
      AddChildBoards(&list, &children);

      if (next == last) {
        break;
      }
    }

    if (turn == BLACKS_TURN) {
      turn = WHITES_TURN;
    } else {
      turn = BLACKS_TURN;
    }
  }

  ResetBoardIter(&list);
  Board* next;
  //while(next = NextBoard(&list)) {
    //PrintBoard(next);
  //}
  //PrintBoardList(&list);
  printf("Num boards: %u\n", BoardListSize(&list));
}
