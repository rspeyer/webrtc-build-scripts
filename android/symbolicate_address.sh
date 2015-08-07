#!/bin/bash

set -e
set -u

ARCH=armeabi_v7a

function usage {
    echo $1 >&2
    echo "Usage: $0 " >&2
    echo "        [--arch] [armeabi_v7a|x86]" >&2
    echo "        [--address|-a] address" >&2
}

# 0. Parse arguments
while [ $# -gt 0 ]
do
  case $1 in
    --arch)
    ARCH=$2
    shift
    ;;
    -a)
    ADDRESS=$2
    shift
    ;;
    --address)
    ADDRESS=$2
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

addr2line -C -f -e ${HOME}/talko_android/ext/talko_voip_client/ext/webrtc/android/${ARCH}/libjingle_peerconnection_so.so ${ADDRESS}