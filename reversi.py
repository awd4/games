
from pyreversi import *
try:
    import pyximport; pyximport.install()
    import cyreversi
    from cyreversi import *
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


