#!/bin/bash

#  export_symbols.sh
#  WebRTC
#
#  Created by Richard Speyer on 11/16/15.
#  Copyright (c) 2015 Talko, Inc. All rights reserved.
set -e
set -u

BUILD=Release

function usage {
  echo $1 >&2
  echo "Usage: $0" >&2
  echo "        --version|-v VERSION" >&2
  echo "        [--build Release|Debug]" >&2
  echo "        [--noupload]" >&2
}

# 0. Parse arguments
while [ $# -gt 0 ]
do
  case $1 in
    -v)
    VERSION=$2
    shift
    ;;
    --version)
    VERSION=$2
    shift
    ;;
    --build)
    BUILD=$2
    shift
    ;;
    --noupload)
    NOUPLOAD=YES
    ;;
    --help)
    usage ""
    exit 0 "Packages all debug symbols for WebRTC for Android"
    ;;
    -*)
    usage "Fatal: unknown option: $1"
    exit 1
    ;;
    *)break
    ;;
  esac
  shift
done

case $# in
  0)
  ;;
  *)
  usage "Fatal: too many arguments"
  exit 1
  ;;
esac

if [ -z "${VERSION+x}" ]
then
    usage "Fatal: Must specify version"
    exit 1
fi

# 1. Gather symbols
TMP=`mktemp -d`
ARCHS=("armeabi-v7a" "arm64-v8a" "x86" "x86_64")
for arch in "${ARCHS[@]}"; do
    SYMBOLS_IN=${HOME}/webrtc-build-scripts/android/webrtc/src/out_android_${arch}/${BUILD}/obj
    SYMBOLS_OUT=${TMP}/local/${arch}/objs
    mkdir -p ${SYMBOLS_OUT}

    pushd ${SYMBOLS_IN} >/dev/null
    for o in `find . -name '*.o' | grep -v ./obj.host/`; do
        cp --parents $o $SYMBOLS_OUT
    done
    popd >/dev/null
done

# 2. TAR
TARFILE=/tmp/talko-webrtc-symbols-${VERSION}.tar
pushd ${TMP} >/dev/null
tar -czf ${TARFILE} .
popd >/dev/null

# 3. Upload
if [ ! -z "${NOUPLOAD+x}" ]
then
#FIXME
else
    echo "WARNING: Skipping upload of symbols"
fi

# 4. Echo
rm -rf ${TMP}
echo "WebRTC symbols available at ${TARFILE}" 

