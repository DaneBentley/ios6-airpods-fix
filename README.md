# AirPods go silent after the first song on iOS 6 (fixed)

On an iPod touch running iOS 6.1.6, AirPods play the first song, then go silent when the next one starts. The iPod still shows it playing. Restarting the Music app or reconnecting the AirPods brings sound back until the next song.

This tweak fixes it. Songs play one after another like they should.

## Install

Your iPod needs to be jailbroken with Cydia.

1. Open **Cydia** and tap **Sources**, then **Edit**, then **Add**.
2. Type this and tap **Add Source**:
   ```
   https://danebentley.github.io/ios6-airpods-fix/
   ```
3. Search for **iOS 6 AirPods Fix** and tap **Install**.
4. Reboot the iPod.

If Cydia can't add the source, download the `.deb` from [Releases](https://github.com/DaneBentley/ios6-airpods-fix/releases/latest) and open it with Filza or iFile, or run `dpkg -i` on it over SSH. Then reboot.

To remove it, uninstall **iOS 6 AirPods Fix** in Cydia and reboot.

## Works on

Tested on an **iPod touch 4th generation, iOS 6.1.6**, with AirPods.

On any other device or iOS version it does nothing: it checks for the exact Bluetooth code it fixes and stays off if it doesn't find it. If you have a different iOS 6 device with the same problem, [open an issue](https://github.com/DaneBentley/ios6-airpods-fix/issues) with your model and iOS version.

## Why it happens

Each Bluetooth audio packet carries a timestamp that tells the headphones when to play it. iOS 6 counts that timestamp in bytes sent instead of time passed. When a song changes, the iPod sends nothing for about 2 seconds, so the timestamp barely moves. Every packet after that looks 2 seconds late, and AirPods throw them all away. Older Bluetooth headphones don't check timestamps this strictly, which is why they work fine.

The tweak makes the timestamp follow real time at 44.1 kHz, as the A2DP spec requires (RFC 3016, RFC 3550). Details are in [`src/A2DPClock.m`](src/A2DPClock.m).

This is the bug in [this Apple Community thread](https://discussions.apple.com/thread/8641081), which was closed without a fix.

## Build from source

```
SDK=/path/to/iPhoneOS.sdk ./build.sh
tools/repo.sh
```

Needs Xcode, an iOS SDK that still has armv7, and `ldid`. MIT license.
