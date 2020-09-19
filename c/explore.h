#ifndef REV_EXPLORE_H_
#define REV_EXPLORE_H_

#include "board.h"
#include "bucket_list.h"
#include "mtwister.h"

void CollectBoards(Board *start, Turn turn, int num_turns, BoardList *list) {
  AddBoard(list, start);

  for (int i = 0; i < num_turns; ++i) {
    Board *last = LastBoard(list);
    Board *next;

    while (next = NextBoard(list)) {

      ChildBoards children;
      GenerateCanonicalChildBoards(next, turn, &children);
      AddChildBoards(list, &children);

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
}

#endif // REV_EXPLORE_H_
