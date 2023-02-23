#!/bin/bash

(set -ex; home-manager switch)
if [[ $# -gt 0 ]]; then
    (set -x; $@)
else
    (set -x; bash)
fi
