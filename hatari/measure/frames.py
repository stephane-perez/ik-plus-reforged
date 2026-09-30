"""frames.py <log.txt> : frame timeline from a Hatari run using frames.dbg.

Prints, for each stretch of identical (game state, message), the number of
frames and the average number of VBLs per frame, then the distribution of
frame lengths during combat (state 1).
1 VBL = 1/50 s. The game needs at least 2 VBLs per frame in turbo (F6) and
5 at normal speed (F8), unless the speed table is unlocked (unlock.py).
"""
import re, sys, collections

text = open(sys.argv[1]).read()
frames = []
for block in text.split('> e VBL')[1:]:
    m = re.search(r'#(\d+) \(dec\)', block)
    if not m:
        continue
    vals = {k: int(x, 16) >> 24 for k, x in
            re.findall(r'value in RAM at \(\$(\w+)\)\.l = \$(\w+)', block)}
    frames.append((int(m.group(1)), vals.get('1076'), vals.get('1090')))

prev, seg = None, []
for v, st, msg in frames:
    if (st, msg) != prev:
        seg.append([(st, msg), v, v, 0])
        prev = (st, msg)
    seg[-1][2] = v
    seg[-1][3] += 1
for (st, msg), a, b, n in seg:
    if n > 1:
        print('state %s msg %s  VBL %d-%d  %d frames  %.2f VBL/frame' % (st, msg, a, b, n, (b - a) / (n - 1)))

d = [b[0] - a[0] for a, b in zip(frames, frames[1:]) if a[1] == 1 and b[1] == 1]
if d:
    c = collections.Counter(d)
    print('combat: %d frames, %s, average %.2f VBL = %.1f frames/s' % (
        len(d), ', '.join('%d VBL %.0f%%' % (k, 100 * c[k] / len(d)) for k in sorted(c)),
        sum(d) / len(d), 50 * len(d) / sum(d)))
