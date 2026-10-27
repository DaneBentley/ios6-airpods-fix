# AirPods on iOS 6: silent after the first song, and dropping every minute (fixed)

On an iPod touch running iOS 6.1.6, AirPods have two problems:

1. **They go silent when the next song starts.** The iPod still shows it playing. Restarting the Music app or reconnecting the AirPods brings sound back until the next song.
2. **They disconnect and reconnect about once a minute.** It gets worse with a Mac or iPhone nearby, which grabs the AirPods during the gap.

This tweak fixes both. Songs play one after another and the AirPods stay connected.

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

**Silence at song changes.** Each Bluetooth audio packet carries a timestamp that tells the headphones when to play it. iOS 6 counts that timestamp in bytes sent instead of time passed. When a song changes, the iPod sends nothing for about 2 seconds, so the timestamp barely moves. Every packet after that looks 2 seconds late, and AirPods throw them all away. Older Bluetooth headphones don't check timestamps this strictly, which is why they work fine.

The tweak makes the timestamp follow real time at 44.1 kHz, as the A2DP spec requires (RFC 3016, RFC 3550). Details are in [`src/A2DPClock.m`](src/A2DPClock.m).

This is the bug in [this Apple Community thread](https://discussions.apple.com/thread/8641081), which was closed without a fix.

**Disconnecting every minute.** AirPods also connect as a headset (the mic and calls channel) and report their battery level on it. Every message they send ends with a line ending, except that battery report. iOS 6 waits for the line ending before it answers, so it never answers. The AirPods hang up after 10 seconds, and after about three tries they drop the iPod completely, music included. The tweak treats the end of the message as the end of the line, the way newer iPhones do, and answers. Details are in [`src/ATLineEnd.m`](src/ATLineEnd.m).

## Build from source

```
SDK=/path/to/iPhoneOS.sdk ./build.sh
tools/repo.sh
```

Needs Xcode, an iOS SDK that still has armv7, and `ldid`. MIT license.
