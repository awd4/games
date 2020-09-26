#ifndef REV_AI_H_
#define REV_AI_H_

#include "board.h"
#include "mtwister.h"

typedef enum { AI_RANDOM, AI_GREEDY } AIType;

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
  return (int32_t)genRandUniform((MTRand *)ai->state, choices->count);
}

int32_t AIGreedyMove(AI *ai, Turn turn, const ChildBoards *choices) {
  int pieces_count[MAX_NUM_CHILD_BOARDS];
  int black_count = 0;
  int white_count = 0;
  int max_count = 0;
  int num_max_count_boards = 0;
  for (int i = 0; i < choices->count; ++i) {
    CountPieces(&choices->boards[i], &black_count, &white_count);
    pieces_count[i] = (turn == BLACKS_TURN) ? black_count : white_count;
    if (pieces_count[i] > max_count) {
      max_count = pieces_count[i];
      num_max_count_boards = 1;
    } else if (pieces_count[i] == max_count) {
      num_max_count_boards++;
    }
  }

  // Break any ties.
  int max_index = 0;
  if (num_max_count_boards > 1) {
    max_index = (int)genRandUniform((MTRand *)ai->state, num_max_count_boards);
  }

  int32_t choice = 0;
  for (int i = 0; i < choices->count; ++i) {
    if (pieces_count[i] == max_count) {
      if (max_index == 0) {
        choice = i;
        break;
      }
      max_index--;
    }
  }
  return choice;
}

void AIDefaultClear(AI *ai) {
  free(ai->state);
  ai->state = NULL;
}

AI AIMakeRandom() {
  AI random = {.type = AI_RANDOM,
               .move = AIRandomMove,
               .clear = AIDefaultClear,
               .state = malloc(sizeof(MTRand))};
  MTRand *rng = (MTRand *)random.state;
  *rng = systemSeedRand();
  return random;
}

AI AIMakeGreedy() {
  AI greedy = {.type = AI_GREEDY,
               .move = AIGreedyMove,
               .clear = AIDefaultClear,
               .state = malloc(sizeof(MTRand))};
  MTRand *rng = (MTRand *)greedy.state;
  *rng = systemSeedRand();
  return greedy;
}

typedef struct Game {
  int white_count;
  int black_count;
  Board history[60];
  int length;
} Game;

Game Play(AI *black_ai, AI *white_ai) {
  Board board = OpeningBoard();
  Turn turn = BLACKS_TURN;
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

  CountPieces(&board, &game.black_count, &game.white_count);

  return game;
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

    if (game.black_count > game.white_count) {
      tournament.black_wins++;
    } else if (game.white_count > game.black_count) {
      tournament.white_wins++;
    } else {
      tournament.ties++;
    }
  }
  if (tournament.black_wins > tournament.white_wins) {
    printf("(black/white/tie): (%d/%d/%d)    Advantage BLACK by: %d\n",
           tournament.black_wins, tournament.white_wins, tournament.ties,
           tournament.black_wins - tournament.white_wins);
  } else if (tournament.white_wins > tournament.black_wins) {
    printf("(black/white/tie): (%d/%d/%d)    Advantage WHITE by: %d\n",
           tournament.black_wins, tournament.white_wins, tournament.ties,
           tournament.white_wins - tournament.black_wins);
  } else {
    printf("(black/white/tie): (%d/%d/%d)    TIED tournament!\n",
           tournament.black_wins, tournament.white_wins, tournament.ties);
  }

  return tournament;
}

#endif // REV_AI_H_
