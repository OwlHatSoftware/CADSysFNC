#!/usr/bin/env python3
"""Writes the committed .CS2 fixtures in Test\\data.

Why this exists, and why it is Python rather than Pascal:

CADSys4.Tests.Legacy builds its streams in Delphi, with TLegacyWriter, and
argues in its own header comment that this is better than a fixture on disk.
It is - for testing the reader's branches. But a writer and a reader written
by the same hand from the same reading of the format agree with each other
whether or not either agrees with the format.

So these three files are written from the format description alone, by a
program that shares no code with the library, and committed as bytes. A
change to the reader that also "fixes" TLegacyWriter to match still has to
get past them.

The format has two widths that the file does not record, and they are
independent:

  * a Char is one byte in a Delphi 7 era build and two in a Unicode one -
    the reader sniffs this from the header, where 'CAD' has a zero after
    every character in the wide form;
  * a TRealType is a Single before version CAD423 and a Double from it.

Hence three files rather than one. The third is the combination that catches
people out: a modern Unicode build still writing the CAD422 version string,
so wide characters and narrow reals in the same file.

Run it from anywhere:  python Tools\\make-legacy-fixtures.py

It rewrites the fixtures in place. If a fixture changes, that is a change to
what the reader is being held to - read the diff rather than committing it.
"""

import os
import struct
import sys

# --- the drawing all three files hold -------------------------------------
#
# Deliberately small, and chosen so that every field a reader has to get
# right is asserted by something in CADSys4.Tests.Legacy:
#
#   layer 3    a name, a pen colour, a width and a brush colour
#   line       the plain two-point primitive
#   polyline   a point count that is not two
#   ellipse    the curve tail (precision and saving type)
#   arc        the curve tail and the direction byte after it
#
# The coordinates are whole numbers so that a Single and a Double file
# produce bit-identical values and one set of assertions covers both.

LAYER_INDEX = 3
LAYER_NAME = 'WALLS'
LAYER_PEN_COLOR = 0x0000FF      # TColor is $00BBGGRR - this is red
LAYER_PEN_WIDTH = 2
LAYER_BRUSH_COLOR = 0xFFFFFF

LINE = (101, (10.0, 20.0), (110.0, 220.0))
POLYLINE = (102, [(0.0, 0.0), (50.0, 0.0), (50.0, 40.0)])
ELLIPSE = (103, (200.0, 200.0), (300.0, 260.0))
ARC = (104, (0.0, 0.0), (100.0, 100.0), (100.0, 50.0), (50.0, 100.0))

CURVE_PRECISION = 60
SAVING_TYPE = 0                 # stSpace

# --- class indices, from the original CADSysRegister.pas -------------------

IDX_LINE2D = 3
IDX_POLYLINE2D = 4
IDX_ELLIPSE2D = 8
IDX_ARC2D = 7

# --- section markers -------------------------------------------------------

LAYERS_MARKER = 1
BLOCKS_MARKER = 2
OBJECTS_MARKER = 3
END_OF_LAYERS = 256
END_OF_OBJECTS = 65535


class Writer:
    """The legacy format, written from its description.

    Nothing here is imported from the library: the point is that these
    bytes were produced by an independent reading of the same spec.
    """

    def __init__(self, version, wide, double):
        assert len(version) == 6, 'TCADVersion is six characters'
        self.wide = wide
        self.double = double
        self.buf = bytearray()
        for ch in version:
            self.buf += ch.encode('latin-1')
            if wide:
                self.buf += b'\x00'

    # -- primitives ---------------------------------------------------------

    def byte(self, v):
        self.buf += struct.pack('<B', v)

    def bool(self, v):
        self.byte(1 if v else 0)

    def word(self, v):
        self.buf += struct.pack('<H', v)

    def int(self, v):
        self.buf += struct.pack('<i', v)

    def real(self, v):
        self.buf += struct.pack('<d' if self.double else '<f', v)

    def point(self, x, y, w=1.0):
        """The old format stored homogeneous points: X, Y and W."""
        self.real(x)
        self.real(y)
        self.real(w)

    def identity(self):
        """Nine reals, row major, as TTransf2D was laid out."""
        for row in range(3):
            for col in range(3):
                self.real(1.0 if row == col else 0.0)

    def shortstring32(self, s):
        """A Delphi ShortString in a fixed 32 byte slot.

        Always single byte characters, even in a Unicode build. The bytes
        past the length were whatever was in memory; real files have
        rubbish there, so the fixtures do too - it is the one thing a
        reader must not look at.
        """
        raw = s.encode('latin-1')
        assert len(raw) <= 31
        slot = bytearray(32)
        slot[0] = len(raw)
        slot[1:1 + len(raw)] = raw
        for i in range(1 + len(raw), 32):
            slot[i] = 0xCC
        self.buf += slot

    # -- sections -----------------------------------------------------------

    def layers(self):
        self.word(LAYERS_MARKER)
        self.word(LAYER_INDEX)
        self.int(LAYER_PEN_COLOR)
        self.byte(0)                  # pen style   - cpsSolid
        self.byte(0)                  # pen mode    - cpmCopy
        self.int(LAYER_PEN_WIDTH)
        self.int(LAYER_BRUSH_COLOR)
        self.byte(0)                  # brush style - cbsSolid
        self.int(0)                   # decorative pen pattern, length 0
        self.bool(True)               # active
        self.bool(True)               # visible
        self.bool(False)              # opaque
        self.bool(True)               # streamable
        self.shortstring32(LAYER_NAME)
        self.word(END_OF_LAYERS)

    def no_blocks(self):
        self.byte(BLOCKS_MARKER)
        self.int(0)

    def object_header(self, class_index, obj_id, layer):
        self.word(class_index)
        self.int(obj_id)
        self.byte(layer)
        # bit 0 visible, bit 1 enabled, bit 2 meant "not to be saved"
        self.byte(0x01 | 0x02)
        self.identity()

    def primitive(self, class_index, obj_id, layer, points):
        self.object_header(class_index, obj_id, layer)
        self.word(len(points))
        for x, y in points:
            self.point(x, y)
        self.bool(False)              # growing

    def curve_tail(self):
        self.word(CURVE_PRECISION)
        self.byte(SAVING_TYPE)

    def objects(self, overcount):
        """The drawing's four objects.

        overcount writes a count one higher than the number of objects and
        appends the end-of-objects sentinel, which is what a real writer
        produced when it skipped an object on an unstreamable layer. The
        count at the head of the section is an upper bound; the sentinel is
        the real end.
        """
        self.byte(OBJECTS_MARKER)
        self.int(4 + (1 if overcount else 0))

        obj_id, p1, p2 = LINE
        self.primitive(IDX_LINE2D, obj_id, LAYER_INDEX, [p1, p2])

        obj_id, pts = POLYLINE
        self.primitive(IDX_POLYLINE2D, obj_id, LAYER_INDEX, pts)

        obj_id, p1, p2 = ELLIPSE
        self.primitive(IDX_ELLIPSE2D, obj_id, LAYER_INDEX, [p1, p2])
        self.curve_tail()

        obj_id, p1, p2, p3, p4 = ARC
        self.primitive(IDX_ARC2D, obj_id, LAYER_INDEX, [p1, p2, p3, p4])
        self.curve_tail()
        self.byte(0)                  # direction - adClockwise

        if overcount:
            self.word(END_OF_OBJECTS)


def build(version, wide, double, overcount):
    w = Writer(version, wide, double)
    w.layers()
    w.no_blocks()
    w.objects(overcount)
    return bytes(w.buf)


FIXTURES = [
    # name, version, wide chars, double reals, over-counted objects
    ('narrow-chars-single-reals.CS2', 'CAD422', False, False, False),
    ('wide-chars-double-reals.CS2',   'CAD423', True,  True,  True),
    ('wide-chars-single-reals.CS2',   'CAD422', True,  False, False),
]


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(os.path.dirname(here), 'Test', 'data')
    os.makedirs(out, exist_ok=True)
    for name, version, wide, double, overcount in FIXTURES:
        data = build(version, wide, double, overcount)
        path = os.path.join(out, name)
        old = None
        if os.path.exists(path):
            with open(path, 'rb') as f:
                old = f.read()
        with open(path, 'wb') as f:
            f.write(data)
        state = 'unchanged' if old == data else ('CHANGED' if old else 'new')
        print('%-32s %5d bytes  %s' % (name, len(data), state))
    return 0


if __name__ == '__main__':
    sys.exit(main())
