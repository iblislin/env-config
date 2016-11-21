import argparse
import os

from multiprocessing.pool import ThreadPool

import pycurl

RETRY_LIMIT = 20


def extract_filename(url):
    return url, os.path.split(url)[-1]


def dw(*args, **kwargs):
    retry = 1
    error_info = ''

    while retry < RETRY_LIMIT:
        try:
            _dw(*args, **kwargs)
        except Exception as e:
            retry += 1
            error_info = e
            continue
        else:
            return

    print('[ERROR]', (args, kwargs), error_info)


def _dw(url, filename):

    c = pycurl.Curl()
    c.setopt(c.URL, url)
    with open(filename, 'wb') as f:
        c.setopt(c.WRITEFUNCTION, f.write)
        c.perform()
    c.close()
    print('[INFO]', url, filename, 'Done')


def main(args):
    with open(args.input) as f:
        ls = map(str.strip, f.readlines())

    with ThreadPool(100) as pool:
        pool.starmap(dw, map(extract_filename, ls))


def parse():
    parser = argparse.ArgumentParser('Simple crawler')
    parser.add_argument('-i', dest='input', type=argparse.FileType('r'))
    return parser.parse_args()


if __name__ == '__main__':
    main(parse())
