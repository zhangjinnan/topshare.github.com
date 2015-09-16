#!/bin/bash

sudo mount 192.168.234.1:/Users/kevin/code /home/kevin/code
exec /usr/bin/ssh-agent $SHELL


#find and delete *.pyc
find . -iname *.pyc
find . -iname *.pyc -exec rm -rf {} \;

exit 0
