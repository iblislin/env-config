#!/usr/bin/env python3

import i3ipc
import sys


def current_workspace(workspaces):
    for ws in workspaces:
        if ws.focused is True:
            return ws


def main():
    i3 = i3ipc.Connection()

    workspaces = i3.get_workspaces()
    num = len(workspaces)
    current = current_workspace(workspaces).num

    to = current + int(sys.argv[1])
    if to < 1:
        to = workspaces[to-1].num
    print(to)
    i3.command("workspace number {}".format(to))


if __name__ == '__main__':
    main()
