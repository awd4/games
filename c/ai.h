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

#endif // REV_AI_H_
