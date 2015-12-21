#!/usr/bin/env python
# encoding: utf-8

import i3ipc


if __name__ == '__main__':
    i3 = i3ipc.Connection()

    i3.command('focus output right')
