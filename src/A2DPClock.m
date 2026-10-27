// A2DPClock: gives BTServer's AAC stream RTP timestamps that follow real time.
//
// iOS 6.1.6's A2DP send loop (BTServer, MobileBluetooth-85.10.1) advances the RTP timestamp by
// payload bytes / 32 per packet: no fixed clock, and nothing moves it while no audio is sent. At
// every song change mediaserverd stops sending for 2.07 s with the stream left open (packet
// captures, 2026-10-27), so every packet after it carries a timestamp 2 s behind real time and
// AirPods drop them all until the stream is restarted. A seek leaves a 0.18 s hole, which they
// ride out.
//
// RFC 3016 puts AAC timestamps on the sample clock, and RFC 3550 has the timestamp jump across a
// gap in sending. The send loop builds each packet in one function, 0x11560, which copies the
// timestamp from a global at 0x15c7c4 and adds to it afterwards; this hook rewrites that global
// before each packet. The original loop zeroes it when a stream starts, which resets the clock.

#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach/mach_time.h>
#include <stdint.h>
#include <syslog.h>

enum {
    kBuildPacket = 0x11560,
    kTimestamp = 0x15c7c4,
    kRate = 44100,
    kFrame = 1024,           // samples per AAC frame; the send loop puts one frame in each packet
};

static const double kGap = .1;   // seconds; packets normally leave every 23 ms, in small bursts

static int (*orig_build)(int, int, int, int, int, int, int, int);
static volatile uint32_t *gTimestamp;
static uint32_t gWritten, gClock;
static uint64_t gLast;
static double gTicks;

static int clock_build(int a, int b, int c, int d, int e, int f, int g, int h) {
    uint64_t now = mach_absolute_time();
    uint32_t seen = *gTimestamp;
    if (!gLast || seen < gWritten) {
        // a new stream: the send loop set the global back to 0
        gClock = 0;
    } else {
        double away = (now - gLast) * gTicks;
        gClock += kFrame;
        if (away > kGap) {
            gClock += (uint32_t)((away - (double)kFrame / kRate) * kRate);
            syslog(LOG_NOTICE, "A2DPClock: %.2f s without audio, timestamp moved on", away);
        }
    }
    gLast = now;
    *gTimestamp = gWritten = gClock;
    return orig_build(a, b, c, d, e, f, g, h);
}

__attribute__((constructor)) static void A2DPClockInit(void) {
    static const uint8_t prologue[] = { 0xf0, 0xb5, 0x03, 0xaf, 0x89, 0xb0, 0x47, 0xf2, 0xe8, 0x75 };
    intptr_t slide = _dyld_get_image_vmaddr_slide(0);
    const uint8_t *build = (const uint8_t *)(kBuildPacket + slide);
    for (unsigned i = 0; i < sizeof prologue; i++) {
        if (build[i] == prologue[i]) continue;
        syslog(LOG_NOTICE, "A2DPClock: unknown BTServer build, not loaded");
        return;
    }
    mach_timebase_info_data_t tb;
    mach_timebase_info(&tb);
    gTicks = (double)tb.numer / tb.denom / 1e9;
    gTimestamp = (volatile uint32_t *)(kTimestamp + slide);
    // Substrate loads this dylib before CydiaSubstrate itself, so MSHookFunction is not yet in RTLD_DEFAULT
    void *substrate = dlopen("/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate", RTLD_LAZY);
    void (*hook)(void *, void *, void **) = (void (*)(void *, void *, void **))dlsym(substrate, "MSHookFunction");
    if (!hook) return;
    hook((void *)((uintptr_t)build | 1), (void *)clock_build, (void **)&orig_build);
    syslog(LOG_NOTICE, "A2DPClock: loaded");
}
