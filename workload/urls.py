import glob
import os
import sys

urls = set()

_base_dir = os.path.dirname(__file__)

def _ensure_url(path):
    url = path
    path = _base_dir + '/' + path
    return ('file://'+ os.path.realpath(path)) if os.path.isfile(path) else url

for fn in glob.glob(os.path.dirname(__file__) + '/urls[0-9]*'):
    with open(fn, 'r') as f:
        urls.update((_ensure_url(line.strip()) for line in f if not line.startswith('#')))
