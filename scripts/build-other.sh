#!/bin/bash

# Setup
CURR_VERSION=jxl-v`awk '/^version: /{print $2}' packages/jxl/pubspec.yaml`

BUILD_DIR=platform-build
mkdir $BUILD_DIR
cd $BUILD_DIR

# Install build dependencies
cargo install cargo-zigbuild
cargo install cargo-xwin

zig_build () {
    local TARGET="$1"
    local PLATFORM_NAME="$2"
    local LIBNAME="$3"
    rustup target add "$TARGET"
    cargo zigbuild --target "$TARGET" -r
    mkdir "$PLATFORM_NAME"
    cp "../target/$TARGET/release/$LIBNAME" "$PLATFORM_NAME/"
}

win_build () {
    local TARGET="$1"
    local PLATFORM_NAME="$2"
    local LIBNAME="$3"
    rustup target add "$TARGET"
    cargo xwin build --target "$TARGET" -r
    mkdir "$PLATFORM_NAME"
    cp "../target/$TARGET/release/$LIBNAME" "$PLATFORM_NAME/"
}

# Build all the dynamic libraries
LINUX_LIBNAME=libjxl.so
zig_build aarch64-unknown-linux-gnu linux-arm64 $LINUX_LIBNAME
zig_build x86_64-unknown-linux-gnu linux-x64 $LINUX_LIBNAME
WINDOWS_LIBNAME=jxl.dll
win_build aarch64-pc-windows-msvc windows-arm64 $WINDOWS_LIBNAME
win_build x86_64-pc-windows-msvc windows-x64 $WINDOWS_LIBNAME

# Archive the dynamic libs
tar -czvf windows.tar.gz windows-*
tar -czvf linux.tar.gz linux-*

# Copy the built windows library to the correct path
mkdir -p ../packages/flutter_jxl/windows/${CURR_VERSION}/windows-x64
mkdir -p ../packages/flutter_jxl/windows/${CURR_VERSION}/windows-arm64
cp -f windows-arm64*/$WINDOWS_LIBNAME ../packages/flutter_jxl/windows/${CURR_VERSION}/windows-arm64/$WINDOWS_LIBNAME
cp -f windows-x64*/$WINDOWS_LIBNAME ../packages/flutter_jxl/windows/${CURR_VERSION}/windows-x64/$WINDOWS_LIBNAME

cp -f windows.tar.gz ../packages/flutter_jxl/windows/${CURR_VERSION}.tar.gz

# Cleanup
rm -rf linux-* windows-*