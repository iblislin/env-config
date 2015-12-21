#!/usr/bin/env python3

import i3ipc
import sys


OUTPUT = {
    'DVI-I-1': 0,
    'VGA-1':   10,
}

DVI = 'DVI-I-1'
VGA = 'VGA-1'

WS_MAP = ['', 'α', 'β', 'ξ', 'δ', 'ε', 'φ', 'γ', 'θ']


def current_workspace(workspaces):
    for ws in workspaces:
        if ws.focused is True:
            return ws


def class_ws(workspaces):
    ret = {
        DVI: [],
        VGA: [],
    }

    for ws in workspaces:
        if ws.output == DVI:
            ret[DVI].append(ws)
        elif ws.output == VGA:
            ret[VGA].append(ws)

    return ret


def on_ws_focus(i3, e):
    workspaces = i3.get_workspaces()
    cur = current_workspace(workspaces)
    output = cur.output
    ws_ls = class_ws(workspaces)

    num = ws_ls[output].index(cur) + 1 + OUTPUT[output]

    char = WS_MAP[num - OUTPUT[output]]
    print('rename to {}:{}'.format(num, char))
    i3.command('rename workspace to {}:{}'.format(num, char))


def main():
    i3 = i3ipc.Connection()

    i3.on('workspace::focus', on_ws_focus)

    i3.main()


if __name__ == '__main__':
    main()
