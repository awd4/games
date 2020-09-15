#ifndef REV_BOARD_H_
#define REV_BOARD_H_

#include <stdint.h>
#include <stdio.h>

const uint64_t OPENING_BLACKS = 34628173824;
const uint64_t OPENING_WHITES = 68853694464;
const uint64_t LEFT_BIT = 0x8000000000000000;

const char MARK_SIDE[] = "|";
const char MARK_TOP_BOT[] = "-----------------";
const char MARK_EMPTY[] = " ";
const char MARK_BLACK[] = "#";
const char MARK_WHITE[] = "o";

typedef struct Board {
  uint64_t blacks;
  uint64_t whites;
} Board;

void PrintBoard(Board *board) {
  printf("%s\n", MARK_TOP_BOT);
  for (int i = 0; i < 64; ++i) {
    int c = i % 8;
    if (c == 0) {
      printf("%s", MARK_SIDE);
    }
    if ((board->blacks << i) & LEFT_BIT) {
      printf("%s", MARK_BLACK);
    } else if ((board->whites << i) & LEFT_BIT) {
      printf("%s", MARK_WHITE);
    } else {
      printf("%s", MARK_EMPTY);
    }
    if (c == 7) {
      printf("%s\n", MARK_SIDE);
    } else {
      printf("%s", MARK_EMPTY);
    }
  }
  printf("%s\n", MARK_TOP_BOT);
}

uint64_t RotatePiecesCCW(uint64_t pieces) {
  uint64_t rotated = 0;

  for (int i = 0; i < 64; ++i) {
    rotated <<= 1;

    int dx = i % 8;
    int dy = i / 8;
    uint64_t mask = 1LU << (56 - dx * 8 + dy);

    if (mask & pieces) {
      rotated ^= 1;
    }
  }

  return rotated;
}

uint64_t FlipPiecesTB(uint64_t pieces) {
  const uint64_t row = 255;
  uint64_t flipped = 0;

  for (int i = 0; i < 8; ++i) {
    flipped <<= 8;

    uint64_t mask = row << (i * 8);
    mask = mask & pieces;
    mask = mask >> (i * 8);
    flipped ^= mask;
  }

  return flipped;
}

void RotateBoardCCW(Board *board) {
  board->blacks = RotatePiecesCCW(board->blacks);
  board->whites = RotatePiecesCCW(board->whites);
}

void FlipBoardTB(Board *board) {
  board->blacks = FlipPiecesTB(board->blacks);
  board->whites = FlipPiecesTB(board->whites);
}

void MakeBoardCanonical(Board *board) {
  uint64_t blacks_[8];
  uint64_t whites_[8];

  blacks_[0] = board->blacks;
  whites_[0] = board->whites;
  blacks_[1] = RotatePiecesCCW(blacks_[0]);
  whites_[1] = RotatePiecesCCW(whites_[0]);
  blacks_[2] = RotatePiecesCCW(blacks_[1]);
  whites_[2] = RotatePiecesCCW(whites_[1]);
  blacks_[3] = RotatePiecesCCW(blacks_[2]);
  whites_[3] = RotatePiecesCCW(whites_[2]);
  blacks_[4] = FlipPiecesTB(blacks_[0]);
  whites_[4] = FlipPiecesTB(whites_[0]);
  blacks_[5] = FlipPiecesTB(blacks_[1]);
  whites_[5] = FlipPiecesTB(whites_[1]);
  blacks_[6] = FlipPiecesTB(blacks_[2]);
  whites_[6] = FlipPiecesTB(whites_[2]);
  blacks_[7] = FlipPiecesTB(blacks_[3]);
  whites_[7] = FlipPiecesTB(whites_[3]);

  int min_index = 0;
  for (int i = 1; i < 8; ++i) {
    if (blacks_[i] < blacks_[min_index] ||
        (blacks_[i] == blacks_[min_index] && whites_[i] < whites_[min_index])) {
      min_index = i;
    }
  }

  board->blacks = blacks_[min_index];
  board->whites = whites_[min_index];
}

#endif // REV_BOARD_H_
