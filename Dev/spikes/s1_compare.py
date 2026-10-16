"""S1 spike (dev-only): decode talent strings and find duplicates / near matches.

Usage: python s1_compare.py path\\to\\TalentLoadoutsEx.lua [maxdiff]
Mirrors Blizzard's ExportUtil + ClassTalentImportExportMixin (wow-ui-source live,
12.1.5). No tree data needed: the content is one record per tree node, so two
builds of the same spec compare node by node. Talent names need the game (v0.2).
"""
import re, sys, itertools

B64 = {c: i for i, c in enumerate(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")}

def bits(s):
    return [(B64[ch] >> i) & 1 for ch in s for i in range(6)]

def decode(s):
    b, pos = bits(s), 0
    def take(n):
        nonlocal pos
        if pos + n > len(b):
            raise EOFError
        pos += n
        return sum(b[pos - n + i] << i for i in range(n))
    version, spec = take(8), take(16)
    take(128)  # tree hash: ignored, it changes with patches not picks
    nodes = []
    try:
        while True:
            if not take(1):
                nodes.append(None); continue
            if not take(1):
                nodes.append("granted"); continue
            ranks = take(6) if take(1) else "max"
            choice = take(2) + 1 if take(1) else None
            nodes.append((ranks, choice))
    except EOFError:
        pass
    while nodes and nodes[-1] is None:  # base64 padding reads as empty nodes
        nodes.pop()
    return version, spec, tuple(nodes)

def diff(a, b):
    n = max(len(a), len(b))
    pad = lambda t: t + (None,) * (n - len(t))
    return [i for i, (x, y) in enumerate(zip(pad(a), pad(b))) if x != y]

def builds(path):
    src = open(path, encoding="utf-8-sig").read()
    cls = None
    for line_block in re.split(r"\n(?=\[\"[A-Z]+\"\] = \{)", src):
        m = re.match(r'\["([A-Z]+)"\]', line_block)
        cls = m.group(1) if m else cls
        for blk in re.findall(r"\{[^{}]*\}", line_block):
            t = re.search(r'\["text"\] = "([^"]+)"', blk)
            if t:
                name = re.search(r'\["name"\] = "((?:[^"\\]|\\.)*)"', blk)
                pvp = tuple(int(v) for _, v in sorted(re.findall(r'\["pvp(\d)"\] = (\d+)', blk)))
                yield cls, name.group(1) if name else "?", t.group(1), pvp

def main():
    path, maxdiff = sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 4
    rows = [(c, n, *decode(t), p) for c, n, t, p in builds(path)]
    print(f"{len(rows)} builds")
    for (c1, n1, v1, s1, a, p1), (c2, n2, v2, s2, b, p2) in itertools.combinations(rows, 2):
        if s1 != s2:
            continue
        d = diff(a, b)
        if len(d) <= maxdiff:
            kind = "DUPLICATE" if not d else f"differs at {len(d)} node(s) {d}"
            pvp = "" if p1 == p2 else f" (PvP differs {p1} vs {p2})"
            print(f"spec {s1} {c1}: '{n1}' vs '{n2}': {kind}{pvp}")

if __name__ == "__main__":
    main()
