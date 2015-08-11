#!/bin/bash

set -e
set -u

#awk '{print system("/home/talko/webrtc-build-scripts/android/symbolicate_address.sh -a "$5)}' ~/share/in.log

ARCH=armeabi-v7a
BUILD=Release

function usage {
    echo $1 >&2
    echo "Usage: $0 " >&2
    echo "        [--address|-a] address" >&2
    echo "        [--arch] [armeabi-v7a|x86]" >&2
    echo "        [--build] [Release|Debug]" >&2
}

# 0. Parse arguments
while [ $# -gt 0 ]
do
  case $1 in
    -a)
    ADDRESS=$2
    shift
    ;;
    --address)
    ADDRESS=$2
    shift
    ;;
    --arch)
    ARCH=$2
    shift
    ;;
    --build)
    BUILD=$2
    shift
    ;;
    --help)
    usage "Symbolicate WebRTC stack address"
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

if [ -z "${ADDRESS+x}" ]
then
    usage "Fatal: Must supply address"
    exit 1
fi

ADDRLINE=
ARCHDIR=
if [[ $ARCH == armeabi-v7a ]]
then
  ADDRLINE=${ANDROID_NDK_HOME}/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin/arm-linux-androideabi-addr2line
  ARCHDIR=out_android_armeabi_v7a
else
  ADDRLINE=${ANDROID_NDK_HOME}/toolchains/x86-4.9/prebuilt/linux-x86_64/bin/i686-linux-android-addr2line
  ARCHDIR=out_android_x86
fi

$ADDRLINE -C -p -a -f -e ${HOME}/webrtc-build-scripts/android/webrtc/src/${ARCHDIR}/${BUILD}/AppRTCDemo/libs/${ARCH}/libjingle_peerconnection_so.so ${ADDRESS}