#!/bin/sh
# Rebuilds the Cydia source in docs/ (served by GitHub Pages) from the .debs in docs/debs.
set -e
cd "$(dirname "$0")/../docs"
: > Packages
for f in debs/*.deb; do
    python3 -I - "$f" >> Packages <<'PY'
import sys, hashlib, io, tarfile
p = sys.argv[1]; d = open(p, 'rb').read()
i = d.find(b'control.tar.gz'); n = int(d[i+48:i+58]); t = tarfile.open(fileobj=io.BytesIO(d[i+60:i+60+n]))
ctl = t.extractfile('./control').read().decode().strip()
print(ctl)
print(f'Filename: {p}\nSize: {len(d)}\nMD5sum: {hashlib.md5(d).hexdigest()}\nSHA1: {hashlib.sha1(d).hexdigest()}\nSHA256: {hashlib.sha256(d).hexdigest()}\n')
PY
done
gzip -9kf Packages && bzip2 -9kf Packages
cat > Release <<R
Origin: iOS 6 AirPods Fix
Label: iOS 6 AirPods Fix
Suite: stable
Version: 1.1
Codename: ios6
Architectures: iphoneos-arm
Components: main
Description: Fixes AirPods going silent at song changes and dropping the iPod every minute on iOS 6.1.6.
R
touch .nojekyll
