#!/bin/bash

#  tk.sh
#  WebRTC
#
#  Created by Richard Speyer on 1/7/15.
#  Copyright (c) 2015 Talko, Inc. All rights reserved.
set -e
set -u

BASE_DIR=${HOME}/webrtc-build-scripts
BRANCH=talko_master
BUILD=Release
ARCH=all

function usage {
  echo $1 >&2
  echo "Usage: $0" >&2
  echo "        [--init]" >&2
  echo "        [--branch BRANCH]" >&2
  echo "        [--build Release|Debug]" >&2
  echo "        [--arch x86|armv7|all]"
  echo "        [--clean]" >&2
  echo "        [--copy-only]" >&2
}

# 0. Parse arguments
while [ $# -gt 0 ]
do
  case $1 in
    --init)
    INIT=YES
    ;;
    --branch)
    BRANCH=$2
    shift
    ;;
    --build)
    BUILD=$2
    shift
    ;;
    --arch)
    ARCH=$2
    shift
    ;;
    --clean)
    CLEAN=YES
    ;;
    --copy-only)
    COPYONLY=YES
    ;;
    --help)
    usage "Build and deploy WebRTC binary for Android into talko_android project"
    exit 0
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

if [ ! -z "${INIT+x}" ]
then
  ${BASE_DIR}/android/init_webrtc.sh 
fi

if [ -z "${COPYONLY+x}" ]
then
  # 1. Update Code
  pushd ${BASE_DIR}/android/webrtc/src >/dev/null
  git fetch
  git checkout ${BRANCH}
  git reset --hard origin/${BRANCH}
  popd >/dev/null

  # 2. Clean intermediates if requested
  if [ ! -z "${CLEAN+x}" ]
  then
    rm -rf ${BASE_DIR}/android/webrtc/src/out_android*
  fi

  # 3. Build Code
  ${BASE_DIR}/android/build_webrtc.sh $BUILD $ARCH
fi

BASE_SRC_DIR=${BASE_DIR}/android/webrtc/libjingle_peerconnection_builds/${BUILD}
BASE_DST_DIR=${HOME}/talko_android/ext/talko_voip_client/ext/webrtc/android

# 3. "Deploy" Code
ARCHS=("armeabi_v7a" "x86")
for arch in "${ARCHS[@]}"; do
    SRC_DIR=${BASE_SRC_DIR}/sharedlibs/${arch}
    DST_DIR=${BASE_DST_DIR}/${arch}

    if [ ! -d ${DST_DIR} ]
    then
      mkdir -p ${DST_DIR}
    fi

    ## Shared Object Files
    cp -v ${SRC_DIR}/libjingle_peerconnection_so.so ${DST_DIR}
done

cp -v ${BASE_SRC_DIR}/jars/libjingle_peerconnection.jar ${BASE_DST_DIR}
cp -v ${BASE_SRC_DIR}/libWebRTC-${BUILD}.version ${BASE_DST_DIR}/libWebRTC.version

NOTIFY=$(which notify-send)
if [ ! -z $NOTIFY ]
then
  $NOTIFY "WebRTC Build Completed" --category=WebRTC --expire-time=5000
fi
