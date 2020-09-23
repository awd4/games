#ifndef REV_TABLE_H_
#define REV_TABLE_H_

#include "board.h"

#include <math.h>
#include <stdint.h>

typedef uint32_t H32(Board *board);

uint64_t AddPieces(Board *board) { return board->blacks + board->whites; }
uint64_t MultiplyPieces(Board *board) { return board->blacks * board->whites; }

uint32_t hash1(Board *board) { return board->blacks; }
uint32_t hash2(Board *board) { return board->whites; }
uint32_t hash3(Board *board) { return AddPieces(board); }
uint32_t hash4(Board *board) { return MultiplyPieces(board); }
uint32_t hash5(Board *board) { return board->blacks ^ board->whites; }
uint32_t hash6(Board *board) {
  uint64_t x = board->blacks + board->whites;
  return (x & 0xFFFFFFFF ^ (x >> 32) & 0xFFFFFFFF);
}
uint32_t hash7(Board *board) {
  uint64_t x = board->blacks * board->whites;
  return (x & 0xFFFFFFFF ^ (x >> 32) & 0xFFFFFFFF);
}
uint32_t hash8(Board *board) {
  uint64_t x = board->blacks - board->whites;
  return (x & 0xFFFFFFFF ^ (x >> 32) & 0xFFFFFFFF);
}
uint32_t hash9(Board *board) {
  uint64_t x = board->blacks - board->whites;
  x = x * 0x118F20237E9B23C7;
  return (x & 0xFFFFFFFF ^ (x >> 32) & 0xFFFFFFFF);
}
uint32_t hash10(Board *board) {
  uint64_t x = board->blacks - board->whites;
  x = x * 0x114F20237E9B23C7;
  return (x & 0xFFFFFFFF ^ (x >> 32) & 0xFFFFFFFF);
}

void EvaluateHash32Function(BoardList *list, H32 *hash) {
  uint32_t counts[32];
  for (int i = 0; i < 32; ++i) {
    counts[i] = 0;
  }

  Board *next;
  ResetBoardIter(list);
  while (next = NextBoard(list)) {
    uint32_t code = hash(next);
    for (int i = 0; i < 32; ++i) {
      counts[i] += (code >> i) & 1;
    }
  }
  uint32_t total = BoardListSize(list);

  double max_half_dist = 0.0;
  for (int i = 0; i < 32; ++i) {
    double fraction = counts[i] / (double)total;
    if (fabs(fraction - 0.5) > max_half_dist) {
      max_half_dist = fabs(fraction - 0.5);
    }
  }
  printf("Score: %f\n", max_half_dist);
}

#endif // REV_TABLE_H_
