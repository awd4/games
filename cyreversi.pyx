from cpython.array cimport array
import random


cdef int EMPTY = 0
cdef int WHITE = 1
cdef int BLACK = 2


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

