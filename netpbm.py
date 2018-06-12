# Supports the Netpbm image formats PPM and PGM.
# Only supports max-values of exactly 255.
#
# http://netpbm.sourceforge.net/doc/ppm.html
# http://netpbm.sourceforge.net/doc/pgm.html


class Netpbm:

    def __init__(self):
        self.width = None
        self.height = None
        self.num_channels = None
        self.max_val = None
        self.data = None

    def raw_bytes(self):
        im_type = {1: 'P5', 3: 'P6'}[self.num_channels]
        return bytes('{} {} {} 255 '.format(im_type, self.width, self.height), encoding='ascii') + bytes(self.data)

    def copy(self):
        return self.patch(0, 0, self.width, self.height)

    def row_size(self):
        return self.width * self.num_channels

    def overwrite_patch(self, x, y, other):
        assert self.num_channels == other.num_channels
        assert self.max_val == other.max_val
        self._check_patch_validity(x, y, other.width, other.height)

        c = self.num_channels

        r1 = self.row_size()
        r2 = other.row_size()
        for i in range(other.height):
            i1 = (y + i) * r1 + x * c
            i2 = i * r2
            self.data[i1:i1 + r2] = other.data[i2:i2 + r2]

    def patch(self, x, y, w, h):
        self._check_patch_validity(x, y, w, h)

        c = self.num_channels

        im = Netpbm()
        im.width = w
        im.height = h
        im.num_channels = c
        im.max_val = self.max_val
        im.data = bytearray(w * h * c)

        r1 = self.row_size()
        r2 = im.row_size()
        for i in range(h):
            i1 = (y + i) * r1 + x * c
            i2 = i * r2
            im.data[i2:i2 + r2] = self.data[i1:i1 + r2]

        return im

    def paint_patch(self, x, y, w, h, color):
        self._check_patch_validity(x, y, w, h)

        c = self.num_channels

        if c == 1 and not hasattr(color, '__len__'):
            color = [color]
        assert len(color) == c
        assert all([0 <= c <= 255 for c in color])
        row_color = color * w

        r1 = self.row_size()
        r2 = w * c
        for i in range(h):
            i1 = (y + i) * r1 + x * c
            self.data[i1:i1 + r2] = row_color

    def _check_patch_validity(self, x, y, w, h):
        assert 0 <= x < self.width
        assert 0 <= y < self.height
        assert 0 < w <= self.width - x
        assert 0 < h <= self.height - y


def empty(width, height, num_channels=3):

    assert 0 < width <= 8192
    assert 0 < height <= 8192
    assert num_channels in [1, 3]

    im = Netpbm()
    im.width = width
    im.height = height
    im.num_channels = num_channels
    im.max_val = 255
    im.data = bytearray(width * height * num_channels)

    return im


def load(path):

    def get_integer(data, i):
        num = b''
        while str(data[i:i+1], 'ascii').isdigit():
            num += data[i:i+1]
            i += 1
        num = int(str(num, 'ascii'))

        assert data[i:i+1] in b' \t\n\r\v\f'
        i += 1

        return num, i

    ######################
    data = open(path, 'rb').read()

    if data[:2] not in [b'P5', b'P6']:
        print('Unknown file type')
        return None
    assert data[2:3] in b' \t\n\r\v\f'

    num_channels = {b'P5': 1, b'P6': 3}[data[:2]]

    width, i = get_integer(data, 3)
    height, i = get_integer(data, i)
    max_val, i = get_integer(data, i)
    assert max_val == 255
    assert len(data[i:]) == width * height * num_channels

    im = Netpbm()
    im.width = width
    im.height = height
    im.num_channels = num_channels
    im.max_val = max_val
    im.data = bytearray(data[i:])

    return im


