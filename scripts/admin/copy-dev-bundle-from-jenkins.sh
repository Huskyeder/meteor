#!/bin/bash

# Requires s3cmd to be installed and an appropriate ~/.s3cfg.
# Usage:
#    scripts/admin/copy-dev-bundle-from-jenkins.sh [--prod] BUILDNUMBER
# where BUILDNUMBER is the small integer Jenkins build number.

set -e
set -u

cd "`dirname "$0"`"

TARGET="s3://com.meteor.static/test/"
TEST=no
if [ $# -ge 1 -a $1 = '--prod' ]; then
    shift
    TARGET="s3://com.meteor.static/"
else
    TEST=yes
fi

if [ $# -ne 1 ]; then
    echo "usage: $0 [--prod] jenkins-build-number" 1>&2
    exit 1
fi

DIRNAME=$(s3cmd ls s3://com.meteor.jenkins/ | perl -nle 'print $1 if m!/(dev-bundle-.+--'$1'--.+)/!')

if [ -z "$DIRNAME" ]; then
    echo "build not found" 1>&2
    exit 1
fi

echo Found build $DIRNAME

trap "echo Found surprising number of tarballs." EXIT
# Check to make sure the proper number of each kind of file is there.
s3cmd ls s3://com.meteor.jenkins/$DIRNAME/ | \
  perl -nle 'if (/\.tar\.gz/) { ++$TAR } else { die "something weird" }  END { exit !($TAR == 3) }'

trap - EXIT

for FILE in $(s3cmd ls s3://com.meteor.jenkins/$DIRNAME/ | perl -nlaF/ -e 'print $F[-1]'); do
   if s3cmd info $TARGET$FILE >/dev/null 2>&1; then
     echo "$TARGET$FILE already exists (maybe from another branch?)"
     exit 1
   fi
done

echo Copying to $TARGET
s3cmd -P cp -r s3://com.meteor.jenkins/$DIRNAME/ $TARGET
