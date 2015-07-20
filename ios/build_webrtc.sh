#!/bin/sh

#  build_webrtc.sh
#  WebRTC

SOURCE="${BASH_SOURCE[0]}"
PROJECT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

source "$PROJECT_DIR/build.sh"
build_webrtc $1
