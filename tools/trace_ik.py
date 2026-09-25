"""trace_ik.py : désassemblage récursif de l'image IK+ (ATOR.EXE, chargée en $700).

Pas de relocations : un pointeur de code n'est reconnu que par l'usage.
Graines :
  - $1000 (point d'entrée), puis tout ce qui s'exécute depuis là ;
  - immédiats et adresses absolues ($1000 <= v < $53800) utilisés comme
    #imm (move.l/cmpi.l…), lea/pea, ou jmp/jsr absolus ;
  - tables de pointeurs longs repérées par lea d'une table dont au moins
    2 entrées consécutives pointent dans l'image.
Chaque graine « faible » (immédiat, table) est décodée à l'essai : elle est
rejetée si le chemin rencontre un opcode invalide ou chevauche une
instruction déjà reconnue.

Sortie : work/ik.lst (listing annoté) et work/ik_code.txt (adresses code).
"""
import sys, re, capstone
from capstone import m68k as M

BASE, END = 0x700, 0x53800
LO = 0x1000
if len(sys.argv) < 2:
    sys.exit('usage : python3 tools/trace_ik.py <ATOR.EXE>   (écrit work/ik.lst)')
data = open(sys.argv[1], 'rb').read()
import os
os.makedirs('work', exist_ok=True)
md = capstone.Cs(capstone.CS_ARCH_M68K, capstone.CS_MODE_M68K_000)
md.detail = True

def rd(a, n):
    return data[a - BASE:a - BASE + n]

_cache = {}
def dec(a):
    if a in _cache:
        return _cache[a]
    ins = None
    if BASE <= a < END - 2:
        l = list(md.disasm(rd(a, 10), a, 1))
        if l:
            ins = l[0]
            if ins.id == 0 or ins.mnemonic.startswith('dc'):
                _cache[a] = None
                return None
            # capstone : taille fausse des décalages mémoire (asl.w d16(An))
            b = int.from_bytes(rd(a, 2), 'big')
            if (b & 0xF8C0) == 0xE0C0 and ins.size == 2 and ((b >> 3) & 7) in (5, 6, 7):
                ins = None
            if ins is not None and re.search(r'\(\[|\]\)|\*\s*[248]|,\s*[ad]\d\.[wl]\s*\*', ins.op_str):
                ins = None  # modes 68020
    _cache[a] = ins
    return ins

BR = {'bra', 'bsr', 'bhi', 'bls', 'bcc', 'bcs', 'bne', 'beq', 'bvc', 'bvs', 'bpl', 'bmi', 'bge', 'blt', 'bgt', 'ble', 'bhs', 'blo'}
END_FLOW = {'rts', 'rte', 'rtr', 'jmp', 'bra', 'illegal', 'stop'}

def targets(ins):
    """cibles directes (branches / jsr absolus / pc-relatif)."""
    t = []
    mn = ins.mnemonic.split('.')[0]
    ops = ins.operands
    if mn in BR or mn.startswith('db'):
        for o in ops:
            if o.type == M.M68K_OP_BR_DISP:
                t.append(ins.address + 2 + o.br_disp.disp)
        if not t:
            m = re.search(r'\$([0-9a-f]+)$', ins.op_str)
            if m: t.append(int(m.group(1), 16))
    elif mn in ('jmp', 'jsr'):
        m = re.fullmatch(r'\$([0-9a-f]+)(\.[wl])?', ins.op_str.strip())
        if m: t.append(int(m.group(1), 16))
        m = re.fullmatch(r'\$([0-9a-f]+)\(pc\)', ins.op_str.strip())
        if m: t.append(int(m.group(1), 16))
    return t

def weak_refs(ins):
    """valeurs susceptibles d'être des pointeurs de code."""
    out = []
    mn = ins.mnemonic.split('.')[0]
    s = ins.op_str
    for m in re.finditer(r'#\$([0-9a-f]+)', s):
        v = int(m.group(1), 16)
        if LO <= v < END and not v & 1 and ('.l' in ins.mnemonic or mn in ('movea',)):
            out.append(v)
    if mn in ('lea', 'pea'):
        m = re.match(r'\$([0-9a-f]+)(\.[wl]|\(pc\))?', s)
        if m:
            v = int(m.group(1), 16)
            if LO <= v < END and not v & 1:
                out.append(v)
    return out

code = {}          # addr -> ins
owner = {}         # byte addr -> ins start
labels = {}        # addr -> kind
tables = {}        # table addr -> [entries]

def try_trace(start, commit):
    """trace depuis start ; si commit=False, vérifie seulement la validité."""
    todo, seen, new = [start], set(), {}
    while todo:
        a = todo.pop()
        while True:
            if a in code or a in new:
                break
            if a in owner and owner[a] != a:
                return None
            ins = dec(a)
            if ins is None:
                return None
            for k in range(1, ins.size):
                if (a + k) in code or (a + k) in new:
                    return None
            new[a] = ins
            for t in targets(ins):
                if not (BASE <= t < END):
                    continue
                if t & 1:
                    return None
                todo.append(t)
            mn = ins.mnemonic.split('.')[0]
            if mn in END_FLOW:
                break
            a += ins.size
    if commit:
        for a, ins in new.items():
            code[a] = ins
            for k in range(ins.size):
                owner[a + k] = a
    return new

def after_end(v):
    """la graine faible suit-elle une fin de flot (rts/rte/jmp/bra) ?"""
    w2 = int.from_bytes(rd(v - 2, 2), 'big')
    if w2 in (0x4E75, 0x4E73, 0x4E77): return True
    if (w2 & 0xFF00) == 0x6000 and (w2 & 0xFF): return True          # bra.s
    if int.from_bytes(rd(v - 4, 2), 'big') == 0x6000: return True     # bra.w
    if int.from_bytes(rd(v - 6, 2), 'big') in (0x4EF9,): return True   # jmp abs.l
    if int.from_bytes(rd(v - 4, 2), 'big') in (0x4EF8,): return True   # jmp abs.w
    return False

def label(a, k):
    labels.setdefault(a, k)

label(0x1000, 'entry')
strong = [0x1000]
weak = []            # (valeur, instruction)
weak_done = set()
def run_strong():
    while strong:
        s = strong.pop()
        r = try_trace(s, True)
        if r is None:
            print('ECHEC graine forte $%x' % s, file=sys.stderr)
            continue
        for a, ins in sorted(r.items()):
            for t in targets(ins):
                if BASE <= t < END:
                    label(t, 'sub' if ins.mnemonic.startswith(('bsr', 'jsr')) else 'loc')
            for v in weak_refs(ins):
                if v not in weak_done:
                    weak.append((v, ins))

run_strong()
while weak:
    v, ins = weak.pop(0)
    if v in weak_done:
        continue
    weak_done.add(v)
    if v < 0x14E6:                   # variables globales $1000-$14E5
        continue
    if v in code:
        label(v, 'ptr'); continue
    ent, p = [], v
    while p + 4 <= END:
        w = int.from_bytes(rd(p, 4), 'big')
        if 0x14E6 <= w < END and not w & 1 and dec(w) is not None:
            ent.append(w); p += 4
        else:
            break
    if len(ent) >= 2 and ins.mnemonic.startswith('lea') and all(e in code or try_trace(e, False) is not None for e in ent):
        tables[v] = ent; label(v, 'table')
        for e in ent:
            label(e, 'ptr'); strong.append(e)
        run_strong(); continue
    if after_end(v) and try_trace(v, False) is not None:
        label(v, 'ptr'); strong.append(v); run_strong()

# ---------- listing ----------
def name(a):
    k = labels.get(a)
    if not k:
        return None
    return {'entry': 'entry', 'sub': 'F_%05x', 'ptr': 'P_%05x', 'loc': 'L_%05x', 'table': 'T_%05x'}[k] % a if k != 'entry' else 'entry'

ncode = sum(i.size for i in code.values())
with open('work/ik.lst', 'w') as f:
    a = BASE
    while a < END:
        n = name(a)
        if a in code:
            ins = code[a]
            if n: f.write('\n%s:\n' % n)
            ops = re.sub(r'\$([0-9a-f]{3,6})\b', lambda m: (name(int(m.group(1), 16)) or m.group(0)), ins.op_str)
            f.write('%06x  %-20s %-8s %s\n' % (a, rd(a, ins.size).hex(), ins.mnemonic, ops))
            a += ins.size
        else:
            b = a
            while b < END and b not in code and (b == a or b not in labels):
                b += 1
            if n: f.write('\n%s:\n' % n)
            chunk = rd(a, b - a)
            for i in range(0, len(chunk), 16):
                c = chunk[i:i + 16]
                f.write('%06x  dc.b %-48s ; %s\n' % (a + i, c.hex(' '), ''.join(chr(x) if 32 <= x < 127 else '.' for x in c)))
            a = b
with open('work/ik_code.txt', 'w') as f:
    for a in sorted(code):
        f.write('%x\n' % a)
print('code : %d octets (%.1f %% de l\'image), %d instructions, %d labels, %d tables'
      % (ncode, 100 * ncode / (END - BASE), len(code), len(labels), len(tables)))
