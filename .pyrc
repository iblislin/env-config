# Add auto-completion and a stored history file of commands to your Python
# interactive interpreter. Requires Python 2.0+, readline. Autocomplete is
# bound to the Esc key by default (you can change it - see readline docs).
#
# Store the file in ~/.pyrc.py, and set an environment variable to point
# to it:  "export PYTHONSTARTUP=/home/yourname/.pyrc.py" in bash.
#
# Note that PYTHONSTARTUP does *not* expand "~", so you have to put in the
# full path to your home directory.

import atexit
import os
import readline
import rlcompleter
import sys

is_py2 = (sys.version_info.major == 2)

# Change autocomplete to tab
if readline.__doc__ and 'libedit' in readline.__doc__:
    # for mac
    readline.parse_and_bind("bind ^I rl_complete")
else:
    readline.parse_and_bind("tab: complete")


# If history file exist, source it.
history_path = os.path.expanduser("~/.pyhistory")
if os.path.exists(history_path):
    readline.read_history_file(history_path)


# Save history on exit
def save_history(history_path=history_path):
    import readline
    readline.write_history_file(history_path)
atexit.register(save_history)


# If ~/.pylocal.py exist, source it.
pylocal_path = os.path.expanduser("~/.pylocal.py")
if os.path.exists(pylocal_path):
    print("exec '.pylocal.py'  ...")
    if is_py2:
        execfile(pylocal_path)
    else:
        exec(compile(open(pylocal_path).read(), pylocal_path, 'exec'))


# Anything not deleted (sys and os) will remain in the interpreter session
del atexit, readline, rlcompleter, save_history, history_path, pylocal_path


# Useful libs import for you
from datetime import datetime
import itertools
import json
import math
import re
import shlex
import subprocess

if is_py2:
    import urllib, urllib2
else:
    import urllib.request, urllib.parse

def openurl(url, params={}, method="GET"):
    """open the url
    args:
        @url(string): the url to be opened.
        @params(dict): the url's params
        @method(string): GET/POST
    
    return value:
        urllib2.urlopen() instance. you can get the content by .read().
        # urllib.request.urlopen()
    
    example:
        openurl('http://www.google.com/', {'q':'google'}, 'GET').read()
    """
    if is_py2:
        urlopen = urllib2.urlopen
        urlencode = urllib.urlencode
    else:
        urlopen = urllib.request.urlopen
        urlencode = urllib.parse.urlencode

    if method == "POST":
        return urlopen(url, data=urlencode(params))
    else:
        return urlopen(url + "?" + urlencode(params))

