#ifndef REV_BOARD_H_
#define REV_BOARD_H_

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#define MAX_NUM_CHILD_BOARDS 60

const uint64_t OPENING_BLACKS = 34628173824;
const uint64_t OPENING_WHITES = 68853694464;
const uint64_t LEFT_BIT = 0x8000000000000000;

const uint64_t rcol = 72340172838076673ULL;
const uint64_t lcol = 9259542123273814144ULL;
const uint64_t not_rcol = 18374403900871474942Ull;
const uint64_t not_lcol = 9187201950435737471ULL;

const char MARK_SIDE[] = "|";
const char MARK_TOP_BOT[] = "-----------------";
const char MARK_EMPTY[] = " ";
const char MARK_BLACK[] = "#";
const char MARK_WHITE[] = "o";

typedef enum { BLACKS_TURN, WHITES_TURN } Turn;

typedef struct Board {
  uint64_t blacks;
  uint64_t whites;
} Board;

typedef struct ChildBoards {
  Board boards[MAX_NUM_CHILD_BOARDS];
  int count;
} ChildBoards;

Board OpeningBoard() {
  Board board;
  board.blacks = OPENING_BLACKS;
  board.whites = OPENING_WHITES;
  return board;
}

bool BoardsEqual(Board *board1, Board *board2) {
  return board1->blacks == board2->blacks && board1->whites == board2->whites;
}

void PrintBoard(Board *board) {
  if (board == NULL) {
    printf("Cannot print a NULL Board.");
    return;
  }
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

void PrintChildBoards(ChildBoards *children) {
  for (int i = 0; i < children->count; ++i) {
    PrintBoard(&children->boards[i]);
  }
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

void m_GenerateChildBoards(Board *board, Turn turn, ChildBoards *children,
                           bool canonical) {
  children->count = 0;

  uint64_t up_moves, dn_moves, lf_moves, rt_moves;
  uint64_t ur_moves, ul_moves, dr_moves, dl_moves;
  uint64_t moves;

  uint64_t e, w, b;
  uint64_t mv, flip, tmp;

  Board *child;

  e = ~(board->blacks | board->whites);
  b = board->blacks;
  w = board->whites;

  uint64_t c1, c2, c1_mv, c2_mv, c2_run;

  if (turn == BLACKS_TURN) {
    c1 = b;
    c2 = w;
  } else {
    c1 = w;
    c2 = b;
  }

  c1_mv = (c1 << 56);
  c2_mv = (c2 << 48);
  up_moves = c2_mv & c1_mv;
  for (int i = 5; i > 0; --i) {
    c1_mv = (c1 << (8 * (i + 1)));
    c2_mv = (c2 << (8 * i));
    up_moves = c2_mv & (c1_mv | up_moves);
  }
  up_moves = up_moves & e;

  c1_mv = (c1 >> 56);
  c2_mv = (c2 >> 48);
  dn_moves = c2_mv & c1_mv;
  for (int i = 5; i > 0; --i) {
    c1_mv = (c1 >> (8 * (i + 1)));
    c2_mv = (c2 >> (8 * i));
    dn_moves = c2_mv & (c1_mv | dn_moves);
  }
  dn_moves = dn_moves & e;

  c1_mv = not_rcol & (c1 << 1);
  c1_mv = not_rcol & (c1_mv << 1);
  c2_run = not_rcol & (c2 << 1);
  lf_moves = c2_run & c1_mv;
  for (int i = 1; i < 7; ++i) {
    c2_run = c2_run & not_rcol & (c2_run << 1);
    c1_mv = not_rcol & (c1_mv << 1);
    lf_moves = lf_moves | c2_run & c1_mv;
  }
  lf_moves = lf_moves & e;

  c1_mv = not_lcol & (c1 >> 1);
  c1_mv = not_lcol & (c1_mv >> 1);
  c2_run = not_lcol & (c2 >> 1);
  rt_moves = c2_run & c1_mv;
  for (int i = 1; i < 7; ++i) {
    c2_run = c2_run & not_lcol & (c2_run >> 1);
    c1_mv = not_lcol & (c1_mv >> 1);
    rt_moves = rt_moves | c2_run & c1_mv;
  }
  rt_moves = rt_moves & e;

  c1_mv = not_lcol & (c1 << 7);
  c1_mv = not_lcol & (c1_mv << 7);
  c2_run = not_lcol & (c2 << 7);
  ur_moves = c2_run & c1_mv;
  for (int i = 1; i < 7; ++i) {
    c2_run = c2_run & not_lcol & (c2_run << 7);
    c1_mv = not_lcol & (c1_mv << 7);
    ur_moves = ur_moves | c2_run & c1_mv;
  }
  ur_moves = ur_moves & e;

  c1_mv = not_rcol & (c1 << 9);
  c1_mv = not_rcol & (c1_mv << 9);
  c2_run = not_rcol & (c2 << 9);
  ul_moves = c2_run & c1_mv;
  for (int i = 1; i < 7; ++i) {
    c2_run = c2_run & not_rcol & (c2_run << 9);
    c1_mv = not_rcol & (c1_mv << 9);
    ul_moves = ul_moves | c2_run & c1_mv;
  }
  ul_moves = ul_moves & e;

  c1_mv = not_lcol & (c1 >> 9);
  c1_mv = not_lcol & (c1_mv >> 9);
  c2_run = not_lcol & (c2 >> 9);
  dr_moves = c2_run & c1_mv;
  for (int i = 1; i < 7; ++i) {
    c2_run = c2_run & not_lcol & (c2_run >> 9);
    c1_mv = not_lcol & (c1_mv >> 9);
    dr_moves = dr_moves | c2_run & c1_mv;
  }
  dr_moves = dr_moves & e;

  c1_mv = not_rcol & (c1 >> 7);
  c1_mv = not_rcol & (c1_mv >> 7);
  c2_run = not_rcol & (c2 >> 7);
  dl_moves = c2_run & c1_mv;
  for (int i = 1; i < 7; ++i) {
    c2_run = c2_run & not_rcol & (c2_run >> 7);
    c1_mv = not_rcol & (c1_mv >> 7);
    dl_moves = dl_moves | c2_run & c1_mv;
  }
  dl_moves = dl_moves & e;

  moves = up_moves | dn_moves | lf_moves | rt_moves | ur_moves | ul_moves |
          dr_moves | dl_moves;

  if (moves == 0) {
    return;
  }

  for (int i = 0; i < 64; ++i) {
    mv = (1ULL << i);
    if ((moves & mv) == 0) {
      continue;
    }

    flip = mv;

    if (mv & up_moves) {
      tmp = mv >> 8;
      while (tmp & c2) {
        flip = flip | tmp;
        tmp = tmp >> 8;
      }
    }
    if (mv & dn_moves) {
      tmp = mv << 8;
      while (tmp & c2) {
        flip = flip | tmp;
        tmp = tmp << 8;
      }
    }
    if (mv & lf_moves) {
      tmp = mv >> 1;
      while (tmp & c2) {
        flip = flip | tmp;
        tmp = tmp >> 1;
      }
    }
    if (mv & rt_moves) {
      tmp = mv << 1;
      while (tmp & c2) {
        flip = flip | tmp;
        tmp = tmp << 1;
      }
    }
    if (mv & ur_moves) {
      tmp = mv >> 7;
      while (tmp & c2) {
        flip = flip | tmp;
        tmp = tmp >> 7;
      }
    }
    if (mv & ul_moves) {
      tmp = mv >> 9;
      while (tmp & c2) {
        flip = flip | tmp;
        tmp = tmp >> 9;
      }
    }
    if (mv & dr_moves) {
      tmp = mv << 9;
      while (tmp & c2) {
        flip = flip | tmp;
        tmp = tmp << 9;
      }
    }
    if (mv & dl_moves) {
      tmp = mv << 7;
      while (tmp & c2) {
        flip = flip | tmp;
        tmp = tmp << 7;
      }
    }

    child = &children->boards[children->count];

    if (turn == BLACKS_TURN) {
      child->blacks = board->blacks | flip;
      child->whites = board->whites & ~flip;
    } else {
      child->blacks = board->blacks & ~flip;
      child->whites = board->whites | flip;
    }

    if (canonical) {
      MakeBoardCanonical(child);
      bool already_present = false;
      for (int j = 0; j < children->count; ++j) {
        if (BoardsEqual(child, &children->boards[j])) {
          already_present = true;
          break;
        }
      }
      if (already_present) {
        continue;
      }
    }

    children->count++;
  }
}

void GenerateChildBoards(Board *board, Turn turn, ChildBoards *children) {
  m_GenerateChildBoards(board, turn, children, false);
}

void GenerateCanonicalChildBoards(Board *board, Turn turn,
                                  ChildBoards *children) {
  m_GenerateChildBoards(board, turn, children, true);
}

#endif // REV_BOARD_H_
