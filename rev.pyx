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

    cdef uint64_t w_ups[7]
    cdef uint64_t w_dns[7]
    cdef uint64_t w_lfs[7]
    cdef uint64_t w_rts[7]
    cdef uint64_t w_urs[7]
    cdef uint64_t w_uls[7]
    cdef uint64_t w_drs[7]
    cdef uint64_t w_dls[7]
    cdef uint64_t b_ups[7]
    cdef uint64_t b_dns[7]
    cdef uint64_t b_lfs[7]
    cdef uint64_t b_rts[7]
    cdef uint64_t b_urs[7]
    cdef uint64_t b_uls[7]
    cdef uint64_t b_drs[7]
    cdef uint64_t b_dls[7]
    cdef uint64_t up_moves, dn_moves, lf_moves, rt_moves, ur_moves, ul_moves, dr_moves, dl_moves
    cdef uint64_t moves

    cdef uint64_t e, w, b
    cdef uint64_t mv, flip, tmp, other

    cdef int i, s
    cdef State *child

    e = state.empties
    w = state.whites
    b = state.blacks

    w_lfs[0] = not_rcol & (w << 1)
    w_rts[0] = not_lcol & (w >> 1)
    w_urs[0] = not_lcol & (w << 7)
    w_uls[0] = not_rcol & (w << 9)
    w_drs[0] = not_lcol & (w >> 9)
    w_dls[0] = not_rcol & (w >> 7)
    b_lfs[0] = not_rcol & (b << 1)
    b_rts[0] = not_lcol & (b >> 1)
    b_urs[0] = not_lcol & (b << 7)
    b_uls[0] = not_rcol & (b << 9)
    b_drs[0] = not_lcol & (b >> 9)
    b_dls[0] = not_rcol & (b >> 7)
    for i in range(7):
        s = 8 * (i + 1)
        w_ups[i] = (w << s)
        w_dns[i] = (w >> s)
        b_ups[i] = (b << s)
        b_dns[i] = (b >> s)
        if i == 0:
            continue
        w_lfs[i] = not_rcol & (w_lfs[i-1] << 1)
        w_rts[i] = not_lcol & (w_rts[i-1] >> 1)
        w_urs[i] = not_lcol & (w_urs[i-1] << 7)
        w_uls[i] = not_rcol & (w_uls[i-1] << 9)
        w_drs[i] = not_lcol & (w_drs[i-1] >> 9)
        w_dls[i] = not_rcol & (w_dls[i-1] >> 7)
        b_lfs[i] = not_rcol & (b_lfs[i-1] << 1)
        b_rts[i] = not_lcol & (b_rts[i-1] >> 1)
        b_urs[i] = not_lcol & (b_urs[i-1] << 7)
        b_uls[i] = not_rcol & (b_uls[i-1] << 9)
        b_drs[i] = not_lcol & (b_drs[i-1] >> 9)
        b_dls[i] = not_rcol & (b_dls[i-1] >> 7)

    if state.turn == WHITE:
        up_moves = e & b_ups[0] & (w_ups[1] | b_ups[1] & (w_ups[2] | b_ups[2] & (w_ups[3] | b_ups[3] & (w_ups[4] | b_ups[4] & (w_ups[5] | b_ups[5] & w_ups[6])))))
        dn_moves = e & b_dns[0] & (w_dns[1] | b_dns[1] & (w_dns[2] | b_dns[2] & (w_dns[3] | b_dns[3] & (w_dns[4] | b_dns[4] & (w_dns[5] | b_dns[5] & w_dns[6])))))
        lf_moves = e & b_lfs[0] & (w_lfs[1] | b_lfs[1] & (w_lfs[2] | b_lfs[2] & (w_lfs[3] | b_lfs[3] & (w_lfs[4] | b_lfs[4] & (w_lfs[5] | b_lfs[5] & w_lfs[6])))))
        rt_moves = e & b_rts[0] & (w_rts[1] | b_rts[1] & (w_rts[2] | b_rts[2] & (w_rts[3] | b_rts[3] & (w_rts[4] | b_rts[4] & (w_rts[5] | b_rts[5] & w_rts[6])))))
        ur_moves = e & b_urs[0] & (w_urs[1] | b_urs[1] & (w_urs[2] | b_urs[2] & (w_urs[3] | b_urs[3] & (w_urs[4] | b_urs[4] & (w_urs[5] | b_urs[5] & w_urs[6])))))
        ul_moves = e & b_uls[0] & (w_uls[1] | b_uls[1] & (w_uls[2] | b_uls[2] & (w_uls[3] | b_uls[3] & (w_uls[4] | b_uls[4] & (w_uls[5] | b_uls[5] & w_uls[6])))))
        dr_moves = e & b_drs[0] & (w_drs[1] | b_drs[1] & (w_drs[2] | b_drs[2] & (w_drs[3] | b_drs[3] & (w_drs[4] | b_drs[4] & (w_drs[5] | b_drs[5] & w_drs[6])))))
        dl_moves = e & b_dls[0] & (w_dls[1] | b_dls[1] & (w_dls[2] | b_dls[2] & (w_dls[3] | b_dls[3] & (w_dls[4] | b_dls[4] & (w_dls[5] | b_dls[5] & w_dls[6])))))
    else:
        up_moves = e & w_ups[0] & (b_ups[1] | w_ups[1] & (b_ups[2] | w_ups[2] & (b_ups[3] | w_ups[3] & (b_ups[4] | w_ups[4] & (b_ups[5] | w_ups[5] & b_ups[6])))))
        dn_moves = e & w_dns[0] & (b_dns[1] | w_dns[1] & (b_dns[2] | w_dns[2] & (b_dns[3] | w_dns[3] & (b_dns[4] | w_dns[4] & (b_dns[5] | w_dns[5] & b_dns[6])))))
        lf_moves = e & w_lfs[0] & (b_lfs[1] | w_lfs[1] & (b_lfs[2] | w_lfs[2] & (b_lfs[3] | w_lfs[3] & (b_lfs[4] | w_lfs[4] & (b_lfs[5] | w_lfs[5] & b_lfs[6])))))
        rt_moves = e & w_rts[0] & (b_rts[1] | w_rts[1] & (b_rts[2] | w_rts[2] & (b_rts[3] | w_rts[3] & (b_rts[4] | w_rts[4] & (b_rts[5] | w_rts[5] & b_rts[6])))))
        ur_moves = e & w_urs[0] & (b_urs[1] | w_urs[1] & (b_urs[2] | w_urs[2] & (b_urs[3] | w_urs[3] & (b_urs[4] | w_urs[4] & (b_urs[5] | w_urs[5] & b_urs[6])))))
        ul_moves = e & w_uls[0] & (b_uls[1] | w_uls[1] & (b_uls[2] | w_uls[2] & (b_uls[3] | w_uls[3] & (b_uls[4] | w_uls[4] & (b_uls[5] | w_uls[5] & b_uls[6])))))
        dr_moves = e & w_drs[0] & (b_drs[1] | w_drs[1] & (b_drs[2] | w_drs[2] & (b_drs[3] | w_drs[3] & (b_drs[4] | w_drs[4] & (b_drs[5] | w_drs[5] & b_drs[6])))))
        dl_moves = e & w_dls[0] & (b_dls[1] | w_dls[1] & (b_dls[2] | w_dls[2] & (b_dls[3] | w_dls[3] & (b_dls[4] | w_dls[4] & (b_dls[5] | w_dls[5] & b_dls[6])))))
#up_moves = b_ups[5] & w_ups[6]
#for i in range(5, 0, -1):
#    up_moves = up_moves | w_ups[i]
#    print('{:064b}'.format(up_moves))
#    up_moves = up_moves & b_ups[i-1]
#    print('{:064b}'.format(up_moves))

    moves = up_moves | dn_moves | lf_moves | rt_moves | ur_moves | ul_moves | dr_moves | dl_moves

    if moves == 0:
        child = <State *>containers.bucket_list_add_item(bl)
        child[0] = state[0]   # OR memcpy(child, state, sizeof(State))
        if child.turn == WHITE:
            child.turn = BLACK
        else:
            child.turn = WHITE
        return

    if state.turn == WHITE:
        other = b
    else:
        other = w

    for i in range(64):
        mv = (1ULL << i)
        if (moves & mv) == 0:
            continue

        flip = mv

        if mv & up_moves:
            tmp = mv >> 8
            while tmp & other:
                flip = flip | tmp
                tmp = tmp >> 8
        if mv & dn_moves:
            tmp = mv << 8
            while tmp & other:
                flip = flip | tmp
                tmp = tmp << 8
        if mv & lf_moves:
            tmp = mv >> 1
            while tmp & other:
                flip = flip | tmp
                tmp = tmp >> 1
        if mv & rt_moves:
            tmp = mv << 1
            while tmp & other:
                flip = flip | tmp
                tmp = tmp << 1
        if mv & ur_moves:
            tmp = mv >> 7
            while tmp & other:
                flip = flip | tmp
                tmp = tmp >> 7
        if mv & ul_moves:
            tmp = mv >> 9
            while tmp & other:
                flip = flip | tmp
                tmp = tmp >> 9
        if mv & dr_moves:
            tmp = mv << 9
            while tmp & other:
                flip = flip | tmp
                tmp = tmp << 9
        if mv & dl_moves:
            tmp = mv << 7
            while tmp & other:
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

#        with gil:
#            if np.random.rand() < 0.1:
#                print_state(state)
#                print('|')
#                print('V')
#                print_state(child)
#                print('')

#        with gil:
#            print_state(child)


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


cdef Search *search = make_search()
seed_search(search)
start = time.time()
search_generations(search, 9, num_threads=1)
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

