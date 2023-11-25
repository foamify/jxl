#!/bin/bash

CURR_VERSION=jxl-v`awk '/^version: /{print $2}' packages/jxl/pubspec.yaml`

# iOS & macOS
APPLE_HEADER="release_tag_name = '$CURR_VERSION' # generated; do not edit"
sed -i.bak "1 s/.*/$APPLE_HEADER/" packages/flutter_jxl/ios/flutter_jxl.podspec
sed -i.bak "1 s/.*/$APPLE_HEADER/" packages/flutter_jxl/macos/flutter_jxl.podspec
rm packages/flutter_jxl/macos/*.bak packages/flutter_jxl/ios/*.bak

# CMake platforms (Linux, Windows, and Android)
CMAKE_HEADER="set(LibraryVersion \"$CURR_VERSION\") # generated; do not edit"
for CMAKE_PLATFORM in android linux windows
do
    sed -i.bak "1 s/.*/$CMAKE_HEADER/" packages/flutter_jxl/$CMAKE_PLATFORM/CMakeLists.txt
    rm packages/flutter_jxl/$CMAKE_PLATFORM/*.bak
done

git add packages/flutter_jxl/
