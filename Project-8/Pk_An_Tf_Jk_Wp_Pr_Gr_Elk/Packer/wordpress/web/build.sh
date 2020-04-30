#!/bin/bash

/usr/local/packer/packer build -timestamp-ui -force web-ami-builder.json | tee build.log

egrep "${AWS_REGION}\:\sami\-" build.log | cut -d' ' -f2 > ami_id.txt
grep -i ami ami_id.txt || exit 1

rm build.log ami_id.txt
