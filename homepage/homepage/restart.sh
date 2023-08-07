#!/bin/sh

#Restart by killing all node processes: the container will exit, and
#docker will restart automatically:
set -x
sleep 2
killall node
