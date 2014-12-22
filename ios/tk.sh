#!/bin/bash

pushd ios/webrtc/src >/dev/null

git checkout master
git branch -D develop
git pulls
git checkout develop

popd >/dev/null

