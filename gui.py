import os
import gzip
import struct

import tkinter as tk

import netpbm
import reversi
from reversi import EMPTY, WHITE, BLACK


class GameArt:

    def __init__(self):
        self.pieces = None
        self.empty_board = None
        self.canvas = None


def create_game_art(resources_directory):
    rdir = resources_directory
    all_pieces = netpbm.load(os.path.join(rdir, 'reversi.pieces.ppm'))

    w = all_pieces.width // 2
    h = all_pieces.height
    c = all_pieces.num_channels

    empty = netpbm.empty(w, h)
    empty.paint_patch(0, 0, empty.width, empty.height, all_pieces.data[:3])

    pieces = {}
    pieces[EMPTY] = empty
    pieces[WHITE] = all_pieces.patch(0, 0, w, h)
    pieces[BLACK] = all_pieces.patch(w, 0, w, h)

    empty_board = netpbm.empty(2 + 8 * (w + 2), 2 + 8 * (h + 2))
    empty_board.paint_patch(0, 0, empty.width, empty.height, (0, 0, 0))
    for i in range(8):
        for j in range(8):
            empty_board.overwrite_patch(2 + j * (w + 2), 2 + i * (h + 2), empty)

    canvas = empty_board.copy()

    art = GameArt()
    art.pieces = pieces
    art.empty_board = empty_board
    art.canvas = canvas

    return art


def draw_board(art, board):
    art.canvas.overwrite_patch(0, 0, art.empty_board)

    c = art.canvas.num_channels
    w = art.pieces[WHITE].width     # width of piece
    h = art.pieces[WHITE].height    # height of piece

    r1 = art.canvas.row_size()
    for i in range(8):
        for j in range(8):

            if board[i * 8 + j] == EMPTY:
                continue

            x = 2 + (w + 2) * j
            y = 2 + (h + 2) * i
            ptype = board[i * 8 + j]
            p = art.pieces[ptype]

            art.canvas.overwrite_patch(x, y, p)


class GUI():

    def __init__(self):
        self.frame = None


color = BLACK
def create_gui():

    def on_key(event):
        global color
        b = board

        other = BLACK if color == WHITE else WHITE

        depth = 6 if color == WHITE else 4
        v, m = reversi.minimax_move(b, depth, color, reversi.piece_count_heuristic)
        if m is not None:
            b = reversi.make_move(b, m[0], m[1], color)

        color = other

        draw_board(art, b)

        im = art.canvas
        photo = tk.PhotoImage(width=im.width, height=im.height, data=im.raw_bytes(), format='PPM')
        label.configure(image=photo)
        label.image = photo

    g = GUI()

    frame = tk.Frame()
    frame.bind('<Key>', on_key)
    frame.focus_set()
    frame.pack()

    art = create_game_art('ims/')
    board = reversi.opening_board()

    draw_board(art, board)
    im = art.canvas

    photo = tk.PhotoImage(width=im.width, height=im.height, data=im.raw_bytes(), format='PPM')

    label = tk.Label(image=photo, bg='white')
    label.image = photo # keep a reference so it is not garbage-collected
    label.pack()

    g.frame = frame
    return g


if __name__ == '__main__':
    wnd = create_gui()
    wnd.frame.mainloop()


