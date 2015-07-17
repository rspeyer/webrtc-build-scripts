#!/bin/sh

#  init_webrtc.sh
#  WebRTC

SOURCE="${BASH_SOURCE[0]}"
PROJECT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
source "$PROJECT_DIR/build.sh"
clone