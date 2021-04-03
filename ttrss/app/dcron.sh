#!/bin/sh
# https://github.com/dubiousjim/dcron/issues/13
set -e

/usr/sbin/crond "$@"
