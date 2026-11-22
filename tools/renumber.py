#!/usr/bin/env python3
"""Move BASIC lines to new numbers in a petcat listing and fix every
GOTO/GOSUB/THEN/ON target. Usage: renumber.py file.txt old=new ..."""
import re
import sys


def renumber(text, mapping):
    def fix_targets(body):
        out = []
        i = 0
        inq = False
        while i < len(body):
            ch = body[i]
            if ch == '"':
                inq = not inq
                out.append(ch)
                i += 1
                continue
            if not inq:
                m = re.match(r'(goto|gosub|then)\s*', body[i:])
                if m:
                    out.append(m.group(0))
                    i += m.end()
                    kw = m.group(1)
                    while True:
                        n = re.match(r'\d+', body[i:])
                        if not n:
                            break
                        num = int(n.group(0))
                        out.append(str(mapping.get(num, num)))
                        i += n.end()
                        if kw == 'then':
                            break
                        if body[i:i + 1] == ',':
                            out.append(',')
                            i += 1
                            continue
                        break
                    continue
            out.append(ch)
            i += 1
        return ''.join(out)

    lines = []
    for line in text.splitlines():
        if not line.strip():
            continue
        num, body = line.strip().split(' ', 1)
        num = int(num)
        lines.append((mapping.get(num, num), fix_targets(body)))
    nums = [n for n, _ in lines]
    if len(nums) != len(set(nums)):
        raise SystemExit("duplicate line numbers after renumbering")
    lines.sort()
    return '\n'.join(f' {n} {b}' for n, b in lines) + '\n'


if __name__ == '__main__':
    path = sys.argv[1]
    mapping = {}
    for arg in sys.argv[2:]:
        a, b = arg.split('=')
        mapping[int(a)] = int(b)
    src = open(path).read()
    open(path, 'w').write(renumber(src, mapping))
