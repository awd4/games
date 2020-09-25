#ifndef REV_BUCKET_LIST_H_
#define REV_BUCKET_LIST_H_

#include "board.h"

#include <stdbool.h>
#include <stdlib.h>

#define BUCKET_SIZE 500000

typedef struct BoardBucket BoardBucket;

typedef struct BoardBucket {
  BoardBucket *next;
  int count;
  Board boards[BUCKET_SIZE];
} BoardBucket;

typedef struct BoardListIter {
  BoardBucket *curr;
  int index;
} BoardListIter;

typedef struct BoardList {
  BoardBucket *head;
  BoardBucket *tail;
  BoardListIter iter;
} BoardList;

BoardList MakeBoardList() {
  BoardList list = {
      .head = NULL, .tail = NULL, .iter = {.curr = NULL, .index = 0}};
  return list;
}

void AddBucket(BoardList *list) {
  if (list->tail != NULL && list->tail->count < BUCKET_SIZE) {
    return;
  }

  BoardBucket *bucket = (BoardBucket *)malloc(sizeof(BoardBucket));
  bucket->next = NULL;
  bucket->count = 0;

  if (list->tail != NULL) {
    list->tail->next = bucket;
  }
  list->tail = bucket;

  if (list->iter.curr == NULL) {
    list->iter.curr = bucket;
    list->iter.index = 0;
  }
}

void AddBoard(BoardList *list, const Board *board) {
  if (list->head == NULL || list->tail == NULL) {
    AddBucket(list);
    list->head = list->tail;
  }
  if (list->tail->count >= BUCKET_SIZE) {
    AddBucket(list);
  }

  list->tail->boards[list->tail->count] = *board;
  list->tail->count++;
}

void AddChildBoards(BoardList *list, const ChildBoards *children) {
  for (int i = 0; i < children->count; ++i) {
    AddBoard(list, &children->boards[i]);
  }
}

void BoardListClear(BoardList *list) {
  list->iter.curr = NULL;
  list->iter.index = 0;

  BoardBucket *curr;
  while (list->head != NULL) {
    curr = list->head;
    list->head = curr->next;
    curr->next = NULL;
    curr->count = 0;
    free(curr);
  }
}

void PrintBoardList(BoardList *list) {
  BoardBucket *curr = list->tail;
  while (curr != NULL) {
    for (int i = 0; i < curr->count; ++i) {
      PrintBoard(&curr->boards[i]);
    }
    curr = curr->next;
  }
}

void ResetBoardIter(BoardList *list) {
  list->iter.curr = list->head;
  list->iter.index = 0;
}

// Returns NULL if at the end of the list.
Board *NextBoard(BoardList *list) {
  Board *found = NULL;
  if (list->iter.curr->count >= BUCKET_SIZE &&
      list->iter.index >= BUCKET_SIZE && list->iter.curr->next != NULL) {
    list->iter.curr = list->iter.curr->next;
    list->iter.index = 0;
  }
  if (list->iter.index < list->iter.curr->count) {
    found = &list->iter.curr->boards[list->iter.index];
    list->iter.index++;
  }
  return found;
}

Board *LastBoard(BoardList *list) {
  Board *found = NULL;
  if (list->tail != NULL) {
    found = &list->tail->boards[list->tail->count - 1];
  }
  return found;
}

uint32_t BoardListSize(BoardList *list) {
  BoardBucket *curr = list->head;
  uint32_t size = curr->count;
  while (curr = curr->next) {
    size += curr->count;
  }
  return size;
}

#endif // REV_BUCKET_LIST_H_
