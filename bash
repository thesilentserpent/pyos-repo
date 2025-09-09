#!/usr/bin/env python3
"""
SimOS Bash-like Shell with Syntax Highlight
- Blue prompt: user@host:path$
- Command highlighting:
    - Green if command exists
    - Red if command missing
- Arguments: White color
- Built-ins: cd, pwd, exit, help
"""

import os
import sys
from pathlib import Path
import shlex
import subprocess
import readline  # for line editing and history

# Colors
BLUE = "\033[94m"
GREEN = "\033[92m"
RED = "\033[91m"
WHITE = "\033[97m"
RESET = "\033[0m"

SIMOS_ROOT = Path(os.environ.get("SIMOS_ROOT", ".")).resolve()
cwd = os.environ.get("SIMOS_CWD", "/")
user = os.environ.get("SIMOS_USER", os.environ.get("USER", "user"))

def real_path(virtual_path: str, cwd_virtual: str) -> Path:
    if not virtual_path:
        virtual_path = "."
    if virtual_path.startswith("/"):
        v = Path(virtual_path)
    else:
        v = (Path(cwd_virtual) / virtual_path)

    v_parts = []
    for p in v.parts:
        if p == ".":
            continue
        if p == "..":
            if v_parts:
                v_parts.pop()
            continue
        v_parts.append(p)

    virtual_abs = Path("/")
    for p in v_parts:
        virtual_abs /= p

    rel = Path(*[p for p in virtual_abs.parts if p != "/"])
    return (SIMOS_ROOT / rel).resolve()

def run_external(cmd_parts):
    name = cmd_parts[0]
    exe = None
    if "/" in name:
        exe = real_path(name, cwd)
    else:
        cand = (SIMOS_ROOT / "usr" / "bin" / name)
        if cand.exists():
            exe = cand
    if exe is None or not exe.exists():
        print(f"{RED}command not found:{RESET} {name}")
        return 127
    env = os.environ.copy()
    env["SIMOS_ROOT"] = str(SIMOS_ROOT)
    env["SIMOS_CWD"] = cwd
    env["SIMOS_USER"] = user
    try:
        p = subprocess.run([sys.executable, str(exe)] + cmd_parts[1:], env=env, cwd=SIMOS_ROOT)
        return p.returncode
    except KeyboardInterrupt:
        return 130
    except Exception as e:
        print(f"{RED}run error:{RESET} {e}")
        return 1

def is_command_available(cmd):
    return (SIMOS_ROOT / "usr" / "bin" / cmd).exists()

def colorize_input(line):
    try:
        parts = shlex.split(line)
    except ValueError:
        return line  # return unmodified if syntax broken
    if not parts:
        return line

    cmd = parts[0]
    args = parts[1:]

    if is_command_available(cmd):
        cmd_colored = f"{GREEN}{cmd}{RESET}"
    else:
        cmd_colored = f"{RED}{cmd}{RESET}"

    args_colored = " ".join(f"{WHITE}{a}{RESET}" for a in args)
    return f"{cmd_colored} {args_colored}".strip()

# Main shell loop
while True:
    try:
        raw_line = input(f"{BLUE}{user}@simos:{cwd}$ {RESET}")
        if not raw_line.strip():
            continue

        parts = shlex.split(raw_line)
        cmd = parts[0]
        args = parts[1:]

        # Built-ins
        if cmd == "exit":
            break
        elif cmd == "pwd":
            print(cwd)
            continue
        elif cmd == "cd":
            target = args[0] if args else "/"
            rp = real_path(target, cwd)
            if rp.exists() and rp.is_dir():
                if rp == SIMOS_ROOT:
                    cwd = "/"
                else:
                    rel = rp.relative_to(SIMOS_ROOT)
                    cwd = "/" + rel.as_posix()
            else:
                print(f"{RED}no such directory{RESET}")
            continue
        elif cmd == "help":
            print(f"Shell built-ins: {GREEN}cd, pwd, exit, help{RESET}")
            print(f"Other programs run from {SIMOS_ROOT}/usr/bin")
            continue

        # External commands
        run_external(parts)

    except EOFError:
        print()
        break
    except KeyboardInterrupt:
        print()
        continue
