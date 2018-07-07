# cython: profile = True

from libc.stdint cimport uintptr_t, int8_t, int32_t
from libc.string cimport memcpy
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from cpython.array cimport array

cimport cython
from cython.parallel import prange, threadid

import random

import numpy as np


cimport containers


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


cdef struct Search:
    containers.BucketList* l1
    containers.BucketList* l2
    containers.BucketList* last




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

cdef void add_child_states_of(containers.BucketList *bl, State *state) nogil:

    cdef int i, j, k, l, v, di, dj, i2, j2, size

    cdef int other = BLACK if state.turn == WHITE else WHITE

    cdef bint done

    cdef State *child
    cdef int8_t *board = state.board

    for l in range(60):
        if state.history[l] == FUTURE_MOVE:
            if state.history[l-1] == PASS_MOVE and state.history[l-2] == PASS_MOVE:
                return

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
            child = <State *>containers.bucket_list_add_item(bl)
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
        child = <State *>containers.bucket_list_add_item(bl)
        copy_state(state, child)
        child.turn = other
        for l in range(60):
            if child.history[l] == FUTURE_MOVE:
                child.history[l] = PASS_MOVE
                break


cdef Search* make_search():
    cdef Search *search = <Search *>PyMem_Malloc(1 * sizeof(Search))
    search.l1 = containers.bucket_list_make(sizeof(State))
    search.l2 = containers.bucket_list_make(sizeof(State))
    search.last = NULL
    return search

cdef void del_search(Search* search):
    if search == NULL:
        return
    containers.bucket_list_del(search.l1)
    containers.bucket_list_del(search.l2)
    search.last = NULL
    PyMem_Free(search)

cdef void seed_search(Search* search, State* state=NULL):
    if search.l1.size != 0:
        return

    cdef State *tmp = <State *>containers.bucket_list_add_item(search.l1)

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
    cdef containers.BucketList *prev
    cdef containers.BucketList *curr
    cdef containers.BucketList *thread_bl[16]

    if num_threads == 1:
        print(search.last.size)
        for n in range(num):

            prev = search.last
            curr = search.l2 if search.l1 == search.last else search.l1
            containers.bucket_list_clear(curr)

            for i in range(prev.size):
                add_child_states_of(curr, <State *>containers.bucket_list_get_item(prev, i))

            search.last = curr

            print(search.last.size)

    else:
        for i in range(num_threads):
            thread_bl[i] = containers.bucket_list_make(sizeof(State))

        print(search.last.size)
        for n in range(num):

            prev = search.last
            curr = search.l2 if search.l1 == search.last else search.l1
            containers.bucket_list_clear(curr)
            for i in range(num_threads):
                containers.bucket_list_clear(thread_bl[i])

            for i in prange(prev.size, nogil=True, num_threads=num_threads):
                tid = threadid()
                add_child_states_of(thread_bl[tid], <State *>containers.bucket_list_get_item(prev, i))

            for i in range(num_threads):
                containers.bucket_list_transfer_data(curr, thread_bl[i])

            search.last = curr

            print(search.last.size)

        for i in range(num_threads):
            containers.bucket_list_del(thread_bl[i])


import time


cdef Search *search = make_search()
seed_search(search)
start = time.time()
search_generations(search, 10, num_threads=16)
print(time.time() - start)






























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


