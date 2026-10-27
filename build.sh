#!/bin/sh
# Builds A2DPClock.dylib and the .deb. Needs Xcode and an iOS SDK with armv7 (set SDK).
set -e
cd "$(dirname "$0")"
: "${SDK:?set SDK to an iOS SDK path that has armv7 libSystem}"
L=layout/Library/MobileSubstrate/DynamicLibraries
xcrun clang -target armv7-apple-ios6.0 -marm -isysroot "$SDK" -dynamiclib -O2 -Wall src/A2DPClock.m -o $L/A2DPClock.dylib
cp src/A2DPClock.plist $L/
ldid -S $L/A2DPClock.dylib
python3 -I tools/deb.py layout ios6-airpods-fix_1.0_iphoneos-arm.deb
