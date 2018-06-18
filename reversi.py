import random


EMPTY = 0
WHITE = 1
BLACK = 2


def opening_board():
    return [
            [EMPTY] * 8,
            [EMPTY] * 8,
            [EMPTY] * 8,
            [EMPTY, EMPTY, EMPTY, WHITE, BLACK, EMPTY, EMPTY, EMPTY],
            [EMPTY, EMPTY, EMPTY, BLACK, WHITE, EMPTY, EMPTY, EMPTY],
            [EMPTY] * 8,
            [EMPTY] * 8,
            [EMPTY] * 8
            ]


def is_valid_move(board, row, col, color):
    assert 0 <= row < 8
    assert 0 <= col < 8
    assert color in [WHITE, BLACK]
    other = BLACK if color == WHITE else WHITE

    if board[row][col] != EMPTY:
        return False

    def check_direction(dr, dc):
        assert dr in [-1, 0, 1]
        assert dc in [-1, 0, 1]
        assert (dr, dc) != (0, 0)

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

    for dr, dc in [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]:
        if check_direction(dr, dc):
            return True
    return False


def all_valid_moves(board, color):
    moves = []
    for i in range(8):
        for j in range(8):
            if is_valid_move(board, i, j, color):
                moves.append((i, j))
    return moves


def make_move_(board, row, col, color):
    b = [[e for e in row] for row in board]
    return make_move(b, row, col, color)


def make_move(board, row, col, color):
    assert 0 <= row < 8
    assert 0 <= col < 8
    assert color in [WHITE, BLACK]
    assert board[row][col] == EMPTY
    other = BLACK if color == WHITE else WHITE

    board[row][col] = color

    def check_direction(dr, dc):
        assert dr in [-1, 0, 1]
        assert dc in [-1, 0, 1]
        assert (dr, dc) != (0, 0)

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

    for dr, dc in [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]:
        if check_direction(dr, dc):
            for l in range(1, 7):
                r = row + l * dr
                c = col + l * dc
                if board[r][c] == color:
                    break
                board[r][c] = color
    return board


def child_boards(board, color):
    moves = all_valid_moves(board, color)
    if len(moves) == 0:
        b = [[e for e in row] for row in board]
        return [(None, b)]
    boards = []
    for m in moves:
        b = make_move_(board, m[0], m[1], color)
        boards.append((m, b))
    return boards


def piece_count_heuristic(board):
    num_black = len([e for row in board for e in row if e == BLACK])
    num_white = len([e for row in board for e in row if e == WHITE])
    return num_white - num_black


def minimax_move(board, depth, color, heuristic):
    if depth == 0:
        return heuristic(board), None

    assert color in [BLACK, WHITE]
    other = BLACK if color == WHITE else WHITE

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



try:
    import pyximport; pyximport.install()
    import cyreversi
    # Override functions with the fast versions in cyreversi
    is_valid_move = cyreversi.is_valid_move
    make_move = cyreversi.make_move
except:
    pass


if __name__ == '__main__':
    b = opening_board()

    import time
    start = time.time()
    for i in range(30):
        v, m = minimax_move(b, 1, BLACK, piece_count_heuristic)
        print(v, m, 'black')
        if m is not None:
            b = make_move(b, m[0], m[1], BLACK)

        v, m = minimax_move(b, 4, WHITE, piece_count_heuristic)
        print(v, m, 'white')
        if m is not None:
            b = make_move(b, m[0], m[1], WHITE)
    print(time.time() - start)


