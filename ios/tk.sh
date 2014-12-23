#!/bin/bash
BASE_DIR=${HOME}/dev/webrtc-build-scripts
BRANCH=develop
BUILD=Release

# 1. Update Code
pushd ${BASE_DIR}/ios/webrtc/src >/dev/null
git checkout master
git branch -D ${BRANCH}
git pulls
git checkout ${BRANCH}
popd >/dev/null

# 2. Build Code
${BASE_DIR}/ios/build_webrtc.sh

# 3. "Deploy" Code
cp ${BASE_DIR}/ios/webrtc/libWebRTC-Universal-${BUILD}.a ${HOME}/dev/talko_ios/ext/talko_voip_client/ext/webrtc/libWebRTC.a
cp ${BASE_DIR}/ios/webrtc/libWebRTC-Universal-${BUILD}.version ${HOME}/dev/talko_ios/ext/talko_voip_client/ext/webrtc/libWebRTC.version
