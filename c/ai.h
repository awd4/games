#ifndef REV_AI_H_
#define REV_AI_H_

#include "board.h"
#include "mtwister.h"

typedef enum { AI_RANDOM, AI_GREEDY, AI_PURE_MCTS } AIType;

typedef struct AI AI;
typedef int32_t Move(AI *ai, Turn turn, const ChildBoards *choices);
typedef void ClearState(AI *ai);

struct AI {
  AIType type;
  Move *move;
  ClearState *clear;
  void *state;
};

typedef enum { GAME_BLACK_WON, GAME_WHITE_WON, GAME_TIE } GameResult;

typedef struct Game {
  Board history[60];
  int length;
  GameResult result;
} Game;

Game PlayFrom(AI *black_ai, AI *white_ai, const Board *start, Turn turn) {
  Board board = *start;
  ChildBoards children;

  Game game;
  game.length = 0;

  AI *ai = NULL;
  while (true) {
    GenerateChildBoards(&board, turn, &children);
    if (children.count == 0) {
      turn = (turn == BLACKS_TURN) ? WHITES_TURN : BLACKS_TURN;
      GenerateChildBoards(&board, turn, &children);
      if (children.count == 0) {
        break;
      }
    }

    ai = (turn == BLACKS_TURN) ? black_ai : white_ai;

    int32_t choice = ai->move(ai, turn, &children);
    board = children.boards[choice];
    turn = (turn == BLACKS_TURN) ? WHITES_TURN : BLACKS_TURN;

    game.history[game.length] = board;
    game.length++;
  }

  int black_count = 0;
  int white_count = 0;
  CountPieces(&board, &black_count, &white_count);

  if (black_count > white_count) {
    game.result = GAME_BLACK_WON;
  } else if (white_count > black_count) {
    game.result = GAME_WHITE_WON;
  } else {
    game.result = GAME_TIE;
  }

  return game;
}

Game Play(AI *black_ai, AI *white_ai) {
  Board opening_board = OpeningBoard();
  return PlayFrom(black_ai, white_ai, &opening_board, BLACKS_TURN);
}

typedef struct Tournament {
  int black_wins;
  int white_wins;
  int ties;
} Tournament;

Tournament PlayTournament(AI *black_ai, AI *white_ai, int num_games) {
  Tournament tournament = {.black_wins = 0, .white_wins = 0, .ties = 0};

  for (int i = 0; i < num_games; ++i) {
    Game game = Play(black_ai, white_ai);
    tournament.black_wins += (game.result == GAME_BLACK_WON);
    tournament.white_wins += (game.result == GAME_WHITE_WON);
    tournament.ties += (game.result == GAME_TIE);
  }
  printf("(black/white/tie): (%d/%d/%d)", tournament.black_wins,
         tournament.white_wins, tournament.ties);
  if (tournament.black_wins > tournament.white_wins) {
    printf("    Advantage BLACK by: %d\n",
           tournament.black_wins - tournament.white_wins);
  } else if (tournament.white_wins > tournament.black_wins) {
    printf("    Advantage WHITE by: %d\n",
           tournament.white_wins - tournament.black_wins);
  } else {
    printf("    TIED tournament!\n");
  }

  return tournament;
}

int FairArgMax(int *values, int size, MTRand *rng) {
  if (size <= 0) {
    return -1;
  }
  int max_value = values[0];
  int num_max_values = 0;
  for (int i = 1; i < size; ++i) {
    if (values[i] > max_value) {
      max_value = values[i];
      num_max_values = 1;
    } else if (values[i] == max_value) {
      num_max_values++;
    }
  }

  // Break any ties.
  int max_index = 0;
  if (num_max_values > 1) {
    max_index = (int)genRandUniform(rng, num_max_values);
  }

  int arg_max = 0;
  for (int i = 0; i < size; ++i) {
    if (values[i] == max_value) {
      if (max_index == 0) {
        arg_max = i;
        break;
      }
      max_index--;
    }
  }
  return arg_max;
}

int32_t AIRandomMove(AI *ai, Turn turn, const ChildBoards *choices) {
  return (int32_t)genRandUniform((MTRand *)ai->state, choices->count);
}

int32_t AIGreedyMove(AI *ai, Turn turn, const ChildBoards *choices) {
  int pieces_count[MAX_NUM_CHILD_BOARDS];
  int black_count = 0;
  int white_count = 0;
  for (int i = 0; i < choices->count; ++i) {
    CountPieces(&choices->boards[i], &black_count, &white_count);
    pieces_count[i] = (turn == BLACKS_TURN) ? black_count : white_count;
  }

  return FairArgMax(pieces_count, choices->count, (MTRand *)ai->state);
}

typedef struct AIStatePureMCTS {
  int num_playouts;
  AI random;
} AIStatePureMCTS;

int32_t AIPureMCTS(AI *ai, Turn turn, const ChildBoards *choices) {
  AIStatePureMCTS *state = (AIStatePureMCTS *)ai->state;
  int playouts_per_choice = state->num_playouts / choices->count;

  GameResult winning_result =
      (turn == BLACKS_TURN) ? GAME_BLACK_WON : GAME_WHITE_WON;
  Turn next_turn = (turn == BLACKS_TURN) ? WHITES_TURN : BLACKS_TURN;

  int wins_count[MAX_NUM_CHILD_BOARDS];
  for (int i = 0; i < choices->count; ++i) {
    wins_count[i] = 0;
    for (int p = 0; p < playouts_per_choice; ++p) {
      Game game = PlayFrom(&state->random, &state->random, &choices->boards[i],
                           next_turn);
      if (game.result == winning_result) {
        wins_count[i] += 2;
      } else if (game.result == GAME_TIE) {
        wins_count[i] += 1;
      }
    }
  }

  return FairArgMax(wins_count, choices->count, (MTRand *)state->random.state);
}

void AIDefaultClear(AI *ai) {
  free(ai->state);
  ai->state = NULL;
}

void AIClearPureMCTS(AI *ai) {
  AIStatePureMCTS *state = (AIStatePureMCTS *)ai->state;
  state->random.clear(&state->random);
  AIDefaultClear(ai);
}

AI p_AIMakeRandom(AIType type, Move *move) {
  AI random = {.type = type,
               .move = move,
               .clear = AIDefaultClear,
               .state = malloc(sizeof(MTRand))};
  MTRand *rng = (MTRand *)random.state;
  *rng = systemSeedRand();
  return random;
}

AI AIMakeRandom() { return p_AIMakeRandom(AI_RANDOM, AIRandomMove); }

AI AIMakeGreedy() { return p_AIMakeRandom(AI_GREEDY, AIGreedyMove); }

AI AIMakePureMCTS(int num_playouts) {
  AI pure_mcts = {.type = AI_PURE_MCTS,
                  .move = AIPureMCTS,
                  .clear = AIClearPureMCTS,
                  .state = malloc(sizeof(AIStatePureMCTS))};
  AIStatePureMCTS *state = (AIStatePureMCTS *)pure_mcts.state;
  state->num_playouts = num_playouts;
  state->random = AIMakeRandom();
  return pure_mcts;
}

AI AIMakeSameTypeAs(AI *ai) {
  if (ai->type == AI_RANDOM) {
    return AIMakeRandom();
  } else if (ai->type == AI_GREEDY) {
    return AIMakeGreedy();
  } else if (ai->type == AI_PURE_MCTS) {
    AIStatePureMCTS *state = (AIStatePureMCTS *)ai->state;
    return AIMakePureMCTS(state->num_playouts);
  }
  return AIMakeRandom();
}

#endif // REV_AI_H_
