#!/usr/bin/bash

# Invokes command, returns its' exit code, writes STDOUT and specified file
# in the process!
#
# Usage:
# ./tee_and_return_code.sh <outfile> <command with arguments>

outfile=$1
shift

eval "$@" | tee $outfile
exit ${PIPESTATUS[0]}

