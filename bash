#!/usr/bin/env python3
"""
A tiny interactive shell implemented as a simos app.
It reads SIMOS_ROOT and SIMOS_CWD from environment and spawns other apps by invoking
Python on files under $SIMOS_ROOT/usr/bin.
"""
import os
import sys
from pathlib import Path
import shlex
import subprocess

SIMOS_ROOT = Path(os.environ.get('SIMOS_ROOT', '.')).resolve()
cwd = os.environ.get('SIMOS_CWD', '/')
user = os.environ.get('SIMOS_USER', os.environ.get('USER', 'user'))

PROMPT = f"{user}@simos:{cwd}$ "

def real_path(virtual_path: str, cwd_virtual: str) -> Path:
    # minimal virtual->real mapping identical to kernel's mapping
    if not virtual_path:
        virtual_path = '.'
    if virtual_path.startswith('/'):
        v = Path(virtual_path)
    else:
        v = (Path(cwd_virtual) / virtual_path)
    # normalize
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


def run_external(cmd_parts):
    # Look up executable in SIMOS_ROOT/usr/bin or accept path
    name = cmd_parts[0]
    exe = None
    if '/' in name:
        exe = real_path(name, cwd)
    else:
        cand = (SIMOS_ROOT / 'usr' / 'bin' / name)
        if cand.exists():
            exe = cand
    if exe is None or not exe.exists():
        print('command not found:', name)
        return 127
    # Run and inherit stdin/out/err
    env = os.environ.copy()
    env['SIMOS_ROOT'] = str(SIMOS_ROOT)
    env['SIMOS_CWD'] = cwd
    env['SIMOS_USER'] = user
    try:
        p = subprocess.run([sys.executable, str(exe)] + cmd_parts[1:], env=env, cwd=SIMOS_ROOT)
        return p.returncode
    except KeyboardInterrupt:
        return 130
    except Exception as e:
        print('run error:', e)
        return 1


while True:
    try:
        line = input(f"{user}@simos:{cwd}$ ")
    except EOFError:
        print()
        break
    except KeyboardInterrupt:
        print()
        continue
    if not line.strip():
        continue
    parts = shlex.split(line)
    cmd = parts[0]
    args = parts[1:]
    # Builtins handled in the shell app itself
    if cmd == 'exit':
        break
    if cmd == 'pwd':
        print(cwd)
        continue
    if cmd == 'cd':
        target = args[0] if args else '/'
        rp = real_path(target, cwd)
        if rp.exists() and rp.is_dir():
            # compute virtual path
            if rp == SIMOS_ROOT:
                cwd = '/'
            else:
                rel = rp.relative_to(SIMOS_ROOT)
                cwd = '/' + rel.as_posix()
            continue
        else:
            print('no such directory')
            continue
    if cmd == 'help':
        print('shell builtins: cd, pwd, exit, help. Other programs are run from /usr/bin')
        continue
    # External programs
    rc = run_external(parts)
    # loop continues; cwd is kept in-process for this shell
