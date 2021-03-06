#ifndef REV_EXPLORE_H_
#define REV_EXPLORE_H_

#include "board.h"
#include "list.h"
#include "mtwister.h"
#include "table.h"

void CollectBoardsBreadthFirst(Board *start, Turn turn, int num_turns,
                               BoardList *list) {
  ResetBoardIter(list);
  AddBoard(list, start);

  for (int i = 0; i < num_turns; ++i) {
    Board *last = LastBoard(list);
    Board *next;

    ChildBoards children;
    while (next = NextBoard(list)) {

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

void CollectBoardSetBreadthFirst(Board *start, Turn turn, int num_turns,
                                 BoardSet *set) {
  BoardList list = MakeBoardList();
  AddBoard(&list, start);

  for (int i = 0; i < num_turns; ++i) {
    Board *last = LastBoard(&list);
    Board *next;

    ChildBoards children;
    while (next = NextBoard(&list)) {

      GenerateCanonicalChildBoards(next, turn, &children);
      for (int j = 0; j < children.count; ++j) {
        if (!BoardSetHas(set, &children.boards[j])) {
          BoardSetAdd(set, &children.boards[j]);
          AddBoard(&list, &children.boards[j]);
        }
      }

      if (next == last) {
        break;
      }
    }

    // Prune already-processed buckets.
    while (list.head != list.iter.curr) {
      BoardBucket *temp = list.head;
      list.head = list.head->next;

      temp->next = NULL;
      temp->count = 0;
      free(temp);
    }

    if (turn == BLACKS_TURN) {
      turn = WHITES_TURN;
    } else {
      turn = BLACKS_TURN;
    }
  }
}

// Uniformly-sample across moves num_turns times. Return the resulting board.
Board RandomSampleBoardDepthFirst(Board *start, Turn turn, int num_turns,
                                  MTRand *rng) {
  Board sample = *start;
  for (int i = 0; i < num_turns; ++i) {
    ChildBoards children;
    GenerateCanonicalChildBoards(&sample, turn, &children);
    if (children.count == 0) {
      break;
    }

    uint64_t choice = genRandUniform(rng, children.count);
    sample = children.boards[choice];

    if (turn == BLACKS_TURN) {
      turn = WHITES_TURN;
    } else {
      turn = BLACKS_TURN;
    }
  }
  return sample;
}

void SampleBoardsWithinDepthRange(Board *start, Turn turn, int min_num_turns,
                                  int max_num_turns, MTRand *rng,
                                  int num_samples, BoardList *list) {
  if (max_num_turns < min_num_turns || min_num_turns < 0 || num_samples < 0) {
    exit(1);
  }

  int num_turns_range = max_num_turns - min_num_turns;
  for (int i = 0; i < num_samples; ++i) {
    int num_turns = min_num_turns;
    if (num_turns_range > 0) {
      num_turns += genRandUniform(rng, num_turns_range);
    }

    Board sample = RandomSampleBoardDepthFirst(start, turn, num_turns, rng);
    AddBoard(list, &sample);
  }
}

#endif // REV_EXPLORE_H_
