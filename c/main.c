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
  CollectBoardsBreadthFirst(&opening_board, BLACKS_TURN, 11, &list);
  t1 = clock();
  double bfs_time = (double)(t1 - t0) / CLOCKS_PER_SEC;
  printf("Num boards:       %u  (found in %fs)\n", BoardListSize(&list),
         bfs_time);

  BoardSet board_set;
  BoardSetInit(&board_set);
  t0 = clock();
  CollectBoardSetBreadthFirst(&opening_board, BLACKS_TURN, 11, &board_set);
  t1 = clock();
  double bfs_set_time = (double)(t1 - t0) / CLOCKS_PER_SEC;
  printf("Num boards (set): %u  (found in %fs)\n", board_set.size,
         bfs_set_time);

  return;

  Board *next;
  // ResetBoardIter(&list);
  // while(next = NextBoard(&list)) {
  //  PrintBoard(next);
  //}

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

void ai_stuff() {
  AI random = AIMakeRandom();
  AI greedy = AIMakeGreedy();
  AI pure_mcts = AIMakePureMCTS(100);

  PlayTournament(&random, &random, 10000);
  PlayTournament(&random, &greedy, 10000);
  PlayTournament(&greedy, &random, 10000);
  PlayTournament(&greedy, &greedy, 10000);

  PlayTournament(&random, &pure_mcts, 400);
  PlayTournament(&greedy, &pure_mcts, 400);

  pure_mcts.clear(&pure_mcts);
  greedy.clear(&greedy);
  random.clear(&random);
}

int main(int argc, char **argv) {
  // scratchpad();

  ai_stuff();
}
