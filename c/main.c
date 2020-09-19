#include "board.h"
#include "mtwister.h"
#include "bucket_list.h"
#include "explore.h"

#include <stdio.h>
#include <stdbool.h>
#include <time.h>

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

  clock_t t0, t1;

  BoardList list = MakeBoardList();
  Board opening_board = OpeningBoard();
  t0 = clock();
  CollectBoardsBreadthFirst(&opening_board, BLACKS_TURN, 8, &list);
  t1 = clock();
  double bfs_time = (double)(t1 - t0) / CLOCKS_PER_SEC;

  Board* next;
  ResetBoardIter(&list);
  //while(next = NextBoard(&list)) {
  //  PrintBoard(next);
  //} 
  printf("Num boards: %u\n", BoardListSize(&list));

  for (int i=0; i<5; ++i) {
    Board sample = RandomSampleBoardDepthFirst(&opening_board, BLACKS_TURN, 25, &rng);
    PrintBoard(&sample);
  }

  BoardList sample_list = MakeBoardList();
  t0 = clock();
  SampleBoardsWithinDepthRange(&opening_board, BLACKS_TURN, 5, 60, &rng, 300, &sample_list);
  t1 = clock();
  double dfs_time = (double)(t1 - t0) / CLOCKS_PER_SEC;
  printf("Depth First Samples:\n");
  while(next = NextBoard(&sample_list)) {
    //PrintBoard(next);
  } 

  printf("%d, %d\n", BoardListSize(&list), BoardListSize(&sample_list));
  printf("%f, %f\n", bfs_time, dfs_time);
}
