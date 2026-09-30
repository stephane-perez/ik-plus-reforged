"""profile.py <profile.txt> <ik.lst> [start-end ...]

Shares of CPU time per game routine (nearest F_/P_ label of the listing made
by tools/trace_ik.py), then for the given hex address ranges, e.g.
76d6-76f6 (wait for the beam) or c0000-c1000 (STE module)."""
import re, sys, bisect

labels = sorted(int(m.group(2), 16) for m in
                (re.match(r'^(F|P)_([0-9a-f]+):', l) for l in open(sys.argv[2])) if m)
ranges = [tuple(int(x, 16) for x in r.split('-')) for r in sys.argv[3:]]
per, inr, total = {}, {}, 0
for l in open(sys.argv[1]):
    m = re.match(r'^([0-9a-f]{8}) .*% \((\d+), (\d+),', l)
    if not m:
        continue
    a, c = int(m.group(1), 16), int(m.group(3))
    total += c
    i = bisect.bisect_right(labels, a) - 1
    f = labels[i] if i >= 0 else 0
    per[f] = per.get(f, 0) + c
    for r in ranges:
        if r[0] <= a < r[1]:
            inr[r] = inr.get(r, 0) + c
print('total: %d cycles' % total)
for f, c in sorted(per.items(), key=lambda x: -x[1])[:25]:
    print('%06x %6.2f%%' % (f, 100 * c / total))
for r in ranges:
    print('%06x-%06x %6.2f%%' % (r[0], r[1], 100 * inr.get(r, 0) / total))
