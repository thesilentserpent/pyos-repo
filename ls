#!/usr/bin/env python3
"""
ls.py : list directory. Usage: ls [path]
"""
import os
import sys
import stat
from pathlib import Path
from datetime import datetime

SIMOS_ROOT = Path(os.environ.get('SIMOS_ROOT', '.')).resolve()
SIMOS_CWD = os.environ.get('SIMOS_CWD', '/')

# ANSI colors
COLORS = {
    "dir": "\033[94m",
    "exec": "\033[92m",
    "file": "\033[0m",
    "reset": "\033[0m"
}

def real_path(virtual_path: str, cwd_virtual: str) -> Path:
    if not virtual_path:
        virtual_path = '.'
    if virtual_path.startswith('/'):
        v = Path(virtual_path)
    else:
        v = Path(cwd_virtual) / virtual_path
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

def permissions(mode: int) -> str:
    perms = ''
    for who in ['USR', 'GRP', 'OTH']:
        for what in ['R', 'W', 'X']:
            perms += (what.lower() if not (mode & getattr(stat, f'S_I{what}{who}')) else what)
    return perms

def list_dir(path: Path):
    if not path.exists():
        print('no such file or directory')
        return
    if path.is_file():
        print(path.name)
        return

    for p in sorted(path.iterdir()):
        mode = p.stat().st_mode
        color = COLORS['file']
        suf = ''
        if p.is_dir():
            color = COLORS['dir']
            suf = '/'
        elif os.access(p, os.X_OK):
            color = COLORS['exec']
        size = p.stat().st_size
        mtime = datetime.fromtimestamp(p.stat().st_mtime).strftime('%Y-%m-%d %H:%M')
        perms = permissions(mode)
        print(f"{color}{perms} {size:8} {mtime} {p.name}{suf}{COLORS['reset']}")

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else SIMOS_CWD
    rp = real_path(path, SIMOS_CWD)
    list_dir(rp)
