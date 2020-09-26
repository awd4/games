#ifndef REV_AI_H_
#define REV_AI_H_

#include "board.h"
#include "mtwister.h"

typedef enum { AI_RANDOM } AIType;

typedef struct AI AI;
typedef int32_t Move(AI *ai, Turn turn, const ChildBoards *choices);
typedef void ClearState(AI *ai);

struct AI {
  AIType type;
  Move *move;
  ClearState *clear;
  void *state;
};

int32_t AIRandomMove(AI *ai, Turn turn, const ChildBoards *choices) {
  if (choices->count <= 0) {
    return -1;
  }

  return (int32_t)genRandUniform((MTRand *)ai->state, choices->count);
}

void AIDefaultClear(AI *ai) {
  free(ai->state);
  ai->state = NULL;
}

AI AIMakeRandom() {
  AI random;
  random.type = AI_RANDOM;
  random.move = AIRandomMove;
  random.clear = AIDefaultClear;
  random.state = malloc(sizeof(MTRand));

  MTRand *rng = (MTRand *)random.state;
  *rng = systemSeedRand();

  return random;
}

typedef struct Game {
  int white_count;
  int black_count;
  Board history[60];
  int length;
} Game;

Game PlaySelf(AI *ai) {
  Board board = OpeningBoard();
  Turn turn = BLACKS_TURN;
  ChildBoards children;

  Game game;
  game.length = 0;

  while (true) {
    // PrintBoard(&board);

    GenerateChildBoards(&board, turn, &children);
    if (children.count == 0) {
      turn = (turn == BLACKS_TURN) ? WHITES_TURN : BLACKS_TURN;
      GenerateChildBoards(&board, turn, &children);
      if (children.count == 0) {
        // printf("Neither player can move!\n");
        break;
      }
    }

    int32_t choice = ai->move(ai, turn, &children);
    board = children.boards[choice];
    turn = (turn == BLACKS_TURN) ? WHITES_TURN : BLACKS_TURN;

    game.history[game.length] = board;
    game.length++;
  }

  CountPieces(&board, &game.black_count, &game.white_count);
  if (game.black_count > game.white_count) {
    printf("Black won.\n");
  } else if (game.white_count > game.black_count) {
    printf("White won.\n");
  } else {
    printf("Tie.\n");
  }

  return game;
}

#endif // REV_AI_H_
