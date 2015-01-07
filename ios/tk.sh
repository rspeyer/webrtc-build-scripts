#!/bin/bash
set -e
set -u

BASE_DIR=${HOME}/dev/webrtc-build-scripts
BRANCH=develop
BUILD=Release

function usage {
  echo $1 >&2
  echo "Usage: $0" >&2
  echo "        [--branch BRANCH]" >&2
  echo "        [--build Release|Debug|Profile]" >&2
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
    usage "Build and deploy WebRTC binary for iOS into talko_ios project"
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
  pushd ${BASE_DIR}/ios/webrtc/src >/dev/null
  git fetch
  git checkout ${BRANCH}
  git reset --hard origin/${BRANCH}
  popd >/dev/null

  # 2. Clean intermediates if requested
  if [ ! -z "${CLEAN+x}" ]
  then
    rm -rf ${BASE_DIR}/ios/webrtc/src/out_ios*
  fi
  
  # 3. Build Code
  if [ ! -z "${APPLEINDEX+x}" ]
  then
    ${BASE_DIR}/ios/build_webrtc.sh <<< $APPLEINDEX
  else
    ${BASE_DIR}/ios/build_webrtc.sh
  fi
fi

# 4. "Deploy" Code
SRC_DIR=${BASE_DIR}/ios/webrtc
DST_DIR=${HOME}/dev/talko_ios/ext/talko_voip_client/ext/webrtc

cp -v ${SRC_DIR}/libWebRTC-Universal-${BUILD}.a ${DST_DIR}/libWebRTC.a
cp -v ${SRC_DIR}/libWebRTC-Universal-${BUILD}.version ${DST_DIR}/libWebRTC.version

TERMINAL=$(which terminal-notifier)
if [ ! -z $TERMINAL ]
then
  $TERMINAL -message "Build Completed" -title WebRTC -group WebRTC
fi
