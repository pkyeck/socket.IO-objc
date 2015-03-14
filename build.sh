#!/bin/bash

set -e

IOSSDK_VER="7.0"

LIBNAME=SocketIO

# xcodebuild -showsdks

xcodebuild -project SocketTesterARC.xcodeproj -target ${LIBNAME} -configuration Release -sdk iphoneos${IOSSDK_VER} build
xcodebuild -project SocketTesterARC.xcodeproj -target ${LIBNAME} -configuration Release -sdk iphonesimulator${IOSSDK_VER} build

cd build
# for the fat lib file
mkdir -p Release-iphone/lib
xcrun -sdk iphoneos lipo -create Release-iphoneos/lib${LIBNAME}.a Release-iphonesimulator/lib${LIBNAME}.a -output Release-iphone/lib/lib${LIBNAME}.a
xcrun -sdk iphoneos lipo -info Release-iphone/lib/lib${LIBNAME}.a
# for header files
mkdir -p Release-iphone/include
cp ../*.h Release-iphone/include

# Build static framework
mkdir -p ${LIBNAME}.framework/Versions/A
cp Release-iphone/lib/lib${LIBNAME}.a ${LIBNAME}.framework/Versions/A/${LIBNAME}
mkdir -p ${LIBNAME}.framework/Versions/A/Headers
cp Release-iphone/include/*.h ${LIBNAME}.framework/Versions/A/Headers
ln -sfh A ${LIBNAME}.framework/Versions/Current
ln -sfh Versions/Current/${LIBNAME} ${LIBNAME}.framework/${LIBNAME}
ln -sfh Versions/Current/Headers ${LIBNAME}.framework/Headers
