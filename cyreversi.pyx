# cython: profile = True

from libc.stdint cimport int8_t, int32_t
from libc.string cimport memcpy
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from cpython.array cimport array

from cython.parallel import prange, threadid

cimport cython
import random

import numpy as np


DEF ITEMS_PER_BUCKET = 10000

cdef int EMPTY = 0
cdef int WHITE = 1
cdef int BLACK = 2

cdef int FUTURE_MOVE = -1
cdef int PASS_MOVE = -2


# Game Data
#   turn
#       WHITE (1) or BLACK (2)
#   board
#       64 8-bit integers
#           0 indicates EMPTY
#           1 indicates WHITE
#           2 indicates BLACK
#   valid-moves (do we need this?)
#       64 8-bit integers
#           0 indicates an invalid move
#           1 indicates a valid move
#   history:
#       60 8-bit integers
#           0-63 indicate the position of a move
#           -1 indicates the move hasn't happened yet
#           -2 indicates the turn was skipped due to no valid moves being avaialable
#
# Data Structures
#   buckets of game states
#   search tree:
#       root node contains the current game state
#       each child node represents one of the possible valid moves


cdef struct State:
    int8_t board[64]
    int8_t history[60]
    int32_t turn


cdef struct Bucket:
    Bucket* next_bucket
    State items[ITEMS_PER_BUCKET]


cdef struct BucketList:
    int size
    Bucket *head_bucket


cdef struct Search:
    BucketList* l1
    BucketList* l2
    BucketList* last



cdef BucketList* make_bucket_list():
    cdef BucketList *bl = <BucketList *>PyMem_Malloc(1 * sizeof(BucketList))
    bl.head_bucket = <Bucket *>PyMem_Malloc(1 * sizeof(Bucket))
    bl.head_bucket.next_bucket = NULL
    bl.size = 0
    return bl

cdef void del_bucket_list(BucketList* bl):
    cdef Bucket *curr
    cdef Bucket *tmp
    if bl == NULL:
        return
    bl.size = 0
    curr = bl.head_bucket
    while curr != NULL:
        tmp = curr.next_bucket
        PyMem_Free(curr)
        curr = tmp
    bl.head_bucket = NULL
    PyMem_Free(bl)

cdef void clear_bucket_list(BucketList* bl):
    bl.size = 0

cdef void add_bucket(BucketList* bl) nogil:
    cdef Bucket *curr
    curr = bl.head_bucket
    while curr.next_bucket != NULL:
        curr = curr.next_bucket
    with gil:
        curr.next_bucket = <Bucket *>PyMem_Malloc(1 * sizeof(Bucket))
    curr.next_bucket.next_bucket = NULL

@cython.cdivision(True)
cdef State* next_state(BucketList* bl) nogil:
    cdef Bucket *curr = bl.head_bucket
    cdef int i = bl.size
    while i >= ITEMS_PER_BUCKET:
        i -= ITEMS_PER_BUCKET
        if curr.next_bucket == NULL:
            add_bucket(bl)
        curr = curr.next_bucket
    bl.size += 1
    return &curr.items[i]

@cython.cdivision(True)
cdef State* state_at(BucketList* bl, int i) nogil:
    if i < 0 or i >= bl.size:
        return NULL
    cdef Bucket *curr = bl.head_bucket
    while i >= ITEMS_PER_BUCKET:
        i -= ITEMS_PER_BUCKET
        if curr.next_bucket == NULL:
            return NULL
        curr = curr.next_bucket
    return &curr.items[i]

@cython.cdivision(True)
cdef void transfer_data(BucketList* l1, BucketList* l2):
    cdef int i, j, l1_last_size, l2_last_size
    cdef Bucket *l1_last = l1.head_bucket
    cdef Bucket *l2_last = l2.head_bucket
    cdef Bucket *tmp = NULL
    cdef Bucket *tmp2 = NULL
    cdef State* s

    if l2.size <= 0:
        return

    l1_last_size = l1.size
    while l1_last.next_bucket != NULL and l1_last_size > ITEMS_PER_BUCKET:
        l1_last = l1_last.next_bucket
        l1_last_size -= ITEMS_PER_BUCKET

    l2_last_size = l2.size
    while l2_last.next_bucket != NULL:
        l2_last = l2_last.next_bucket
        l2_last_size -= ITEMS_PER_BUCKET

    # prune off any extra, unused buckets in l1
    if l1_last.next_bucket != NULL:
        tmp = l1_last.next_bucket
        while tmp != NULL:
            tmp2 = tmp.next_bucket
            PyMem_Free(tmp)
            tmp = tmp2

    # switch data from l2 into l1
    l1_last.next_bucket = l2.head_bucket
    l1.size += l2.size

    # make l2 empty, but usable
    l2.head_bucket = <Bucket *>PyMem_Malloc(1 * sizeof(Bucket))
    l2.head_bucket.next_bucket = NULL
    l2.size = 0

    tmp = l2_last
    j = l2_last_size - 1
    for i in range(l1_last_size, ITEMS_PER_BUCKET):
        copy_state(&tmp.items[j], &l1_last.items[i])
        j -= 1
        if j < 0:
            # move to the second-to-last bucket, since the last is now empty
            tmp = l1.head_bucket
            while tmp.next_bucket != l2_last:
                tmp = tmp.next_bucket
            j = ITEMS_PER_BUCKET - 1


cdef void print_state(State* state):
    cdef int i
    print('board:')
    print(np.array([int(state.board[i]) for i in range(64)]).reshape((8, 8)))
    print('history: {} turn: {}'.format([int(state.history[i]) for i in range(60) if int(state.history[i]) != FUTURE_MOVE], state.turn))


cdef void set_opening(State* state):
    cdef int i = 0
    for i in range(27):
        state.board[i] = EMPTY
    state.board[27] = WHITE
    state.board[28] = BLACK
    for i in range(29, 35):
        state.board[i] = EMPTY
    state.board[35] = BLACK
    state.board[36] = WHITE
    for i in range(37, 64):
        state.board[i] = EMPTY
    for i in range(60):
        state.history[i] = FUTURE_MOVE
    state.turn = BLACK

cdef void copy_state(State *src, State *dst) nogil:
    memcpy(dst, src, sizeof(State))

cdef void add_child_states_of(BucketList *bl, State *state) nogil:

    cdef int i, j, k, l, v, di, dj, i2, j2, size

    cdef int other = BLACK if state.turn == WHITE else WHITE

    cdef bint done

    cdef State *child
    cdef int8_t *board = state.board

    size = bl.size

    for i in range(8):
        for j in range(8):

            k = i * 8 + j

            if board[k] != EMPTY:
                continue

            done = False

            for di in range(-1, 2):
                for dj in range(-1, 2):

                    if di == 0 and dj == 0:
                        continue

                    for l in range(1, 7):

                        i2 = i + l * di
                        j2 = j + l * dj

                        if i2 < 0 or i2 > 7 or j2 < 0 or j2 > 7:
                            break

                        v = board[i2 * 8 + j2]

                        if l == 1 and v != other:
                            break

                        if v == EMPTY:
                            break

                        elif v == state.turn:   # found a valid move
                            done = True
                            break

                    if done:
                        break

                if done:
                    break

            if not done:
                continue

            # create the child state
            child = next_state(bl)
            copy_state(state, child)
            child.board[k] = state.turn
            child.turn = other
            for l in range(60):
                if child.history[l] == FUTURE_MOVE:
                    child.history[l] = k
                    break

            done = False

            for di in range(-1, 2):
                for dj in range(-1, 2):

                    if di == 0 and dj == 0:
                        continue

                    for l in range(1, 7):

                        i2 = i + l * di
                        j2 = j + l * dj

                        if i2 < 0 or i2 > 7 or j2 < 0 or j2 > 7:
                            break

                        v = child.board[i2 * 8 + j2]

                        if v == other:
                            child.board[i2 * 8 + j2] = state.turn
                        else:
                            done = True
                            break

    # handle the case where a player cannot make a move
    if bl.size == size:
        child = next_state(bl)
        copy_state(state, child)
        child.turn = other
        for l in range(60):
            if child.history[l] == FUTURE_MOVE:
                child.history[l] = PASS_MOVE
                break


cdef Search* make_search():
    cdef Search *search = <Search *>PyMem_Malloc(1 * sizeof(Search))
    search.l1 = make_bucket_list()
    search.l2 = make_bucket_list()
    search.last = NULL
    return search

cdef void del_search(Search* search):
    if search == NULL:
        return
    del_bucket_list(search.l1)
    del_bucket_list(search.l2)
    search.last = NULL
    PyMem_Free(search)

cdef void seed_search(Search* search, State* state=NULL):
    if search.l1.size != 0:
        return

    cdef State *tmp = next_state(search.l1)

    if state == NULL:
        set_opening(tmp)
    else:
        copy_state(state, tmp)

    search.last = search.l1

cdef int search_generations(Search* search, int num, int num_threads=4):
    if num <= 0 or search.last == NULL:
        return 1
    if not (1 <= num_threads <= 16):
        return 2

    cdef int i, n
    cdef long tid
    cdef BucketList *prev
    cdef BucketList *curr
    cdef BucketList *thread_bl[16]

    if num_threads == 1:
        print(search.last.size)
        for n in range(num):

            prev = search.last
            curr = search.l2 if search.l1 == search.last else search.l1
            clear_bucket_list(curr)

            for i in range(prev.size):
                add_child_states_of(curr, state_at(prev, i))

            search.last = curr

            print(search.last.size)

    else:
        for i in range(num_threads):
            thread_bl[i] = make_bucket_list()

        print(search.last.size)
        for n in range(num):

            prev = search.last
            curr = search.l2 if search.l1 == search.last else search.l1
            clear_bucket_list(curr)
            for i in range(num_threads):
                clear_bucket_list(thread_bl[i])

            for i in prange(prev.size, nogil=True, num_threads=num_threads):
                tid = threadid()
                add_child_states_of(thread_bl[tid], state_at(prev, i))

            for i in range(num_threads):
                transfer_data(curr, thread_bl[i])

            search.last = curr

            print(search.last.size)

        for i in range(num_threads):
            del_bucket_list(thread_bl[i])


import time


cdef Search *search = make_search()
seed_search(search)
start = time.time()
search_generations(search, 10, num_threads=16)
print(time.time() - start)


#cdef BucketList *bl1 = make_bucket_list()
#cdef State *s0
#
#s0 = next_state(bl1)
#set_opening(s0)
#add_child_states_of(bl1, s0)
#
#for i in range(bl1.size):
#    s0 = state_at(bl1, i)
#    print_state(s0)
#print(bl1.size)






























cpdef opening_board():
    cdef int[:] board = array('i', \
            [EMPTY] * 27 + \
            [WHITE, BLACK] + \
            [EMPTY] * 6 + \
            [BLACK, WHITE] + \
            [EMPTY] * 27)
    return board


cdef check_direction(int[:] board, int row, int col, int color, int dr, int dc):
    assert -1 <= dr <= 1
    assert -1 <= dc <= 1
    assert not (dr == 0 and dc == 0)

    cdef int r, c, l, other

    other = BLACK if color == WHITE else WHITE

    for l in range(1, 7):
        r = row + l * dr
        c = col + l * dc
        if r < 0 or r >= 8 or c < 0 or c >= 8:
            return False
        if l == 1 and board[r * 8 + c] != other:
            return False
        if board[r * 8 + c] == EMPTY:
            return False
        if board[r * 8 + c] == color:
            return True


cpdef is_valid_move(int[:] board, int row, int col, int color):
    assert 0 <= row < 8
    assert 0 <= col < 8
    assert color in [WHITE, BLACK]

    if board[row * 8 + col] != EMPTY:
        return False

    cdef int dr, dc

    for dr in range(-1, 2):
        for dc in range(-1, 2):
            if dr == 0 and dc == 0:
                continue
            if check_direction(board, row, col, color, dr, dc):
                return True
    return False


cpdef all_valid_moves(int[:] board, int color):

    cdef int i, j

    moves = []
    for i in range(8):
        for j in range(8):
            if is_valid_move(board, i, j, color):
                moves.append((i, j))

    return moves


cpdef make_move_(int[:] board, int row, int col, int color):
    cdef int[:] b = board.copy()
    return make_move(b, row, col, color)


cpdef make_move(int[:] board, int row, int col, int color):
    assert 0 <= row < 8
    assert 0 <= col < 8
    assert color in [WHITE, BLACK]
    assert board[row * 8 + col] == EMPTY

    cdef int dr, dc, other, r, c, l

    other = BLACK if color == WHITE else WHITE

    board[row * 8 + col] = color

    for dr in range(-1, 2):
        for dc in range(-1, 2):
            if dr == 0 and dc == 0:
                continue
            if check_direction(board, row, col, color, dr, dc):
                for l in range(1, 7):
                    r = row + l * dr
                    c = col + l * dc
                    if board[r * 8 + c] == color:
                        break
                    board[r * 8 + c] = color
    return board


cpdef child_boards(int[:] board, int color):
    moves = all_valid_moves(board, color)
    if len(moves) == 0:
        b = board.copy()
        return [(None, b)]
    boards = []
    for m in moves:
        b = make_move_(board, m[0], m[1], color)
        boards.append((m, b))
    return boards


cpdef piece_count_heuristic(int[:] board):

    cdef int i, val
    cdef int num_black = 0
    cdef int num_white = 0

    for i in range(board.shape[0]):
        val = board[i]
        if val == BLACK:
            num_black += 1
        elif val == WHITE:
            num_white += 1

    return num_white - num_black


cpdef minimax_move(int[:] board, int depth, int color, heuristic):
    if depth == 0:
        return heuristic(board), None

    assert color == BLACK or color == WHITE
    cdef int other = BLACK if color == WHITE else WHITE

    children = child_boards(board, color)
    move_candidates = []

    if color == WHITE:
        best_value = float('-inf')
        best_move = None
        for m, b in children:
            v, _ = minimax_move(b, depth-1, other, heuristic)
            if v > best_value:
                best_value = v
                move_candidates = [m]
            elif v == best_value:
                move_candidates.append(m)
        best_move = random.choice(move_candidates)
        return best_value, best_move

    else:
        best_value = float('inf')
        best_move = None
        for m, b in children:
            v, _ = minimax_move(b, depth-1, other, heuristic)
            if v < best_value:
                best_value = v
                move_candidates = [m]
            elif v == best_value:
                move_candidates.append(m)
        best_move = random.choice(move_candidates)
        return best_value, best_move


