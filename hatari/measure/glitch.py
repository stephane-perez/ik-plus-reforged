"""glitch.py <screenshot folder> : checks the raster colours on every
screenshot of a fight. The sea at (200, 244) must be blue (#2266EE); grey
means the Timer B colour chain slipped (see docs/fr/VERSIONS.md, section 10).
Prints one letter per screenshot: B = blue, g = grey, . = other screen."""
import sys, glob
from PIL import Image

out = ''
for f in sorted(glob.glob(sys.argv[1] + '/grab*.png')):
    p = Image.open(f).convert('RGB').getpixel((200, 244))
    out += 'B' if p == (0x22, 0x66, 0xEE) else ('g' if p[0] == p[1] == p[2] and p != (0, 0, 0) else '.')
print(out)
print('%d blue, %d grey (the first grey ones are boot screens)' % (out.count('B'), out.count('g')))
