#!/usr/bin/env python3
"""
ls.py : list directory. Usage: ls [path]
"""
import os
import sys
from pathlib import Path

SIMOS_ROOT = Path(os.environ.get('SIMOS_ROOT', '.')).resolve()
SIMOS_CWD = os.environ.get('SIMOS_CWD', '/')

# minimal real_path mapping
def real_path(virtual_path: str, cwd_virtual: str) -> Path:
    if not virtual_path:
        virtual_path = '.'
    if virtual_path.startswith('/'):
        v = Path(virtual_path)
    else:
        v = (Path(cwd_virtual) / virtual_path)
    v_parts = []
    for p in v.parts:
        if p == '.':
            continue
        if p == '..':
            if v_parts:
                v_parts.pop()
            continue
        v_parts.append(p)
    virtual_abs = Path('/')
    for p in v_parts:
        virtual_abs /= p
    rel = Path(*[p for p in virtual_abs.parts if p != '/'])
    return (SIMOS_ROOT / rel).resolve()

path = sys.argv[1] if len(sys.argv) > 1 else SIMOS_CWD
rp = real_path(path, SIMOS_CWD)
if not rp.exists():
    print('no such file or directory')
    sys.exit(1)
if rp.is_file():
    print(rp.name)
    sys.exit(0)
for p in sorted(rp.iterdir()):
    suf = '/' if p.is_dir() else ''
    print(p.name + suf)
