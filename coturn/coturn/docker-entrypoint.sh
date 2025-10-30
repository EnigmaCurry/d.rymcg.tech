#!/bin/bash
set -e

# Original behavior: if the first arg starts with '-', prepend "turnserver"
if [ "${1:0:1}" == '-' ]; then
  set -- turnserver "$@"
fi

# Drop privileges manually
echo "Dropping privileges to nobody:nogroup"
exec gosu nobody:nogroup "$@"
