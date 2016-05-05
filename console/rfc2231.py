#!/usr/bin/env python3

# Encodes/decodes a string from stdin as per RFC 2231 word encoding rules.
# Input for encoding must be in UTF-8; for decoding it must be in US-ASCII.

import re
import sys

import args as Args

args = Args.Args()
args.add(['-c', '--charset'], ('charset', 'string', 'utf-8'))
args.add(['-d', '--decode'], ('decode', 'bool', False))
args.add(['-n', '--no-newline'], ('no_newline', 'bool', False))
args.parse(sys.argv)

orig = sys.stdin.read()
result = ''

if args.decode:
    result = re.sub(b'%([0-9A-Fa-f]{2})', lambda m: bytes([int(m.group(1), 16)]), bytes(orig, 'us-ascii'))
    result = result.decode(args.charset)
else:
    result = ''.join('%%%0.2X' % b for b in orig.encode(args.charset))

print(result, end = '' if args.no_newline else '\n')
