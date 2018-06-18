
cdef int EMPTY = 0
cdef int WHITE = 1
cdef int BLACK = 2


cdef check_direction(list board, int row, int col, int color, int dr, int dc):
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
        if l == 1 and board[r][c] != other:
            return False
        if board[r][c] == EMPTY:
            return False
        if board[r][c] == color:
            return True


cpdef is_valid_move(list board, int row, int col, int color):
    assert 0 <= row < 8
    assert 0 <= col < 8
    assert color in [WHITE, BLACK]

    if board[row][col] != EMPTY:
        return False

    cdef int dr, dc

    for dr in range(-1, 2):
        for dc in range(-1, 2):
            if dr == 0 and dc == 0:
                continue
            if check_direction(board, row, col, color, dr, dc):
                return True
    return False


