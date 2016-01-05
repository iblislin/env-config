#!/usr/bin/env python3

import i3ipc

OUTPUT = {
    'DVI-I-1': 1,
    'VGA-1':   2,
}


def current_workspace(workspaces):
    for ws in workspaces:
        if ws.focused is True:
            return ws


i3 = i3ipc.Connection()

workspaces = i3.get_workspaces()
current = current_workspace(workspaces)

if current.output.startswith('DVI'):
    to = 'VGA-1'
else:
    to = 'DVI-I-1'

# import pprint; pprint.pprint(current)
print(to)

print(i3.get_tree().find_focused())

i3.command('move workspace to output {0}'.format(to))

# i3.command('focus output {}'.format(to))
# i3.main()
