#!/bin/bash

#  init_webrtc.sh
#  WebRTC
#
#  Created by Richard Speyer on 1/7/15.
#  Copyright (c) 2015 Talko, Inc. All rights reserved.

PROJECT_DIR=$(dirname $0)

source "$PROJECT_DIR/build.sh"
install_dependencies
clone
