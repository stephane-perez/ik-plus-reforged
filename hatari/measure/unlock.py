"""unlock.py <IKPLUS.IMG in> <IKPLUS.IMG out> : copy of the game image with the speed
table at $6EB8 set to 0, so a frame never waits for extra VBLs. Used to
measure how fast the game can really go. For measurements only."""
import sys
d = bytearray(open(sys.argv[1], 'rb').read())
o = 0x6EB8 - 0x700
assert d[o:o + 6] == bytes([1, 3, 4, 5, 6, 7]), 'unexpected speed table'
d[o:o + 6] = bytes(6)
open(sys.argv[2], 'wb').write(d)
