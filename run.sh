#!/usr/bin/env bash

docker run -it --rm \
       -e KEY=/keys/m._domainkey.land.fm.key \
       -e KEY_2=/keys/i3mm.key:i3mm.com:selector:\*@i3mm.com \
       -v `pwd`/m._domainkey.land.fm.key:/keys/m._domainkey.land.fm.key \
       -v `pwd`/m._domainkey.land.fm.key:/keys/i3mm.key\
       docker.rodeopartners.com/opendkim:latest "${@}"
