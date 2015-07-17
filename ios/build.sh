#!/bin/bash

#  build.sh
#  WebRTC
#
#  Created by Rahul Behera on 6/18/14.
#  Copyright (c) 2014 Pristine, Inc. All rights reserved.
set -e
set -u 

# Get location of the script itself .. thanks SO ! http://stackoverflow.com/a/246128
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
PROJECT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

WEBRTC="$PROJECT_DIR/webrtc"
DEPOT_TOOLS="$PROJECT_DIR/depot_tools"
BUILD="$WEBRTC/libjingle_peerconnection_builds"
WEBRTC_TARGET="AppRTCDemo"

WEBRTC_RELEASE=
WEBRTC_DEBUG=
WEBRTC_PROFILE=

function create_directory_if_not_found() {
    if [ ! -d "$1" ];
    then
        mkdir -v "$1"
    fi
}

create_directory_if_not_found "$PROJECT_DIR"
create_directory_if_not_found "$WEBRTC"

function exec_libtool() {
  echo "Running libtool"
  libtool -static -v -o $@
}

function exec_strip() {
  echo "Running strip"
  strip -S -X $@
}

function exec_ninja() {
  echo "Running ninja"
  ninja -v -C $1 $WEBRTC_TARGET
}

# Update/Get/Ensure the Gclient Depot Tools
function pull_depot_tools() {

    echo Get the current working directory so we can change directories back when done
    WORKING_DIR=`pwd`

    echo If no directory where depot tools should be...
    if [ ! -d "$DEPOT_TOOLS" ]
    then
        echo Make directory for gclient called Depot Tools
        mkdir -p $DEPOT_TOOLS

        echo Pull the depot tools project from chromium source into the depot tools directory
        git clone "https://chromium.googlesource.com/chromium/tools/depot_tools.git" "$DEPOT_TOOLS"

    else

        echo Change directory into the depot tools
        cd $DEPOT_TOOLS

        echo Pull the depot tools down to the latest
        git pull
    fi
    PATH="$PATH:$DEPOT_TOOLS"
    echo Go back to working directory
    cd $WORKING_DIR
}

function choose_code_signing() {
    if [ -z "${IDENTITY+x}" ]
    then
        COUNT=$(security find-identity -v | grep -c "iPhone Developer")
        if [[ $COUNT -gt 1 ]]
        then
          security find-identity -v
          echo "Please select your code signing identity index from the above list:"
          read INDEX
          IDENTITY=$(security find-identity -v | gawk -v i=$INDEX -F "\) |\"" '{if (i==$1) {print $3}}')
        else
          IDENTITY=$(security find-identity -v | grep "iPhone Developer" | gawk -F "\) |\"" '{print $3}')
        fi
        echo Using code signing identity $IDENTITY
    fi
    sed -i -e "s/\'CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]\': \'iPhone Developer\',/\'CODE_SIGN_IDENTITY[sdk=iphoneos*]\': \'$IDENTITY\',/" $WEBRTC/src/build/common.gypi
}

function enable_rtti() {
  sed -i -e "s/\'GCC_ENABLE_CPP_RTTI\': \'NO\'/'GCC_ENABLE_CPP_RTTI\': \'YES\'/" $WEBRTC/src/build/common.gypi
}

function enable_objc() {
  sed -i -e "s/\'GCC_C_LANGUAGE_STANDARD\': \'c99\'/'CLANG_ENABLE_OBJC_ARC\': \'YES\'/" $WEBRTC/src/build/common.gypi
}

function no_strict_aliasing() {
  sed -i -e "s/\'CLANG_LINK_OBJC_RUNTIME\': \'NO\'/'GCC_STRICT_ALIASING\': \'NO\'/" $WEBRTC/src/build/common.gypi

}

function warn_conversion() {
  awk -v q="'" '{
    print;
    if ($0 ~ "-Wno-missing-field-initializers") {
        printf("\t\t\t\t\t%s-Wconversion%s,\n",q,q);
    }
}' $WEBRTC/src/build/common.gypi > /tmp/common.gypi && mv /tmp/common.gypi $WEBRTC/src/build/common.gypi
}

function no_error_on_warn() {
  awk -v q="'" '{
    if ($0 ~ "-Werror") {
        // Skip
    }
    else {
        print;
    }
}' $WEBRTC/src/build/common.gypi > /tmp/common.gypi && mv /tmp/common.gypi $WEBRTC/src/build/common.gypi
}

function apply_tk_modifications() {
    echo "No Talko modifications to apply"
    #enable_rtti
    #enable_objc
    #no_strict_aliasing
    #warn_conversion
    #no_error_on_warn
}

# Set the base of the GYP defines, instructing gclient runhooks what to generate
function wrbase() {
    export GYP_DEFINES_BASE="OS=ios build_with_libjingle=1 build_with_chromium=0 libjingle_objc=1 use_system_libcxx=1"
    export GYP_GENERATORS=ninja
}

# Add the iOS Device specific defines on top of the base
function wrios_armv7() {
    wrbase
    export GYP_DEFINES="$GYP_DEFINES_BASE target_arch=arm"
    export GYP_GENERATOR_FLAGS="output_dir=out_ios_armeabi_v7a"
    export GYP_CROSSCOMPILE=1
}

# Add the iOS ARM 64 Device specific defines on top of the base
function wrios_armv8() {
    wrbase
    export GYP_DEFINES="$GYP_DEFINES_BASE target_arch=arm64"
    export GYP_GENERATOR_FLAGS="output_dir=out_ios_arm64_v8a"
    export GYP_CROSSCOMPILE=1
}

# Add the iOS Simulator X86 specific defines on top of the base
function wrX86() {
    wrbase
    export GYP_DEFINES="$GYP_DEFINES_BASE target_arch=ia32"
    export GYP_GENERATOR_FLAGS="output_dir=out_ios_x86"
}

# Add the iOS Simulator X64 specific defines on top of the base
function wrX86_64() {
    wrbase
    export GYP_DEFINES="$GYP_DEFINES_BASE target_arch=x64"
    export GYP_GENERATOR_FLAGS="output_dir=out_ios_x86_64"
}

# Gets the revision number of the current WebRTC svn repo on the filesystem
function get_revision_number() {
    pushd $WEBRTC/src >/dev/null
    git rev-parse HEAD
    popd >/dev/null

#    git describe --tags  | sed 's/r\([0-9]*\)-.*/\1/' #Here's a nice little git version if you are using a git source
#    svn info $WEBRTC/src | awk '{ if ($1 ~ /Revision/) { print $2 } }'
}

# This function allows you to pull the latest changes from WebRTC without doing an entire clone, much faster to build and try changes
function update_webrtc() {
    # Ensure that we have gclient added to our environment, so this function can run standalone
    pull_depot_tools
    cd $WEBRTC

    gclient config --unmanaged --name=src https://chromium.googlesource.com/external/webrtc

    # Make sure that the target os is set to JUST MAC at first by adding that to the .gclient file that gclient config command created
    # Note this is a workaround until one of the depot_tools/ios bugs has been fixed
    cp ${PROJECT_DIR}/gclient_mac_tools_for_ios_only .gclient
    sync

    # Write mac and ios to the target os in the gclient file generated by gclient config
    cp ${PROJECT_DIR}/gclient_ios_and_mac_tools .gclient
    sync

    echo "-- webrtc has been successfully updated"
}

# This function cleans out your webrtc directory and does a fresh clone -- slower than a pull
function clone() {
    if [ -d $WEBRTC ]
    then
        rm -rf $WEBRTC
    fi
    mkdir -v $WEBRTC

    update_webrtc
}

# Fire the sync command
function sync() {
    pull_depot_tools

    pushd $WEBRTC >/dev/null
    choose_code_signing
    apply_tk_modifications

    gclient sync || true
    popd >/dev/null
}

# Convenience function to copy the headers by creating a symbolic link to the headers directory deep within webrtc src
function copy_headers() {
    create_directory_if_not_found "$BUILD"
    if [ ! -h "$WEBRTC/headers" ]; then
        ln -s "$WEBRTC/src/talk/app/webrtc/objc/public/" "$WEBRTC/headers" || true
    fi
}

# Build AppRTC Demo for the simulator (ia32 architecture)
function build_apprtc_sim() {
    pushd "$WEBRTC/src" >/dev/null

    wrX86
    choose_code_signing
    apply_tk_modifications
    gclient runhooks

    copy_headers

    WEBRTC_REVISION=`get_revision_number`
    if [ "$WEBRTC_DEBUG" = true ] ; then
        exec_ninja "out_ios_x86/Debug-iphonesimulator/"
        exec_libtool "$BUILD/libWebRTC-$WEBRTC_REVISION-ios-x86-Debug.a" $WEBRTC/src/out_ios_x86/Debug-iphonesimulator/*.a
    fi

    if [ "$WEBRTC_PROFILE" = true ] ; then
        exec_ninja "out_ios_x86/Profile-iphonesimulator/"
        exec_libtool "$BUILD/libWebRTC-$WEBRTC_REVISION-ios-x86-Profile.a" $WEBRTC/src/out_ios_x86/Profile-iphonesimulator/*.a
    fi

    if [ "$WEBRTC_RELEASE" = true ] ; then
        exec_ninja "out_ios_x86/Release-iphonesimulator/"
        exec_strip $WEBRTC/src/out_ios_x86/Release-iphonesimulator/*.a
        exec_libtool "$BUILD/libWebRTC-$WEBRTC_REVISION-ios-x86-Release.a" $WEBRTC/src/out_ios_x86/Release-iphonesimulator/*.a
    fi
    popd >/dev/null
}

# Build AppRTC Demo for a real device
function build_apprtc() {
    pushd "$WEBRTC/src" >/dev/null

    wrios_armv7
    choose_code_signing
    apply_tk_modifications
    gclient runhooks

    copy_headers

    WEBRTC_REVISION=`get_revision_number`
    if [ "$WEBRTC_DEBUG" = true ] ; then
        exec_ninja "out_ios_armeabi_v7a/Debug-iphoneos/"
        exec_libtool "$BUILD/libWebRTC-$WEBRTC_REVISION-ios-armeabi_v7a-Debug.a" $WEBRTC/src/out_ios_armeabi_v7a/Debug-iphoneos/*.a
    fi

    if [ "$WEBRTC_PROFILE" = true ] ; then
        exec_ninja "out_ios_armeabi_v7a/Profile-iphoneos/"
        exec_libtool "$BUILD/libWebRTC-$WEBRTC_REVISION-ios-armeabi_v7a-Profile.a" $WEBRTC/src/out_ios_armeabi_v7a/Profile-iphoneos/*.a
    fi

    if [ "$WEBRTC_RELEASE" = true ] ; then
        exec_ninja "out_ios_armeabi_v7a/Release-iphoneos/"
        exec_strip $WEBRTC/src/out_ios_armeabi_v7a/Release-iphoneos/*.a
        exec_libtool "$BUILD/libWebRTC-$WEBRTC_REVISION-ios-armeabi_v7a-Release.a" $WEBRTC/src/out_ios_armeabi_v7a/Release-iphoneos/*.a
    fi
    popd >/dev/null
}


# Build AppRTC Demo for an armv7 real device
function build_apprtc_arm64() {
    pushd "$WEBRTC/src" >/dev/null

    wrios_armv8
    choose_code_signing
    apply_tk_modifications
    gclient runhooks

    copy_headers

    WEBRTC_REVISION=`get_revision_number`
    if [ "$WEBRTC_DEBUG" = true ] ; then
        exec_ninja "out_ios_arm64_v8a/Debug-iphoneos/"
        exec_libtool "$BUILD/libWebRTC-$WEBRTC_REVISION-ios-arm64_v8a-Debug.a" $WEBRTC/src/out_ios_arm64_v8a/Debug-iphoneos/*.a
    fi

    if [ "$WEBRTC_PROFILE" = true ] ; then
        exec_ninja "out_ios_arm64_v8a/Profile-iphoneos/"
        exec_libtool "$BUILD/libWebRTC-$WEBRTC_REVISION-ios-arm64_v8a-Profile.a" $WEBRTC/src/out_ios_arm64_v8a/Profile-iphoneos/*.a
    fi

    if [ "$WEBRTC_RELEASE" = true ] ; then
        exec_ninja "out_ios_arm64_v8a/Release-iphoneos/"
        exec_strip $WEBRTC/src/out_ios_arm64_v8a/Release-iphoneos/*.a
        exec_libtool "$BUILD/libWebRTC-$WEBRTC_REVISION-ios-arm64_v8a-Release.a" $WEBRTC/src/out_ios_arm64_v8a/Release-iphoneos/*.a
    fi
    popd >/dev/null
}

# This function is used to put together the intel (simulator), armv7 and arm64 builds (device) into one static library so its easy to deal with in Xcode
# Outputs the file into the build directory with the revision number
function lipo_intel_and_arm() {
    WEBRTC_REVISION=`get_revision_number`
    if [ "$WEBRTC_DEBUG" = true ] ; then
        # Directories to use for lipo, armv7 and arm64 as default
        LIPO_DIRS="$BUILD/libWebRTC-$WEBRTC_REVISION-ios-armeabi_v7a-Debug.a $BUILD/libWebRTC-$WEBRTC_REVISION-ios-arm64_v8a-Debug.a"
        # Lipo the build together into a universal library
        lipo -create $LIPO_DIRS -output $BUILD/libWebRTC-$WEBRTC_REVISION-arm-intel-Debug.a
        # Delete the latest symbolic link just in case :)
        rm $WEBRTC/libWebRTC-Universal-Debug.a || true
        # Create a symbolic link pointing to the exact revision that is the latest. This way I don't have to change the xcode project file every time we update the revision number, while still keeping it easy to track which revision you are on
        ln -s $BUILD/libWebRTC-$WEBRTC_REVISION-arm-intel-Debug.a $WEBRTC/libWebRTC-Universal-Debug.a
        # Make it clear which revision you are using .... You don't want to get in the state where you don't know which revision you were using... trust me
        echo $WEBRTC_REVISION > $WEBRTC/libWebRTC-Universal-Debug.version
    fi

    if [ "$WEBRTC_PROFILE" = true ] ; then
        LIPO_DIRS="$BUILD/libWebRTC-$WEBRTC_REVISION-ios-armeabi_v7a-Profile.a $BUILD/libWebRTC-$WEBRTC_REVISION-ios-arm64_v8a-Profile.a"
        lipo -create $LIPO_DIRS -output $BUILD/libWebRTC-$WEBRTC_REVISION-arm-intel-Profile.a
        rm $WEBRTC/libWebRTC-Universal-Profile.a || true
        ln -s $BUILD/libWebRTC-$WEBRTC_REVISION-arm-intel-Profile.a $WEBRTC/libWebRTC-Universal-Profile.a
        echo $WEBRTC_REVISION > $WEBRTC/libWebRTC-Universal-Profile.version
    fi

    if [ "$WEBRTC_RELEASE" = true ] ; then
        LIPO_DIRS="$BUILD/libWebRTC-$WEBRTC_REVISION-ios-armeabi_v7a-Release.a $BUILD/libWebRTC-$WEBRTC_REVISION-ios-arm64_v8a-Release.a"
        lipo -create $LIPO_DIRS -output $BUILD/libWebRTC-$WEBRTC_REVISION-arm-intel-Release.a
        rm $WEBRTC/libWebRTC-Universal-Release.a || true
        ln -s $BUILD/libWebRTC-$WEBRTC_REVISION-arm-intel-Release.a $WEBRTC/libWebRTC-Universal-Release.a
        echo $WEBRTC_REVISION > $WEBRTC/libWebRTC-Universal-Release.version
    fi
}

# Convenience method to just "get webrtc" -- a clone
function get_webrtc() {
    pull_depot_tools
    update_webrtc
}

# Build webrtc for an ios device and simulator, then create a universal library
function build_webrtc() {
    # Default to DEBUG and RELEASE
    if [[ $1 == Debug ]]
    then
        WEBRTC_DEBUG=true
        WEBRTC_RELEASE=false
    else
        WEBRTC_DEBUG=false
        WEBRTC_RELEASE=true
    fi

    pull_depot_tools

    # Clean BUILD folder
    rm -rf ${BUILD}/*

    # Build
    if  [ -z $2 ] || [[ $2 == all ]] || [[ $2 == armv7 ]]
    then
        build_apprtc
    fi

    if  [ -z $2 ] || [[ $2 == all ]] || [[ $2 == armv8 ]]
    then
        build_apprtc_arm64
    fi

    # Create Universal Binary
    lipo_intel_and_arm
}
