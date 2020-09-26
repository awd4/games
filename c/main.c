#include "ai.h"
#include "board.h"
#include "explore.h"
#include "list.h"
#include "mtwister.h"
#include "table.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

void scratchpad() {

  Board board = OpeningBoard();
  board.blacks |= 1;
  board.whites |= 4;
  // PrintBoard(&board);

  board.blacks = RotatePiecesCCW(board.blacks);
  board.whites = RotatePiecesCCW(board.whites);
  // PrintBoard(&board);

  board.blacks = FlipPiecesTB(board.blacks);
  board.whites = FlipPiecesTB(board.whites);
  // PrintBoard(&board);

  MakeBoardCanonical(&board);
  // PrintBoard(&board);

  MTRand rng = seedRand(4);
  for (int i = 0; i < 10; ++i) {
    uint64_t sample = genRandUniform(&rng, 10);
    // printf("%lu\n", sample);
  }

  clock_t t0, t1;

  BoardList list = MakeBoardList();
  Board opening_board = OpeningBoard();
  t0 = clock();
  CollectBoardsBreadthFirst(&opening_board, BLACKS_TURN, 8, &list);
  t1 = clock();
  double bfs_time = (double)(t1 - t0) / CLOCKS_PER_SEC;
  printf("Num boards:       %u\n", BoardListSize(&list));

  BoardSet board_set;
  BoardSetInit(&board_set);
  t0 = clock();
  CollectBoardSetBreadthFirst(&opening_board, BLACKS_TURN, 12, &board_set);
  t1 = clock();
  double bfs_set_time = (double)(t1 - t0) / CLOCKS_PER_SEC;

  Board *next;
  // ResetBoardIter(&list);
  // while(next = NextBoard(&list)) {
  //  PrintBoard(next);
  //}
  printf("Num boards (set): %u\n", board_set.size);

  for (int i = 0; i < 5; ++i) {
    Board sample =
        RandomSampleBoardDepthFirst(&opening_board, BLACKS_TURN, 25, &rng);
    // PrintBoard(&sample);
  }

  BoardList sample_list = MakeBoardList();
  t0 = clock();
  SampleBoardsWithinDepthRange(&opening_board, BLACKS_TURN, 6, 60, &rng,
                               15, // 553,
                               &sample_list);
  t1 = clock();
  double dfs_time = (double)(t1 - t0) / CLOCKS_PER_SEC;

  // printf("Depth First Samples:\n");
  // while (next = NextBoard(&sample_list)) {
  // PrintBoard(next);
  //}

  printf("%d, %d\n", BoardListSize(&list), BoardListSize(&sample_list));
  printf("%f, %f, %f\n", bfs_time, bfs_set_time, dfs_time);

  Board table[500];
  EvaluateHash32Function(&sample_list, hash1);
  EvaluateHash32Function(&sample_list, hash2);
  EvaluateHash32Function(&sample_list, hash3);
  EvaluateHash32Function(&sample_list, hash4);
  EvaluateHash32Function(&sample_list, hash5);
  EvaluateHash32Function(&sample_list, hash6);
  EvaluateHash32Function(&sample_list, hash7);
  EvaluateHash32Function(&sample_list, hash8);
  EvaluateHash32Function(&sample_list, hash9);
  EvaluateHash32Function(&sample_list, hash10);

  printf("\n");

  EvaluateHash32Function(&list, hash1);
  EvaluateHash32Function(&list, hash2);
  EvaluateHash32Function(&list, hash3);
  EvaluateHash32Function(&list, hash4);
  EvaluateHash32Function(&list, hash5);
  EvaluateHash32Function(&list, hash6);
  EvaluateHash32Function(&list, hash7);
  EvaluateHash32Function(&list, hash8);
  EvaluateHash32Function(&list, hash9);
  EvaluateHash32Function(&list, hash10);

  BoardSet set;
  BoardSetInit(&set);

  ResetBoardIter(&list);
  while (next = NextBoard(&list)) {
    if (BoardSetHas(&set, next)) {
      printf("Found a duplicate board. Yay!\n");
      continue;
    }
    if (set.size < 91) {
      BoardSetAdd(&set, next);
      if (!BoardSetHas(&set, next)) {
        printf("Something is wrong. The set should have this board already!\n");
        exit(1);
      }
    } else {
      // break;
    }
  }
  printf("load: %f\n", set.size / (float)BoardSetCapacity(&set));
}

int main(int argc, char **argv) {
  // scratchpad();

  AI ai = AIMakeRandom();

  int black_wins = 0;
  int white_wins = 0;
  int ties = 0;

  for (int i = 0; i < 1000; ++i) {
    Game game = PlaySelf(&ai);

    if (game.black_count > game.white_count) {
      black_wins++;
    } else if (game.white_count > game.black_count) {
      white_wins++;
    } else {
      ties++;
    }
  }
  printf("(black/white/tie): (%d/%d/%d)\n", black_wins, white_wins, ties);
}
