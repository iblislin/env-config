from  __future__ import print_function

import sys


EXCLUDE_CMD = {
    'CLEAN': ( # those cmds will clean the title
        'ls',
        'la',
        'll',
        'cd',
        '.',
        '..',
    ),
    'NEXT': ( # those cmds will use the next as title
        'sudo',
    ),
}


def change_title(s):
    print('\033k{}\033\\'.format(s), end='')


def main():
    if len(sys.argv) <= 1:
        return
    for cmd in sys.argv[1:]:
        if cmd in EXCLUDE_CMD['CLEAN']:
            change_title('\b')
            break
        if cmd in EXCLUDE_CMD['NEXT']:
            continue
        change_title(cmd)
        break
    else:
        pass

if __name__ == '__main__':
    main()
