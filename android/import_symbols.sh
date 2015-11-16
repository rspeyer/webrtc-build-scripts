#!/bin/bash

#  import_symbols.sh
#  WebRTC
#
#  Created by Richard Speyer on 11/16/15.
#  Copyright (c) 2015 Talko, Inc. All rights reserved.
set -e
set -u

function usage {
  echo $1 >&2
  echo "Usage: $0 <SYMBOL_TAR>" >&2
}

SYMBOL_TAR=$1

if [ -z "${SYMBOL_TAR+x}" ]
then
    usage "Fatal: Must specify input file"
    exit 1
fi

SYMBOL_DESTINATION=${HOME}/dev/talko_android/talko/src/main/obj

pushd ${SYMBOL_DESTINATION} >/dev/null
tar -xf $SYMBOL_TAR
popd >/dev/null