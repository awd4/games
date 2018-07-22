# cython: profile = True

from libc.stdint cimport int8_t, int32_t, uint64_t
from libc.string cimport memcpy
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from cpython.array cimport array

cimport cython
from cython.parallel import prange, threadid

import numpy as np


cimport containers


cdef int EMPTY = 0
cdef int WHITE = 1
cdef int BLACK = 2

cdef int FUTURE_MOVE = -1
cdef int PASS_MOVE = -2

cdef uint64_t rcol = 72340172838076673ULL
cdef uint64_t lcol = 9259542123273814144ULL
cdef uint64_t not_rcol = 18374403900871474942Ull
cdef uint64_t not_lcol = 9187201950435737471ULL


# Game Data
#   turn
#       WHITE (1) or BLACK (2)
#   board
#       3 64-bit integers
#           1-bits in "empties" indicate EMPTY squares
#           1-bits in "whites" indicate WHITE squares
#           1-bits in "blacks" indicate BLACK squares
#
# Data Structures
#   buckets of game states
#   search tree:
#       root node contains the current game state
#       each child node represents one of the possible valid moves


cdef struct State:
    uint64_t empties
    uint64_t whites
    uint64_t blacks
    uint64_t turn


cdef struct Search:
    containers.BucketList* l1
    containers.BucketList* l2
    containers.BucketList* last




cdef void print_bits(uint64_t num, as_square=True):
    cdef uint64_t i
    b = [1 if ((num >> i) & 1) else 0 for i in range(64)]
    b = b[::-1]
    if as_square:
        print(np.array(b).reshape((8,8)))
    else:
        print(np.array(b))


cdef void print_state(State* state):
    cdef uint64_t e, w, b
    print('board:')
    e = state.empties
    w = state.whites
    b = state.blacks
    board = []
    for i in range(64):
        if (e >> i) % 2 == 1:
            board.append(EMPTY)
        elif (w >> i) % 2 == 1:
            board.append(WHITE)
        elif (b >> i) % 2 == 1:
            board.append(BLACK)
    board = board[::-1]
    print(np.array(board).reshape((8, 8)))
    print('turn: {}'.format(state.turn))


cdef void set_opening(State* state):
    state.empties = 18446743970227683327ULL
    state.whites = 68853694464ULL
    state.blacks = 34628173824ULL
    state.turn = BLACK


cdef void add_child_states_of(containers.BucketList *bl, State *state) nogil:

    cdef uint64_t up_moves, dn_moves, lf_moves, rt_moves, ur_moves, ul_moves, dr_moves, dl_moves
    cdef uint64_t moves

    cdef uint64_t e, w, b
    cdef uint64_t mv, flip, tmp

    cdef int i, s
    cdef State *child

    e = state.empties
    w = state.whites
    b = state.blacks


    cdef uint64_t c1, c2, c1_mv, c2_mv, c2_run

    if state.turn == WHITE:
        c1 = w
        c2 = b
    else:
        c1 = b
        c2 = w

    c1_mv = (c1 << 56)
    c2_mv = (c2 << 48)
    up_moves = c2_mv & c1_mv
    for i in range(5, 0, -1):
        c1_mv = (c1 << (8 * (i + 1)))
        c2_mv = (c2 << (8 * i))
        up_moves = c2_mv & (c1_mv | up_moves)
    up_moves = up_moves & e


    c1_mv = (c1 >> 56)
    c2_mv = (c2 >> 48)
    dn_moves = c2_mv & c1_mv
    for i in range(5, 0, -1):
        c1_mv = (c1 >> (8 * (i + 1)))
        c2_mv = (c2 >> (8 * i))
        dn_moves = c2_mv & (c1_mv | dn_moves)
    dn_moves = dn_moves & e


    c1_mv = not_rcol & (c1 << 1)
    c1_mv = not_rcol & (c1_mv << 1)
    c2_run = not_rcol & (c2 << 1)
    lf_moves = c2_run & c1_mv
    for i in range(1, 7):
        c2_run = c2_run & not_rcol & (c2_run << 1)
        c1_mv = not_rcol & (c1_mv << 1)
        lf_moves = lf_moves | c2_run & c1_mv
    lf_moves = lf_moves & e


    c1_mv = not_lcol & (c1 >> 1)
    c1_mv = not_lcol & (c1_mv >> 1)
    c2_run = not_lcol & (c2 >> 1)
    rt_moves = c2_run & c1_mv
    for i in range(1, 7):
        c2_run = c2_run & not_lcol & (c2_run >> 1)
        c1_mv = not_lcol & (c1_mv >> 1)
        rt_moves = rt_moves | c2_run & c1_mv
    rt_moves = rt_moves & e


    c1_mv = not_lcol & (c1 << 7)
    c1_mv = not_lcol & (c1_mv << 7)
    c2_run = not_lcol & (c2 << 7)
    ur_moves = c2_run & c1_mv
    for i in range(1, 7):
        c2_run = c2_run & not_lcol & (c2_run << 7)
        c1_mv = not_lcol & (c1_mv << 7)
        ur_moves = ur_moves | c2_run & c1_mv
    ur_moves = ur_moves & e


    c1_mv = not_rcol & (c1 << 9)
    c1_mv = not_rcol & (c1_mv << 9)
    c2_run = not_rcol & (c2 << 9)
    ul_moves = c2_run & c1_mv
    for i in range(1, 7):
        c2_run = c2_run & not_rcol & (c2_run << 9)
        c1_mv = not_rcol & (c1_mv << 9)
        ul_moves = ul_moves | c2_run & c1_mv
    ul_moves = ul_moves & e


    c1_mv = not_lcol & (c1 >> 9)
    c1_mv = not_lcol & (c1_mv >> 9)
    c2_run = not_lcol & (c2 >> 9)
    dr_moves = c2_run & c1_mv
    for i in range(1, 7):
        c2_run = c2_run & not_lcol & (c2_run >> 9)
        c1_mv = not_lcol & (c1_mv >> 9)
        dr_moves = dr_moves | c2_run & c1_mv
    dr_moves = dr_moves & e


    c1_mv = not_rcol & (c1 >> 7)
    c1_mv = not_rcol & (c1_mv >> 7)
    c2_run = not_rcol & (c2 >> 7)
    dl_moves = c2_run & c1_mv
    for i in range(1, 7):
        c2_run = c2_run & not_rcol & (c2_run >> 7)
        c1_mv = not_rcol & (c1_mv >> 7)
        dl_moves = dl_moves | c2_run & c1_mv
    dl_moves = dl_moves & e


    moves = up_moves | dn_moves | lf_moves | rt_moves | ur_moves | ul_moves | dr_moves | dl_moves


    if moves == 0:
        child = <State *>containers.bucket_list_add_item(bl)
        child[0] = state[0]   # OR memcpy(child, state, sizeof(State))
        if child.turn == WHITE:
            child.turn = BLACK
        else:
            child.turn = WHITE
        return


    for i in range(64):
        mv = (1ULL << i)
        if (moves & mv) == 0:
            continue

        flip = mv

        if mv & up_moves:
            tmp = mv >> 8
            while tmp & c2:
                flip = flip | tmp
                tmp = tmp >> 8
        if mv & dn_moves:
            tmp = mv << 8
            while tmp & c2:
                flip = flip | tmp
                tmp = tmp << 8
        if mv & lf_moves:
            tmp = mv >> 1
            while tmp & c2:
                flip = flip | tmp
                tmp = tmp >> 1
        if mv & rt_moves:
            tmp = mv << 1
            while tmp & c2:
                flip = flip | tmp
                tmp = tmp << 1
        if mv & ur_moves:
            tmp = mv >> 7
            while tmp & c2:
                flip = flip | tmp
                tmp = tmp >> 7
        if mv & ul_moves:
            tmp = mv >> 9
            while tmp & c2:
                flip = flip | tmp
                tmp = tmp >> 9
        if mv & dr_moves:
            tmp = mv << 9
            while tmp & c2:
                flip = flip | tmp
                tmp = tmp << 9
        if mv & dl_moves:
            tmp = mv << 7
            while tmp & c2:
                flip = flip | tmp
                tmp = tmp << 7


        child = <State *>containers.bucket_list_add_item(bl)
        child[0] = state[0]   # OR memcpy(child, state, sizeof(State))

        child.empties = state.empties & ~mv
        if state.turn == WHITE:
            child.whites = state.whites | flip
            child.blacks = state.blacks & ~flip
            child.turn = BLACK
        else:
            child.whites = state.whites & ~flip
            child.blacks = state.blacks | flip
            child.turn = WHITE


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
        tmp[0] = state[0]   # OR memcpy(tmp, state, sizeof(State))

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

    cdef State *s

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


# TODO: there is a segfault that happens when the ITEMS_PER_BUCKET is too low and
# multithreading is being used.
#
# NOTE: for single-threads a large ITEMS_PER_BUCKET really helps speed things up,
# but for multi-threading a lower ITEMS_PER_BUCKET is better.


cdef Search *search = make_search()
seed_search(search)
start = time.time()
search_generations(search, 11, num_threads=16)
print(time.time() - start)


#cdef State s
#cdef containers.BucketList *bl = containers.bucket_list_make(sizeof(State))

#set_opening(&s)
#print_state(&s)

#print(bl.size)
#add_child_states_of(bl, &s)
#print(bl.size)

#cdef Search *search = make_search()
#seed_search(search)

