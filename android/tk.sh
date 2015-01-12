#!/bin/bash

#  tk.sh
#  WebRTC
#
#  Created by Richard Speyer on 1/7/15.
#  Copyright (c) 2015 Talko, Inc. All rights reserved.
set -e
set -u

BASE_DIR=${HOME}/webrtc-build-scripts
BRANCH=develop
BUILD=Release

function usage {
  echo $1 >&2
  echo "Usage: $0" >&2
  echo "        [--branch BRANCH]" >&2
  echo "        [--build Release|Debug]" >&2
  echo "        [--clean]" >&2
  echo "        [--copy-only]" >&2
}

# 0. Parse arguments
while [ $# -gt 0 ]
do
  case $1 in
    --branch)
    BRANCH=$2
    shift
    ;;
    --build)
    BUILD=$2
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
  ${BASE_DIR}/android/build_webrtc.sh
fi

# 3. "Deploy" Code
SRC_DIR=${BASE_DIR}/android/webrtc/libjingle_peerconnection_builds
DST_DIR=${HOME}/talko_android/ext/talko_voip_client/ext/webrtc/android

cp -v ${SRC_DIR}/${BUILD}/jniLibs/armeabi_v7a/libjingle_peerconnection_so.so ${DST_DIR}/libWebRTC-armeabi-v7a.so
#cp -v ${SRC_DIR}/${BUILD}/jniLibs/arm64_v8a/libjingle_peerconnection_so.so ${DST_DIR}/libWebRTC-arm64-v8a.so
cp -v ${SRC_DIR}/${BUILD}/jniLibs/x86/libjingle_peerconnection_so.so ${DST_DIR}/libWebRTC-x86.so
#cp -v ${SRC_DIR}/${BUILD}/jniLibs/x86_64/libjingle_peerconnection_so.so ${DST_DIR}/libWebRTC-x86_64.so
cp -v ${SRC_DIR}/${BUILD}/libWebRTC-${BUILD}.version ${DST_DIR}/libWebRTC.version

NOTIFY=$(which notify-send)
if [ ! -z $NOTIFY ]
then
  $NOTIFY "WebRTC Build Completed" --category=WebRTC --expire-time=5000
fi
