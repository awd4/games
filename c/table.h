#ifndef REV_TABLE_H_
#define REV_TABLE_H_

#include "board.h"

#include <math.h>
#include <stdbool.h>
#include <stdint.h>

typedef uint32_t H32(const Board *board);

uint32_t hash1(const Board *board) { return board->blacks; }
uint32_t hash2(const Board *board) { return board->whites; }
uint32_t hash3(const Board *board) { return board->blacks + board->whites; }
uint32_t hash4(const Board *board) { return board->blacks * board->whites; }
uint32_t hash5(const Board *board) { return board->blacks ^ board->whites; }
uint32_t hash6(const Board *board) {
  uint64_t x = board->blacks + board->whites;
  return (x & 0xFFFFFFFF ^ (x >> 32) & 0xFFFFFFFF);
}
uint32_t hash7(const Board *board) {
  uint64_t x = board->blacks * board->whites;
  return (x & 0xFFFFFFFF ^ (x >> 32) & 0xFFFFFFFF);
}
uint32_t hash8(const Board *board) {
  uint64_t x = board->blacks - board->whites;
  return (x & 0xFFFFFFFF ^ (x >> 32) & 0xFFFFFFFF);
}
uint32_t hash9(const Board *board) {
  uint64_t x = board->blacks - board->whites;
  x = x * 0x118F20237E9B23C7;
  return (x & 0xFFFFFFFF ^ (x >> 32) & 0xFFFFFFFF);
}
uint32_t hash10(const Board *board) {
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

const Board BOARD_SET_EMPTY = {.blacks = 0, .whites = 0};
const Board BOARD_SET_FREE = {.blacks = 0, .whites = 1};

typedef struct BoardSet {
  H32 *hash;
  uint32_t size;
  uint32_t log_capacity;
  Board *boards;
} BoardSet;

uint32_t BoardSetCapacity(BoardSet *set) { return 1 << set->log_capacity; }

void BoardSetInit(BoardSet *set) {
  set->hash = hash10;
  set->size = 0;
  set->log_capacity = 12;
  set->boards = (Board *)calloc(BoardSetCapacity(set), sizeof(Board));
}

void BoardSetFree(BoardSet *set) {
  free(set->boards);
  set->hash = NULL;
  set->size = 0;
  set->log_capacity = 0;
}

void BoardSetAdd(BoardSet *set, const Board *board) {
  uint32_t capacity = BoardSetCapacity(set);
  float load = set->size / (float)capacity;
  if (load > 0.7) {
    // resize
    // printf("resizing from %u to %u (%u).\n", capacity, 2 * capacity,
    //       set->log_capacity);
    Board *old_boards = set->boards;

    set->size = 0;
    set->log_capacity++;
    set->boards = (Board *)calloc(BoardSetCapacity(set), sizeof(Board));

    for (int i = 0; i < capacity; ++i) {
      if (old_boards[i].blacks == 0 && old_boards[i].whites == 0) {
        continue;
      }
      BoardSetAdd(set, old_boards + i);
    }
    free(old_boards);

    capacity = BoardSetCapacity(set);
    // printf("done resizing\n");
  }

  uint32_t code = set->hash(board);
  int shift = 32 - set->log_capacity;
  uint32_t hit = (code << shift) >> shift;

  // Linear probling.
  uint32_t index = hit;
  while (1) {
    if (set->boards[index].blacks == 0 && set->boards[index].whites == 0) {
      break;
    }
    index = (index + 1) % capacity;
  }

  set->boards[index] = *board;
  set->size++;
}

bool BoardSetHas(BoardSet *set, const Board *board) {
  uint32_t capacity = BoardSetCapacity(set);
  uint32_t code = set->hash(board);
  int shift = 32 - set->log_capacity;
  uint32_t hit = (code << shift) >> shift;

  uint32_t index = hit;
  bool found = false;
  while (1) {
    if (set->boards[index].blacks == 0 && set->boards[index].whites == 0) {
      break;
    }
    if (set->boards[index].blacks == board->blacks &&
        set->boards[index].whites == board->whites) {
      found = true;
      break;
    }
    index = (index + 1) % capacity;
    if (index == hit) {
      break;
    }
  }

  return found;
}

#endif // REV_TABLE_H_
