#!/bin/bash

# Copyright Pristine Inc 
# Author: Rahul Behera <rahul@pristine.io>
# Author: Aaron Alaniz <aaron@pristine.io>
# Author: Arik Yaacob   <arik@pristine.io>
#
# Builds the android peer connection library

PROJECT_ROOT=$(dirname $0)

DEPOT_TOOLS="$PROJECT_ROOT/depot_tools"
WEBRTC_ROOT="$PROJECT_ROOT/webrtc"
BUILD="$WEBRTC_ROOT/libjingle_peerconnection_builds"
WEBRTC_TARGET="AppRTCDemo"

ANDROID_TOOLCHAINS="$WEBRTC_ROOT/src/third_party/android_tools/ndk/toolchains"

create_directory_if_not_found() {
	if [ ! -d "$1" ];
	then
	    mkdir -p "$1"
	fi
}

exec_ninja() {
  echo "Running ninja"
  ninja -C $1 $WEBRTC_TARGET
}

# Installs the required dependencies on the machine
install_dependencies() {
    sudo apt-get -y install wget git gnupg flex bison gperf build-essential zip curl subversion pkg-config
    # Additional dependencies per http://blog.gaku.net/building-webrtc-for-android-on-mac/
    sudo apt-get -y install libgtk2.0-dev libxtst-dev libxss-dev libudev-dev libdbus-1-dev libgconf2-dev libgnome-keyring-dev libpci-dev
    # Download the latest script to install the android dependencies for ubuntu
    curl -o install-build-deps-android.sh https://src.chromium.org/svn/trunk/src/build/install-build-deps-android.sh
    # Use bash (not dash which is default) to run the script
    sudo /bin/bash ./install-build-deps-android.sh
    # Delete the file we just downloaded... not needed anymore
    rm install-build-deps-android.sh
}

# Update/Get/Ensure the Gclient Depot Tools
# Also will add to your environment
pull_depot_tools() {
	WORKING_DIR=`pwd`

    # Either clone or get latest depot tools
	if [ ! -d "$DEPOT_TOOLS" ]
	then
	    echo Make directory for gclient called Depot Tools
	    mkdir -p $DEPOT_TOOLS

	    echo Pull the depo tools project from chromium source into the depot tools directory
	    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git $DEPOT_TOOLS

	else
		echo Change directory into the depot tools
		cd $DEPOT_TOOLS

		echo Pull the depot tools down to the latest
		git pull
	fi
	PATH="$PATH:$DEPOT_TOOLS"

    # Navigate back
	cd $WORKING_DIR
}

enable_rtti() {
    sed -i -e "s/\'GCC_ENABLE_CPP_RTTI\': \'NO\'/'GCC_ENABLE_CPP_RTTI\': \'YES\'/" $WEBRTC_ROOT/src/build/common.gypi
    sed -i -e "s/'-fno-rtti',/'-frtti',/" $WEBRTC_ROOT/src/build/common.gypi
}

use_stlport() {
    sed -i -e "s/llvm-libc++abi/stlport/" $WEBRTC_ROOT/src/build/common.gypi
    sed -i -e "s/llvm-libc++/stlport/" $WEBRTC_ROOT/src/build/common.gypi
    sed -i -e "s/libcxx\/include/stlport/" $WEBRTC_ROOT/src/build/common.gypi
}

use_cxx11() {
    sed -i -e "s/'-std=gnu++11'/'-std=c++11'/" $WEBRTC_ROOT/src/build/common.gypi
}

no_exclude_libraries() {
    sed -i -e "s/,--exclude-libs=ALL//" $WEBRTC_ROOT/src/build/common.gypi
}

apply_tk_modifications() {
    if [ -f $WEBRTC_ROOT/src/build/common.gypi ]
    then
        enable_rtti
        #use_stlport
        use_cxx11
        no_exclude_libraries
    fi
}

# Update/Get the webrtc code base
pull_webrtc() {
    # If no directory where webrtc root should be...
    create_directory_if_not_found $WEBRTC_ROOT
    pushd $WEBRTC_ROOT >/dev/null

    # Ensure our target os is correct building android
    echo Configuring gclient for Android build
    gclient config --name=src https://chromium.googlesource.com/external/webrtc
	
    cp ${PROJECT_ROOT}/gclient_android_and_unix_tools .gclient

    # Get latest webrtc source
	echo Pull down the latest from the WebRTC repository
    gclient sync

    # Navigate back
    popd >/dev/null
}

function wrbase() {
    export GYP_DEFINES_BASE="OS=android host_os=linux libjingle_java=1 build_with_libjingle=1 build_with_chromium=0 enable_tracing=1 enable_protobuf=0"
    export GYP_GENERATORS="ninja"
}

# ARMv7
function wrarmv7() {
    wrbase
    export GYP_DEFINES="$GYP_DEFINES_BASE"
    export GYP_GENERATOR_FLAGS="output_dir=out_android_armeabi-v7a"
    export GYP_CROSSCOMPILE=1
}

# ARM64
function wrarmv8() {
    wrbase
    export GYP_DEFINES="$GYP_DEFINES_BASE target_arch=arm64 target_subarch=arm64"
    export GYP_GENERATOR_FLAGS="output_dir=out_android_arm64-v8a"
    export GYP_CROSSCOMPILE=1
}

# x86
function wrX86() {
    wrbase
    export GYP_DEFINES="$GYP_DEFINES_BASE target_arch=ia32"
    export GYP_GENERATOR_FLAGS="output_dir=out_android_x86"
}

# x86_64
function wrX86_64() {
    wrbase
    export GYP_DEFINES="$GYP_DEFINES_BASE target_arch=x64"
    export GYP_GENERATOR_FLAGS="output_dir=out_android_x86_64"
}


# Setup our defines for the build
prepare_gyp_defines() {
    # Configure environment for Android
    source $WEBRTC_ROOT/src/chromium/src/build/android/envsetup.sh

    if [ "$WEBRTC_ARCH" = "x86" ] ;
    then
        wrX86
    elif [ "$WEBRTC_ARCH" = "x86_64" ] ;
    then
        wrX86_64
    elif [ "$WEBRTC_ARCH" = "armv7" ] ;
    then
        wrarmv7
    elif [ "$WEBRTC_ARCH" = "armv8" ] ;
    then
        wrarmv8
    fi
}

execute_build() {
    pushd "$WEBRTC_ROOT/src" >/dev/null

    echo Run gclient hooks
    prepare_gyp_defines
    apply_tk_modifications
    gclient runhooks

    if [ "$WEBRTC_ARCH" = "x86" ] ;
    then
        ARCH="x86"
        STRIP=$ANDROID_TOOLCHAINS/x86-4.9/prebuilt/linux-x86_64/bin/i686-linux-android-strip
    elif [ "$WEBRTC_ARCH" = "x86_64" ] ;
    then
        ARCH="x86_64"
        STRIP=$ANDROID_TOOLCHAINS/x86_64-4.9/prebuilt/linux-x86_64/bin/x86_64-linux-android-strip
    elif [ "$WEBRTC_ARCH" = "armv7" ] ;
    then
        ARCH="armeabi-v7a"
        STRIP=$ANDROID_TOOLCHAINS/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin/arm-linux-androideabi-strip
    elif [ "$WEBRTC_ARCH" = "armv8" ] ;
    then
        ARCH="arm64-v8a"
        STRIP=$ANDROID_TOOLCHAINS/aarch64-linux-android-4.9/prebuilt/linux-x86_64/bin/aarch64-linux-android-strip
    fi

    STRIP="$STRIP -s -x"

    if [ "$WEBRTC_DEBUG" = "true" ] ;
    then
        BUILD_TYPE="Debug"
    else
        BUILD_TYPE="Release"
    fi

    ARCH_OUT="out_android_${ARCH}"
    echo "Build ${WEBRTC_TARGET} in $BUILD_TYPE (arch: ${WEBRTC_ARCH:-arm})"
    exec_ninja "$ARCH_OUT/$BUILD_TYPE"

    pushd $WEBRTC_ROOT/src >/dev/null
    REVISION_NUM=`git rev-parse HEAD`
    popd >/dev/null

    # Verify the build actually worked
    if [ $? -eq 0 ]; then
        SOURCE_DIR="$WEBRTC_ROOT/src/$ARCH_OUT/$BUILD_TYPE"
        TARGET_DIR="$BUILD/$BUILD_TYPE"
        create_directory_if_not_found "$TARGET_DIR"
        
        create_directory_if_not_found "$TARGET_DIR/jars/"
        create_directory_if_not_found "$TARGET_DIR/sharedlibs/"
        create_directory_if_not_found "$TARGET_DIR/staticlibs/"

        ARCH_SO="$TARGET_DIR/sharedlibs/${ARCH}"
        create_directory_if_not_found $ARCH_SO

        ARCH_A="$TARGET_DIR/staticlibs/${ARCH}"
        create_directory_if_not_found $ARCH_A

        cp -p "$SOURCE_DIR/gen/libjingle_peerconnection_java/libjingle_peerconnection_java.jar" "$TARGET_DIR/jars/libjingle_peerconnection.jar" 
        if [ "$WEBRTC_DEBUG" = "true" ]
        then
            cp -p $WEBRTC_ROOT/src/$ARCH_OUT/$BUILD_TYPE/lib/libjingle_peerconnection_so.so $ARCH_SO/libjingle_peerconnection_so.so
        else
            $STRIP -o $ARCH_SO/libjingle_peerconnection_so.so $WEBRTC_ROOT/src/$ARCH_OUT/$BUILD_TYPE/lib/libjingle_peerconnection_so.so
        fi

        pushd $SOURCE_DIR >/dev/null
        for a in `find . -name '*.a' | grep -v ./obj.host/`; do
            cp --parents $a $ARCH_A
        done
        popd >/dev/null

        cd $TARGET_DIR
        mkdir -p res
        zip -r -q "$TARGET_DIR/libWebRTC.zip" .
        
        echo $REVISION_NUM > libWebRTC-$BUILD_TYPE.version
        echo "$BUILD_TYPE build for WebRTC complete for revision $REVISION_NUM"
    else
        
        echo "$BUILD_TYPE build for WebRTC failed for revision $REVISION_NUM"
    fi
    popd >/dev/null
}

clone() {
    pull_depot_tools
    pull_webrtc
}

build_webrtc() {
    pull_depot_tools
    
    # Clean BUILD folder
    rm -rf ${BUILD}/*

    if [[ $1 == Debug ]]
    then
        WEBRTC_DEBUG=true
    else
        WEBRTC_DEBUG=false
    fi

    ARCHITECTURES=(armv7 x86 armv8 x86_64)
    for a in "${ARCHITECTURES[@]}"
    do
        if [ -z $2 ] || [[ $2 == all ]] || [[ $2 == $a ]]
        then
            export WEBRTC_ARCH=$a
            execute_build
        fi
    done
}