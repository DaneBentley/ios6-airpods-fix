#!/bin/sh
# Builds the tweaks and the .deb. Needs Xcode and an iOS SDK with armv7 (set SDK).
set -e
cd "$(dirname "$0")"
: "${SDK:?set SDK to an iOS SDK path that has armv7 libSystem}"
L=layout/Library/MobileSubstrate/DynamicLibraries
for t in A2DPClock ATLineEnd; do
    xcrun clang -target armv7-apple-ios6.0 -marm -isysroot "$SDK" -dynamiclib -O2 -Wall src/$t.m -o $L/$t.dylib
    cp src/$t.plist $L/
    ldid -S $L/$t.dylib
done
V=$(sed -n 's/^Version: //p' layout/DEBIAN/control)
python3 -I tools/deb.py layout ios6-airpods-fix_${V}_iphoneos-arm.deb
